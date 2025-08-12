Gem::Specification.new do |spec|
  spec.name = "basic-grpc-service"
  spec.version = "0.1.0"
  spec.authors = ["Carsten Vuellings"]
  spec.email = ["carsten.vuellings@gmail.com"]

  spec.summary = "Basic gRPC service generated code"
  spec.description = "Generated Ruby code for Basic gRPC service using buf + grpc-tools."
  spec.license = "UNLICENSE"

  spec.files = Dir.glob("sdk/**/*")
  spec.require_paths = ["sdk"]

  spec.add_dependency "grpc"
  spec.add_dependency "google-protobuf"
end
