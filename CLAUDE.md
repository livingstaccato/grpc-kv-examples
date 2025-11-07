# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-language gRPC key/value server/client implementation testing cross-language TLS compatibility. The primary goal is testing mTLS with different elliptic curves (secp256r1, secp384r1, secp521r1) across Go, Python, Ruby, and C# implementations.

**Critical Context**: This project tests compatibility with HashiCorp's `go-plugin` which requires P-521 (secp521r1) curves. Currently only Go clients/servers work properly with secp521r1 certificates - other languages fail despite OpenSSL support.

## Language Implementations

- **Go** (`go/`): Server and client in `go-kv-server.go` and `go-kv-client.go`
- **Python** (`python/`): Server and client in `example-py-server.py` and `example-py-client.py`
- **Ruby** (`ruby/`): Server and client in `rb-kv-server.rb` and `rb-kv-client.rb`
- **C#** (`csharp/`): Client implementation (note: C# has compatibility issues)

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

### C#

```bash
# Build
cs-build

# Run client
cs-client
```

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
├── csharp/          # C# implementation
├── certs/           # mTLS certificates for different curves
├── docs/            # Debugging documentation
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
- Tests all server/client language combinations (Go, Python, Ruby, C#)
- Tests all three elliptic curves (secp256r1, secp384r1, secp521r1)
- Produces a color-coded matrix showing which combinations work
- Provides summary statistics and key findings

**Known Compatibility Issues:**
- secp384r1: Works well for Go ↔ Python, Go ↔ Go, Python ↔ Python
- secp521r1: Only works for Go ↔ Go (Python, Ruby, C# fail with P-521 servers)
- C# client only (no server implementation)

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
