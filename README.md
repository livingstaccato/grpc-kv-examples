# Multi-Language gRPC Key/Value Store

Cross-language gRPC implementation testing mTLS compatibility across multiple elliptic curves and programming languages.

## Overview

This project implements a simple key/value gRPC service in multiple languages to test cross-language TLS/mTLS compatibility, particularly focusing on:

- **Elliptic curve support** (P-256, P-384, P-521)
- **Mutual TLS (mTLS)** authentication
- **Certificate constraint handling** (CA:TRUE vs CA:FALSE)
- **HashiCorp go-plugin compatibility** (requires P-521)

## Language Implementations

| Language | Client | Server | Status | Notes |
|----------|--------|--------|--------|-------|
| **Go** | ✅ | ✅ | Fully working | Best P-521 support |
| **Python** | ✅ | ✅ | Working | P-521 issues |
| **Ruby** | ✅ | ✅ | Working | Lenient cert validation |
| **Rust** | ✅ | ✅ | Partial | Server works with `--ca-mode=true` |
| **Node.js** | ✅ | ✅ | Fully working | Dynamic proto loading |
| **C#** | ✅ | ✅ | Working | Server with comprehensive logging |

## Quick Start

```bash
# 1. Source environment (loads certificates)
source env.sh

# 2. Start a server (choose one)
go-server      # Go server
py-server      # Python server
rb-server      # Ruby server
./rust/target/release/rust-kv-server --ca-mode=true  # Rust server
node-server    # Node.js server
cs-server      # C# server

# 3. Run a client (in another terminal)
source env.sh
go-client      # Go client
py-client      # Python client
rb-client      # Ruby client
./rust/target/release/rust-kv-client  # Rust client
node-client    # Node.js client
cs-client      # C# client
```

## Building

### Go
```bash
cd go && ./build.sh
```

### Python
```bash
uv sync  # Install dependencies
```

### Ruby
```bash
cd ruby && bundle install  # Requires Ruby 3.0+
```

### Rust
```bash
cd rust && cargo build --release
```

### Node.js
```bash
cd nodejs && npm install
```

### C#

**Client:**
```bash
cd csharp && dotnet build
```

**Server:**
```bash
cd csharp && dotnet build CSharpGrpcServer.csproj
```

## Testing

### Comprehensive Matrix Test

Test all language combinations across all curves:

```bash
./test-curve-matrix.sh
```

**Results**: 60 tests (20 combinations × 3 curves)
- Overall: 61% passing (37/60)
- P-256: 70% passing
- P-384: 70% passing
- P-521: 45% passing

### Single Curve Test

Test specific curve:

```bash
./test-cross-language.sh ec-secp384r1
./test-cross-language.sh ec-secp521r1
```

## Compatibility Matrix

### Go ↔ All Languages

| Client → Server | P-256 | P-384 | P-521 |
|-----------------|-------|-------|-------|
| Go → Go | ✅ | ✅ | ✅ |
| Go → Python | ✅ | ✅ | ❌ |
| Go → Ruby | ✅ | ✅ | ✅ |
| Go → Rust | ❌ | ❌ | ❌ |
| Python → Go | ✅ | ✅ | ❌ |
| Ruby → Go | ✅ | ✅ | ❌ |
| Rust → Go | ❌ | ❌ | ❌ |

### Rust Compatibility

**Working**:
- ✅ Rust ↔ Rust (all curves)
- ✅ Rust client → Ruby server (all curves)

**Not Working**:
- ❌ Rust ↔ Go/Python/C# (certificate mismatch)

**Root Cause**: Rust uses CA:FALSE certificates (RFC-compliant) while other languages use CA:TRUE certificates (go-plugin compatible).

**Solution**: See `RUST-INTEGRATION.md` for detailed analysis and solutions.

## Known Issues

### 1. Rust Cross-Language Compatibility

**Issue**: Rust server rejects CA:TRUE certificates from Go/Python/C# clients.

**Workaround**: Use Rust only with:
- Other Rust clients/servers
- Ruby (which accepts CA:FALSE certs)

**Details**: `RUST-INTEGRATION.md`

### 2. Python P-521 Support

**Issue**: Python clients/servers fail with P-521 certificates despite OpenSSL support.

**Status**: Attempted fixes in `P521-IMPROVEMENTS.md`, partial success.

**Workaround**: Use P-256 or P-384 for Python.

### 3. C# Server

**Status**: Not implemented.

**Workaround**: Use C# client with Go/Python/Ruby servers.

## Certificate Management

Two certificate types:

### CA:TRUE Certificates (Standard)
- Used by: Go, Python, Ruby, C#
- Location: `certs/ec-{curve}-mtls-*.crt`
- Compatible with: HashiCorp go-plugin
- Constraint: `basicConstraints=CA:TRUE`

### CA:FALSE Certificates (RFC-Compliant)
- Used by: Rust (default)
- Location: `certs/ca-false-ec-{curve}-mtls-*.crt`
- Compatible with: Strict RFC 5280 validation
- Constraint: `basicConstraints=CA:FALSE`

### Switch Curves

```bash
export PLUGIN_CLIENT_ALGO=ec-secp521r1
export PLUGIN_SERVER_ALGO=ec-secp521r1
source env.sh
```

## Project Structure

```
├── go/                    # Go implementation
├── python/                # Python implementation
├── ruby/                  # Ruby implementation
├── rust/                  # Rust implementation
├── csharp/                # C# implementation
├── proto/                 # Protocol Buffer definitions
├── certs/                 # TLS/mTLS certificates
├── env.sh                 # Environment setup script
├── test-curve-matrix.sh   # Comprehensive test matrix
├── RUST-INTEGRATION.md    # Rust compatibility analysis
├── P521-IMPROVEMENTS.md   # P-521 improvements documentation
└── DEBUGGING.md           # TLS debugging guide
```

## Documentation

- **`CLAUDE.md`**: Developer guide and project instructions
- **`RUST-INTEGRATION.md`**: Rust implementation and compatibility details
- **`P521-IMPROVEMENTS.md`**: P-521 curve support improvements
- **`DEBUGGING.md`**: TLS troubleshooting guide

## Requirements

- **Go**: 1.23+
- **Python**: 3.13+ with `uv`
- **Ruby**: 3.0+ (use `rv` to install)
- **Rust**: 1.80+ with Cargo
- **C#**: .NET 9.0+
- **OpenSSL**: 3.0+

## Contributing

See `CLAUDE.md` for development guidelines and project context.

## Goals

- [x] Implement clients/servers in multiple languages
- [x] Support mTLS with multiple elliptic curves
- [x] Test cross-language compatibility
- [x] Document compatibility issues and solutions
- [ ] Achieve 100% cross-language compatibility
- [ ] Implement C# server
- [ ] Fix Rust cross-language compatibility
- [ ] Resolve Python P-521 issues

## License

MIT

---

*For detailed implementation notes, see `CLAUDE.md`*
*For Rust-specific compatibility, see `RUST-INTEGRATION.md`*
*For P-521 improvements, see `P521-IMPROVEMENTS.md`*
