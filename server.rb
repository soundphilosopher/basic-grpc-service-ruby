require "bundler/setup"
require "grpc_reflection"
require "grpc"

require_relative "lib/health"
require_relative "lib/service"

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

  # add service
  s.handle(BasicServiceV1.new)

  # add gRPC health
  s.handle(Grpc::Health::Service::Experimental.new)

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
