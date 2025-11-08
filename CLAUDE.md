# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-language gRPC key/value server/client implementation testing cross-language TLS compatibility. The primary goal is testing mTLS with different elliptic curves (secp256r1, secp384r1, secp521r1) across 7 language implementations.

**Critical Context**: This project tests compatibility with HashiCorp's `go-plugin` which requires P-521 (secp521r1) curves. Currently only Go clients/servers work properly with secp521r1 certificates - other languages fail despite OpenSSL support.

## Language Implementations

- **Go** (`go/`): Server and client in `go-kv-server.go` and `go-kv-client.go`
- **Python** (`python/`): Server and client in `example-py-server.py` and `example-py-client.py`
- **Ruby** (`ruby/`): Server and client in `rb-kv-server.rb` and `rb-kv-client.rb`
- **Rust** (`rust/`): Server and client in `src/server.rs` and `src/client.rs` (⚠️ limited cross-language compatibility)
- **Node.js** (`nodejs/`): Server and client in `node-kv-server.js` and `node-kv-client.js`
- **C#** (`csharp/`): Client and server - `Program.cs` (client), `ServerProgram.cs` (server)
- **PHP** (`php/`): Server and client in `php-kv-server.php` and `php-kv-client.php`

## Environment Setup

**CRITICAL**: Always source `env.sh` before running any client/server:

```bash
source env.sh
```

This script:
- Loads mTLS certificates into environment variables (`PLUGIN_CLIENT_CERT`, `PLUGIN_CLIENT_KEY`, `PLUGIN_SERVER_CERT`, `PLUGIN_SERVER_KEY`)
- Configures curve algorithms (currently defaults to `ec-secp384r1`)
- Sets up gRPC endpoints (`PLUGIN_HOST`, `PLUGIN_PORT`, `PLUGIN_SERVER_ENDPOINT`)
- Defines helpful aliases for running clients/servers

### Key Environment Variables

- `PLUGIN_CLIENT_ALGO` / `PLUGIN_SERVER_ALGO`: Elliptic curve algorithm (ec-secp256r1, ec-secp384r1, ec-secp521r1)
- `PLUGIN_HOST`: Default is `localhost`
- `PLUGIN_PORT`: Default is `50051`
- Certificate environment variables are PEM-formatted strings loaded from `certs/` directory

## Building and Running

### Go

```bash
# Build (from go/ directory)
cd go && ./build.sh

# Or use the alias
go-build

# Run server
go-server

# Run client
go-client
```

The `build.sh` script:
- Cleans previous builds
- Runs `go mod tidy`
- Builds binaries to `go/bin/go-kv-client` and `go/bin/go-kv-server`

### Python

Python uses `uv` for dependency management:

```bash
# Install dependencies
uv sync

# Run server
py-server

# Run client
py-client
```

Dependencies are defined in `pyproject.toml`. Key packages:
- `grpcio` for gRPC
- `cryptography` for TLS operations
- `rich` for logging

### Ruby

Ruby uses `bundler` for dependency management. **Requires Ruby 3.0+** (system Ruby 2.6 is too old).

```bash
# Install dependencies (first time)
cd ruby
bundle install

# Run server
rb-server

# Run client
rb-client
```

Required gems:
- `grpc` for gRPC (requires Ruby >= 3.0)
- `grpc-tools` for protobuf code generation

**Note:** Use `rv` (Ruby version manager) to install Ruby 3.2+:
```bash
rv ruby install 3.2
```

### Rust

Rust uses `cargo` for dependency management and building.

```bash
# Build (from rust/ directory)
cd rust
cargo build --release

# Or from project root
cargo build --release --manifest-path=rust/Cargo.toml

# Run server (CA:FALSE mode - default)
./rust/target/release/rust-kv-server

# Run server (CA:TRUE mode - experimental)
./rust/target/release/rust-kv-server --ca-mode=true

# Run client (CA:FALSE mode - default)
./rust/target/release/rust-kv-client

# Run client (CA:TRUE mode - experimental)
./rust/target/release/rust-kv-client --ca-mode=true
```

Dependencies are defined in `rust/Cargo.toml`. Key crates:
- `tonic` for gRPC with TLS support
- `prost` for Protocol Buffers
- `rustls` with custom certificate verifiers
- `tokio` for async runtime

**Important Notes:**
- Rust uses **CA:FALSE certificates** by default (RFC-compliant)
- Other languages use **CA:TRUE certificates** (go-plugin compatible)
- This creates **limited cross-language compatibility**:
  - ✅ Rust ↔ Rust works (all curves)
  - ✅ Rust client → Ruby server works (Ruby is lenient)
  - ❌ Rust ↔ Go/Python/C# fails (certificate mismatch)
- See `RUST-INTEGRATION.md` for detailed compatibility matrix and solutions

**Certificate Modes:**
- `--ca-mode=false` (default): Uses `ca-false-{curve}-mtls-*.crt` files
- `--ca-mode=true` (experimental): Uses standard `{curve}-mtls-*.crt` files (has tonic limitations)

### Node.js

Node.js uses dynamic proto loading via `@grpc/proto-loader`, eliminating the need for code generation.

```bash
# Install dependencies (first time)
cd nodejs
npm install

# Run server
node-server

# Run client
node-client
```

Dependencies are defined in `nodejs/package.json`. Key packages:
- `@grpc/grpc-js` for gRPC (v1.9.0)
- `@grpc/proto-loader` for dynamic proto loading

**Key Features:**
- Dynamic proto loading (no code generation needed)
- Full mTLS support
- Accepts CA:TRUE certificates (cross-language compatible)
- Simple setup - just `npm install` and run

### C#

C# has both client and server implementations.

**Client:**
```bash
# Build client
cs-build

# Run client
cs-client
```

**Server:**
```bash
# Build server
cd csharp
dotnet build CSharpGrpcServer.csproj

# Run server
cs-server
```

Dependencies are defined in `.csproj` files. Key packages:
- `Grpc.AspNetCore` (server) or `Grpc.Net.Client` (client) for gRPC
- `Google.Protobuf` for Protocol Buffers
- `Serilog` for structured logging (server)

**Server Features:**
- ASP.NET Core + Kestrel
- HTTP/2 with TLS 1.2/1.3
- mTLS with client certificate validation
- Comprehensive debug/trace logging with certificate details
- Production-ready implementation

**Note:** The server has extensive logging for debugging TLS handshakes and certificate validation.

### PHP

PHP uses Composer for dependency management and requires PHP 8.0+.

```bash
# Install dependencies (first time)
cd php
composer install

# Generate proto files
./generate-proto.sh

# Run server
php-server

# Run client
php-client
```

Dependencies are defined in `composer.json`. Key packages:
- `grpc/grpc` for gRPC (v1.57+)
- `google/protobuf` for Protocol Buffers
- `grpc/grpc-tools` for proto code generation (dev dependency)

**Key Features:**
- Dynamic certificate handling (creates temp files from env vars)
- Full mTLS support
- Comprehensive emoji logging matching other languages
- In-memory key-value store (Get/Put methods)
- Certificate inspection and detailed logging
- TLS 1.2/1.3 support

**Proto Generation:**
PHP requires `protoc` and `grpc_php_plugin` to generate client/server code from proto files:
```bash
cd php
./generate-proto.sh
```

**Dependencies to Install:**
```bash
# macOS
brew install composer protobuf grpc

# Install PHP gRPC extension
pecl install grpc
```

**Note:** PHP gRPC requires certificate file paths (not PEM strings), so the implementation creates temporary files in `/tmp/grpc-kv-php` from environment variables.

## Certificate Management

Certificates are stored in `certs/` directory with naming pattern:
```
ec-{curve}-mtls-{client|server}.{crt|key|cnf}
```

Available curves:
- `ec-secp256r1`: 256-bit curve (works cross-language)
- `ec-secp384r1`: 384-bit curve (works cross-language, current default)
- `ec-secp521r1`: 521-bit curve (required for go-plugin compatibility)

### Switching Elliptic Curves

To switch curves, set environment variables before sourcing `env.sh`:

```bash
# Use secp521r1 (P-521) for HashiCorp go-plugin compatibility
export PLUGIN_CLIENT_ALGO=ec-secp521r1
export PLUGIN_SERVER_ALGO=ec-secp521r1
source env.sh

# Or use secp384r1 (default)
export PLUGIN_CLIENT_ALGO=ec-secp384r1
export PLUGIN_SERVER_ALGO=ec-secp384r1
source env.sh
```

### P-521 Support Improvements

Recent changes have improved P-521 (secp521r1) support across all languages:

**Python**: Added `GRPC_SSL_CIPHER_SUITES` environment variable configuration and extended channel options for better TLS negotiation.

**Ruby**: Added `GRPC_SSL_CIPHER_SUITES` environment variable configuration and increased SSL handshake timeout for P-521.

**Go**: Already has full P-521 support with explicit curve preferences in TLS configuration.

**Testing**: Use the `test-cross-language.sh` script to verify all language combinations work with a specific curve:

```bash
# Test with secp384r1 (default)
./test-cross-language.sh ec-secp384r1

# Test with secp521r1
./test-cross-language.sh ec-secp521r1
```

## Protocol Buffers

The protobuf definition is in `proto/kv.proto`:

```protobuf
service KV {
    rpc Get(GetRequest) returns (GetResponse);
    rpc Put(PutRequest) returns (Empty);
}
```

### Regenerating Proto Files

**Go** (uses buf):
```bash
cd go
buf generate  # Uses buf.gen.yaml config
```

**Python**:
```bash
python -m grpc_tools.protoc -I proto \
    --python_out=python/proto \
    --grpc_python_out=python/proto \
    proto/kv.proto
```

**Ruby**:
```bash
grpc_tools_ruby_protoc --ruby_out=ruby --grpc_out=ruby proto/kv.proto
```

## Project Structure

```
.
├── proto/           # Protobuf definitions and generated Go code
├── go/              # Go implementation
│   ├── proto/       # Generated Go proto files
│   └── bin/         # Compiled binaries
├── python/          # Python implementation
│   ├── proto/       # Generated Python proto files
│   └── utils/       # Certificate and logging helpers
├── ruby/            # Ruby implementation
│   └── proto/       # Generated Ruby proto files
├── rust/            # Rust implementation
│   ├── src/         # Source files (client.rs, server.rs, lenient_verifier.rs)
│   └── target/      # Compiled binaries (rust-kv-client, rust-kv-server)
├── nodejs/          # Node.js implementation
│   ├── node-kv-server.js # Server implementation
│   ├── node-kv-client.js # Client implementation
│   └── package.json # Dependencies (uses dynamic proto loading)
├── csharp/          # C# implementation
│   ├── Program.cs   # Client entry point
│   ├── ServerProgram.cs # Server entry point
│   ├── KVServiceImpl.cs # Server service implementation
│   └── *.csproj     # Project files (client and server)
├── php/             # PHP implementation
│   ├── php-kv-server.php # Server implementation
│   ├── php-kv-client.php # Client implementation
│   ├── composer.json # Dependencies
│   ├── generate-proto.sh # Proto generation script
│   └── README.md    # PHP-specific documentation
├── certs/           # mTLS certificates for different curves
│   ├── ec-*.crt     # CA:TRUE certificates (go-plugin compatible)
│   └── ca-false-*.crt # CA:FALSE certificates (RFC-compliant, for Rust)
├── docs/            # Debugging documentation
├── RUST-INTEGRATION.md # Rust compatibility analysis
├── P521-IMPROVEMENTS.md # P-521 curve improvements
└── env.sh           # Environment setup script
```

## Testing Cross-Language Compatibility

### Quick Manual Testing

The main testing pattern is running a server in one language and client in another:

```bash
# Terminal 1: Start Go server
source env.sh
go-server

# Terminal 2: Test with Python client
source env.sh
py-client

# Terminal 3: Test with Ruby client
source env.sh
rb-client
```

### Comprehensive Matrix Testing

Use `test-curve-matrix.sh` to test all language combinations across all curves automatically:

```bash
./test-curve-matrix.sh
```

This script:
- Tests all server/client language combinations (Go, Python, Ruby, Rust, Node.js, C#, PHP)
- Tests all three elliptic curves (secp256r1, secp384r1, secp521r1)
- Produces a color-coded matrix showing which combinations work
- Provides summary statistics and key findings
- **Total tests**: 144 (48 combinations × 3 curves) when PHP is installed
- **Without PHP**: 108 tests (36 combinations × 3 curves)

**Known Compatibility Issues:**
- **Rust**: Limited cross-language compatibility due to CA:FALSE/CA:TRUE certificate mismatch
  - ✅ Rust ↔ Rust works (all curves)
  - ✅ Rust client → Ruby server works (all curves)
  - ✅ Rust server (--ca-mode=true) ↔ Go/Python/Ruby/Node.js works
  - ❌ Rust client ↔ Go/Python/C# fails (certificate mismatch)
  - See `RUST-INTEGRATION.md` for detailed analysis and solutions
- **P-521 (secp521r1)**: Limited to specific language combinations
  - ✅ Go ↔ Go works
  - ✅ Go ↔ Ruby works
  - ✅ Ruby ↔ Ruby works
  - ✅ Rust ↔ Rust works
  - ❓ Node.js and C# need testing with P-521
  - ❌ Python has known P-521 issues
  - See `P521-IMPROVEMENTS.md` for attempted fixes
- **C# Server**: Simplified certificate validation
  - ✅ Works with Go client (verified)
  - ⚠️ May have issues with some clients (uses thumbprint comparison instead of chain validation)

### Single-Curve Testing

Use `test-cross-language.sh` to test all combinations with a specific curve:

```bash
./test-cross-language.sh ec-secp384r1
./test-cross-language.sh ec-secp521r1
```

## Debugging TLS Issues

See `DEBUGGING.md` and `docs/` for detailed debugging information.

### Quick TLS Verification

Use OpenSSL to test server connectivity:

```bash
source env.sh
ossl-client  # Alias to test mTLS handshake
ossl-check-server-cert  # Verify server certificate
```

### Common Issues

1. **"Failed to load certificates"**: Re-source `env.sh` to reload certificate environment variables
2. **secp521r1 handshake failures**: Known issue - Python/Ruby/C# do not work with P-521 curves despite OpenSSL support
3. **Port already in use**: Server from previous run still running on port 50051

## Python Utilities

- `python/utils/certificate_helper.py`: TLS certificate loading and inspection
- `python/utils/logging_helper.py`: Structured logging with emoji prefixes
- `tools/tls-check.py`: TLS configuration verification tool

## Development Notes

- The repository uses auto-commit, do NOT attempt git rollbacks
- Python uses `uv` for fast dependency management
- All servers default to port 50051
- Servers include extensive structured logging for debugging TLS handshakes
- The codebase extensively uses emoji in logging for visual debugging
