require "bundler/setup"

require "grpc_reflection"

require "grpc"
require "securerandom"

require "google/protobuf/any_pb"
require "basic/v1/basic_services_pb"
require "basic/service/v1/service_pb"
require "io/cloudevents/v1/cloudevents_pb"

require_relative "utils"
require_relative "health"

class BasicServiceV1 < Basic::V1::BasicService::Service
  def hello(req, _call)
    payload = Basic::Service::V1::HelloResponseEvent.new(
          greeting: "Hello, #{req.message}!"
        )

    any = Google::Protobuf::Any.new(
      type_url: "type.googleapis.com/#{payload.class.descriptor.name}",
      value: payload.to_proto.to_s
    )

    resp = Basic::Service::V1::HelloResponse.new(cloud_event: nil)

    resp.cloud_event = Io::CloudEvents::V1::Proto::CloudEvent.new(
      id: SecureRandom.uuid,
      source: "urn:basic:v1:BasicService",
      spec_version: "1.0",
      type: resp.class.descriptor.name,
      attributes: {},
      proto_data: any
    )

    resp
  end

  def talk(requests, _call)
    bot = Utils::Talk.new
    Enumerator.new do |y|
      requests.each do |req|
        text, goodbye = bot.reply(req.message)
        y << Basic::Service::V1::TalkResponse.new(answer: text)
        break if goodbye
      end
    end
  end

  def background(req, _call)
    count = req.processes.to_i
    count = 1 if count <= 0
    utils = Utils::Utils.new

    started_at = Time.now
    rng = Random.new # seed if you want reproducible timings
    q = Queue.new
    threads = []
    responses = []

    # fan-out: kick off N background workers
    count.times do |idx|
      process_id = idx + 1
      threads << Thread.new(process_id) do |pid|
        # each “fake service” sleeps 1–3s, then returns a response
        sleep rng.rand(1.0..3.0)
        q << utils.fake_service_response("service-#{pid}", protocol: [:rest, :grpc, :rpc, :ws, :mqtt, :amqp, :graphql, :sql, :file].sample)
      rescue => e
        # push an error marker into the queue so we still make progress
        q << e
      end
    end

    Enumerator.new do |y|
      # initial progress tick (empty results yet)
      y << utils.build_background_response(
        state: Basic::Service::V1::State::STATE_PROCESS,
        started_at: started_at,
        completed_at: nil,
        responses: []
      )

      remaining = count
      while remaining > 0
        item = q.pop # blocks until any worker finishes
        if item.is_a?(Exception)
          # optional: surface errors as a synthetic response entry
          responses << Basic::Service::V1::SomeServiceResponse.new(
            id: SecureRandom.uuid,
            name: "background-error",
            version: "v1",
            data: Basic::Service::V1::SomeServiceData.new(
              value: item.message,
              type: "error"
            )
          )
        else
          responses << item
          remaining -= 1
        end

        # stream an updated snapshot after every completion
        y << utils.build_background_response(
          state: Basic::Service::V1::State::STATE_PROCESS,
          started_at: started_at,
          completed_at: nil,
          responses: responses.dup # dup so the message keeps this snapshot
        )
      end

      # all done → final COMPLETE with full set
      begin
        threads.each(&:join)
      rescue
        nil
      end
      y << utils.build_background_response(
        state: Basic::Service::V1::State::STATE_COMPLETE,
        started_at: started_at,
        completed_at: Time.now,
        responses: responses
      )
    rescue GRPC::BadStatus => e
      # client cancelled or stream error → stop workers
      threads.each { |t|
        begin
          t.kill
        rescue
          nil
        end
      }
      warn "Background stream aborted: #{e.code} (#{e.message})"
    rescue => e
      threads.each { |t|
        begin
          t.kill
        rescue
          nil
        end
      }
      warn "Background stream error: #{e.class}: #{e.message}"
    end
  end
end

if $0 == __FILE__
  cert_dir = File.expand_path("certs", __dir__)
  server_crt = File.read(File.join(cert_dir, "local.crt"))
  server_key = File.read(File.join(cert_dir, "local.key"))

  creds = GRPC::Core::ServerCredentials.new(
    nil,
    [{private_key: server_key, cert_chain: server_crt}],
    false
  )

  addr = "127.0.0.1:50443"
  s = GRPC::RpcServer.new
  s.add_http2_port(addr, creds)
  s.handle(BasicServiceV1.new)

  # add gRPC health
  s.handle(Grpc::Health::Server.new)

  # add reflection API
  s.handle(GrpcReflection::Server)
  s.handle(GrpcReflection::ServerAlpha)

  # Run server in its own thread
  t = Thread.new { s.run_till_terminated }

  # Self-pipe trick so traps stay trivial/safe
  r, w = IO.pipe
  Signal.trap("INT") {
    begin
      w.write(".")
    rescue
      nil
    end
  }
  Signal.trap("TERM") {
    begin
      w.write(".")
    rescue
      nil
    end
  }

  puts "BasicService (TLS) listening on #{addr} ..."

  # Block here until a signal arrives
  begin
    r.read(1)  # returns after trap writes a byte
    puts "\nShutting down gracefully..."
    # Call stop from the main thread (NOT in the trap)
    s.stop
    t.join       # wait for the run thread to exit cleanly
    puts "Server stopped cleanly."
  rescue => e
    warn "Shutdown error: #{e.class}: #{e.message}"
  ensure
    begin
      r.close
    rescue
      nil
    end
    begin
      w.close
    rescue
      nil
    end
  end
end
