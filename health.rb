require "grpc"
require "google/protobuf"
require "grpc/health/v1/health_services_pb"
require "grpc/health/v1/health_pb"

module Grpc
  module Health
    class Server < Grpc::Health::V1::Health::Service
      ServingStatus = ::Grpc::Health::V1::HealthCheckResponse::ServingStatus

      def initialize(default_status: ServingStatus::SERVING)
        @statuses = {}
        @ignore_services = Set.new
        @status_mutex = Mutex.new
        @watch_mutex = Mutex.new
        @watch_cv = ConditionVariable.new

        seed_all_services!(default_status)
      end

      def check(req, _call)
        Grpc::Health::V1::HealthCheckResponse.new(status: current_status(req.service.to_s))
      end

      WATCH_WAKE_TIMEOUT = 30

      def watch(req, _call)
        svc = req.service.to_s
        last = nil

        loop do
          cur = current_status(svc)
          if cur != last
            yield Grpc::Health::V1::HealthCheckResponse.new(status: cur)
            last = cur
          end
          @watch_mutex.synchronize { @watch_cv.wait(@watch_mutex, WATCH_WAKE_TIMEOUT) }
        end
      end

      # — Runtime control —
      def set_status(service_full_name, status)
        unless ServingStatus.constants(false).map { |c| ServingStatus.const_get(c) }.include?(status)
          raise ArgumentError, "Invalid ServingStatus: #{status.inspect}"
        end

        @status_mutex.synchronize { @statuses[service_full_name] = status }
        @watch_mutex.synchronize { @watch_cv.broadcast }
      end

      def ignore_service(service_full_name)
        @status_mutex.synchronize { @ignore_services.add(service_full_name) }
      end

      def unignore_service(service_full_name)
        @status_mutex.synchronize { @ignore_services.delete(service_full_name) }
      end

      def refresh_services!(default_status: ServingStatus::SERVING)
        seed_all_services!(default_status)
      end

      def set_overall_status(status)
        set_status("", status)
      end

      private

      def seed_all_services!(default_status)
        services = ObjectSpace.each_object(Class)
          .select { |k| k < GRPC::GenericService && k.respond_to?(:service_name) }
          .map(&:service_name)
          .uniq
        @status_mutex.synchronize do
          services.reject! { |s| @ignore_services.include?(s) }
          services.each { |name| @statuses[name] ||= default_status }
        end
      end

      def current_status(service_full_name)
        # Empty/absent service name → UNKNOWN
        return ServingStatus::UNKNOWN if service_full_name.nil? || service_full_name.empty?

        # Non-empty name → registered? return stored status, else SERVICE_UNKNOWN
        @status_mutex.synchronize do
          @statuses.fetch(service_full_name, ServingStatus::SERVICE_UNKNOWN)
        end
      end
    end
  end
end
