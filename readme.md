# 🚀 Basic gRPC Service in Ruby

> A blazingly fast, TLS-secured gRPC service written in Ruby with CloudEvents support and reflection API! 💎

[![Ruby](https://img.shields.io/badge/ruby-2.7+-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-UNLICENSE-green.svg)](./LICENSE)
[![gRPC](https://img.shields.io/badge/gRPC-1.74.1-blue.svg)](https://grpc.io/)
[![Buf](https://img.shields.io/badge/Buf-Protocol%20Buffers-orange.svg)](https://buf.build/)
[![TLS](https://img.shields.io/badge/TLS-Secured-brightgreen.svg)](https://github.com/FiloSottile/mkcert)

## 🎯 What's This All About?

Welcome to the **Basic gRPC Service**, a production-ready Ruby implementation that showcases modern gRPC development practices! This service features:

- 🔐 **TLS/SSL encryption** with local certificates via `mkcert`
- ⚡ **High-performance gRPC** communication
- 🌩️ **CloudEvents integration** for event-driven architecture
- 🔍 **gRPC reflection** for easy service discovery
- 🏥 **Health checking** built-in
- 📦 **Buf CLI** for Protocol Buffer management
- 💎 **Pure Ruby goodness** with modern practices

## ✨ Features

- **Multi-service Architecture**: Hello, Talk, and Background processing services
- **Event-driven Design**: CloudEvents support for async operations
- **State Management**: Process tracking with detailed state transitions
- **Developer Experience**: Hot-reload, reflection API, and comprehensive tooling
- **Security First**: TLS encryption for all communications
- **Standards Compliant**: Uses buf.build for Protocol Buffer linting and generation

## 🚀 Quick Start

### Prerequisites

- 💎 Ruby 2.7 or higher
- 📦 Bundler
- 🛡️ mkcert (for local TLS certificates)
- 🔧 buf CLI (for Protocol Buffer management)

### Installation

1. **Clone and setup:**
   ```bash
   git clone <your-repo-url>
   cd basic-grpc-service-ruby
   bundle install
   ```

2. **Generate certificates (first time only):**
   ```bash
   # Install mkcert if you haven't already
   # macOS: brew install mkcert
   # Linux: see https://github.com/FiloSottile/mkcert#installation

   mkcert -install
   mkcert -cert-file certs/local.crt -key-file certs/local.key localhost 127.0.0.1
   ```

3. **Start the server:**
   ```bash
   ruby server.rb
   ```

4. **Test it's working:**
   ```bash
   # The server will be listening on 127.0.0.1:50443 with TLS
   # Use your favorite gRPC client or grpcurl to test!
   ```

## 📁 Project Structure

```
basic-grpc-service-ruby/
├── 📋 proto/                    # Protocol Buffer definitions
│   ├── basic/service/v1/        # Service definitions
│   ├── basic/v1/               # Basic message types
│   └── io/cloudevents/v1/      # CloudEvents schema
├── 🔧 sdk/                     # Generated Ruby code (via buf)
├── 🛡️ certs/                   # TLS certificates (mkcert)
├── 📚 lib/                     # Service implementations
├── ⚙️ buf.yaml                 # Buf configuration
├── 🔄 buf.gen.yaml             # Code generation config
├── 💎 basic-grpc-service.gemspec # Gem specification
├── 🚀 server.rb                # Main server entry point
└── 📖 README.md                # You are here!
```

## 🛠️ Development

### Code Generation with Buf

We use [buf.build](https://buf.build/) for managing Protocol Buffers:

```bash
# Generate Ruby code from proto files
buf generate

# Lint proto files
buf lint

# Check for breaking changes
buf breaking --against '.git#branch=main'
```

### Service Implementation

The service includes three main RPC methods:

- **Hello**: Simple greeting with CloudEvent response
- **Talk**: Conversational interface
- **Background**: Long-running process simulation

### Testing with grpcurl

```bash
# List available services (thanks to reflection!)
grpcurl 127.0.0.1:50443 list

# Call the Hello service
grpcurl -d '{"message":"World"}' \
  127.0.0.1:50443 basic.service.v1.BasicService/Hello

# Check health status
grpcurl 127.0.0.1:50443 grpc.health.v1.Health/Check
```

## 🔐 TLS Configuration

This service uses TLS encryption for all communications. Certificates are managed with `mkcert` for local development:

```bash
# Generate new certificates
mkcert -cert-file certs/local.crt -key-file certs/local.key localhost 127.0.0.1

# The server automatically loads certificates from the certs/ directory
```

For production, replace the local certificates with proper CA-signed certificates.

## 🌩️ CloudEvents Integration

The service integrates with [CloudEvents](https://cloudevents.io/) specification for event-driven architecture:

- Events are properly structured with CloudEvents metadata
- Supports both synchronous and asynchronous processing patterns
- Compatible with event streaming platforms

## 📊 Monitoring & Health

Built-in health checking endpoint following gRPC health checking protocol:

```ruby
# Health check service is automatically registered
# Use standard gRPC health check clients to monitor service status
```

## 🧪 Development Tips

- Use `standard` for Ruby code formatting
- Generated code is in `sdk/` - don't edit manually!
- Proto files follow buf.build standards
- TLS certificates are git-ignored for security

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run `standard` for code formatting
5. Test your changes
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## 📄 License

This project is unlicensed and released into the public domain. See the `UNLICENSE` file for details.

## 🙏 Acknowledgments

- [gRPC](https://grpc.io/) for the amazing RPC framework
- [buf.build](https://buf.build/) for Protocol Buffer tooling excellence
- [mkcert](https://github.com/FiloSottile/mkcert) for easy local TLS setup
- [CloudEvents](https://cloudevents.io/) for event standardization

---

**Made with ❤️ by Carsten Vuellings**

*Happy gRPC-ing! 🎉
