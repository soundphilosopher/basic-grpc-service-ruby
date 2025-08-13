require "grpc"
require "google/protobuf"
require "grpc/health/v1/health_services_pb"
require "grpc/health/v1/health_pb"
require "basic/v1/basic_services_pb"
require "grpc_reflection/reflection/v1/reflection_services_pb"
require "grpc_reflection/reflection/v1alpha/reflection_v1alpha_services_pb"

module Grpc
  module Health
    class Server < Grpc::Health::V1::Health::Service
      ServingStatus = ::Grpc::Health::V1::HealthCheckResponse::ServingStatus

      def initialize(default_status: ServingStatus::SERVING)
        @statuses = {}
        @status_mutex = Mutex.new
        @watch_mutex = Mutex.new
        @watch_cv = ConditionVariable.new

        seed_from_descriptor!(Basic::V1::BasicService::Service.service_name, default_status)
        seed_from_descriptor!(Grpc::Health::V1::Health::Service.service_name, default_status)
        seed_from_descriptor!(Reflection::V1::ServerReflection::Service.service_name, default_status)
        seed_from_descriptor!(Reflection::V1alpha::ServerReflection::Service.service_name, default_status)
      end

      def check(req, _call)
        Grpc::Health::V1::HealthCheckResponse.new(status: current_status(req.service.to_s))
      end

      def watch(req, _call)
        svc = req.service.to_s
        last = nil
        loop do
          cur = current_status(svc)
          if cur != last
            yield Grpc::Health::V1::HealthCheckResponse.new(status: cur)
            last = cur
          end
          @watch_mutex.synchronize { @watch_cv.wait(@watch_mutex, 30) }
        end
      end

      # — Runtime control —
      def set_status(service_full_name, status)
        @status_mutex.synchronize { @statuses[service_full_name] = status }
        @watch_mutex.synchronize { @watch_cv.broadcast }
      end

      private

      def seed_from_descriptor!(full_service_name, default_status)
        desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(full_service_name)
        unless desc&.is_a?(Google::Protobuf::ServiceDescriptor)
          raise ArgumentError, "Service descriptor not found for #{full_service_name}. " \
                               "Ensure you required *_services_pb.rb."
        end

        # Use the name you already have instead of desc.full_name (which doesn't exist in Ruby)
        @status_mutex.synchronize { @statuses[full_service_name] ||= default_status }
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
