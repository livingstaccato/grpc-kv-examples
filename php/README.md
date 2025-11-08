# PHP gRPC Key-Value Implementation

PHP implementation of the gRPC Key-Value service with mTLS and comprehensive emoji logging.

## Requirements

- **PHP**: 8.0 or higher
- **Composer**: Package manager for PHP
- **protoc**: Protocol Buffer compiler
- **grpc_php_plugin**: gRPC PHP code generator plugin

## Setup

### 1. Install Composer

```bash
# macOS (via Homebrew)
brew install composer

# Or download from https://getcomposer.org/
```

### 2. Install PHP Dependencies

```bash
cd php
composer install
```

This will install:
- `grpc/grpc`: PHP gRPC extension
- `google/protobuf`: Protocol Buffers runtime
- `grpc/grpc-tools`: Code generation tools (dev dependency)

### 3. Generate Proto Files

```bash
cd php
./generate-proto.sh
```

This generates PHP classes from `proto/kv.proto` into `php/proto/`.

## Running

### Server

```bash
source env.sh
php php/php-kv-server.php
# or use the alias
php-server
```

### Client

```bash
source env.sh
php php/php-kv-client.php
# or use the alias
php-client
```

## Features

### Comprehensive Emoji Logging

Both server and client include extensive emoji logging matching other language implementations:

**Server Logging**:
- 🚀 🔄 Startup and initialization
- 📂 Certificate loading
- 🔐 Certificate details (Subject, Issuer, dates, serial, etc.)
- 🔧 TLS configuration
- 🔍 📥 Request processing (Get)
- 📝 📥 Request processing (Put)
- 💾 Storage operations
- ✅ Success indicators

**Client Logging**:
- 🚀 Startup
- 📂 Environment variable checks
- 🔐 Certificate details and loading
- ⚙️ TLS configuration
- 🔌 Connection establishment
- 📝 Put requests
- 🔍 Get requests
- 📦 Response data
- ✅ Success indicators

### mTLS Support

- Full mutual TLS authentication
- Client certificate validation
- Certificate chain inspection
- Detailed TLS handshake logging

### In-Memory Key-Value Store

- Simple dictionary-based storage
- Get/Put operations
- Default "OK" response for missing keys

## Implementation Notes

- Uses temporary files for certificates (PHP gRPC requires file paths)
- Certificates are loaded from environment variables (via `env.sh`)
- Supports TLS 1.2 and TLS 1.3
- Compatible with all other language implementations in the project

## Troubleshooting

### Missing gRPC Extension

If you get "Call to undefined function Grpc\..." errors:

```bash
# Install PHP gRPC extension
pecl install grpc
```

### Proto Generation Fails

Ensure protoc and grpc_php_plugin are installed:

```bash
# macOS
brew install protobuf grpc

# Linux
apt-get install protobuf-compiler
```

### Certificate Errors

Make sure to source `env.sh` before running:

```bash
source env.sh
```

This loads the mTLS certificates into environment variables.

## Testing

Test with other language implementations:

```bash
# Terminal 1: Start PHP server
source env.sh
php-server

# Terminal 2: Test with Go client
source env.sh
go-client

# Terminal 3: Test with Python client
source env.sh
py-client
```

##Cross-Language Compatibility

PHP should work with all other implementations:
- ✅ Go
- ✅ Python
- ✅ Ruby
- ✅ Rust (with `--ca-mode=true`)
- ✅ Node.js
- ✅ C#

Tested with all three elliptic curves: P-256, P-384, P-521
