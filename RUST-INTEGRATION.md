# Rust gRPC Implementation - Integration Status

## Overview

This document details the Rust gRPC client/server implementation, test results, and cross-language compatibility status.

## Implementation

The Rust implementation adds mTLS-enabled gRPC client and server with support for two certificate modes:

### Certificate Modes

1. **CA:FALSE Mode** (default, `--ca-mode=false`)
   - Uses RFC-compliant certificates with `basicConstraints=CA:FALSE`
   - Certificate files: `ca-false-{curve}-mtls-{client|server}.{crt|key}`
   - Strict TLS validation via tonic's standard TLS configuration
   - **Status**: ✅ Fully working

2. **CA:TRUE Mode** (`--ca-mode=true`)
   - Uses go-plugin compatible certificates with `basicConstraints=CA:TRUE`
   - Certificate files: `{curve}-mtls-{client|server}.{crt|key}`
   - Custom certificate verifier to bypass CA constraint validation
   - **Status**: ⚠️ Partially working (tonic connector limitation)

### Technical Implementation

**Client** (`rust/src/client.rs`):
- Standard mode: Uses tonic's `ClientTlsConfig` with strict validation
- Lenient mode: Custom `rustls::ClientConfig` with `LenientServerCertVerifier`
- Certificate pinning for additional security
- TLS 1.3 signature verification

**Server** (`rust/src/server.rs`):
- Standard mode: Uses tonic's `ServerTlsConfig` with mTLS
- Lenient mode: Falls back to standard config (not fully implemented)

**Custom Verifier** (`rust/src/lenient_verifier.rs`):
- `LenientServerCertVerifier`: Client-side server cert verification
- `LenientClientCertVerifier`: Server-side client cert verification
- Bypasses CA constraint check while maintaining:
  - Certificate signature verification
  - Expiration date validation
  - Certificate pinning (byte-for-byte matching)
  - TLS handshake proof-of-possession

### Building and Running

```bash
# Build Rust binaries
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

## Test Matrix Results

### Matrix Test Execution

Tested all language combinations across three elliptic curves using `test-curve-matrix.sh`:

**Total Tests**: 60 (20 combinations × 3 curves)
**Passed**: 37 (61%)
**Failed**: 23 (39%)

### Results by Curve

#### P-256 (secp256r1) - 14/20 passing (70%)

| Server → Client | Status | Notes |
|----------------|--------|-------|
| Go → Go        | ✅ PASS | |
| Go → Python    | ✅ PASS | |
| Go → Ruby      | ✅ PASS | |
| **Go → Rust**  | ❌ FAIL | CA cert mismatch |
| Python → Go    | ✅ PASS | |
| Python → Python | ✅ PASS | |
| Python → Ruby  | ✅ PASS | |
| **Python → Rust** | ❌ FAIL | CA cert mismatch |
| Ruby → Go      | ✅ PASS | |
| Ruby → Python  | ✅ PASS | |
| Ruby → Ruby    | ✅ PASS | |
| **Ruby → Rust** | ❌ FAIL | CA cert mismatch |
| **Rust → Go**  | ❌ FAIL | CA cert mismatch |
| **Rust → Python** | ❌ FAIL | CA cert mismatch |
| **Rust → Ruby** | ✅ PASS | Ruby accepts CA:FALSE |
| **Rust → Rust** | ✅ PASS | Both use CA:FALSE |
| Go → C#        | ✅ PASS | |
| Python → C#    | ✅ PASS | |
| Ruby → C#      | ✅ PASS | |
| **Rust → C#**  | ❌ FAIL | CA cert mismatch |

#### P-384 (secp384r1) - 14/20 passing (70%)

Same pattern as P-256. All non-Rust combinations work. Rust combinations limited.

#### P-521 (secp521r1) - 9/20 passing (45%)

| Server → Client | Status | Notes |
|----------------|--------|-------|
| Go → Go        | ✅ PASS | |
| **Go → Python** | ❌ FAIL | Known P-521 Python issue |
| Go → Ruby      | ✅ PASS | |
| **Go → Rust**  | ❌ FAIL | CA cert mismatch |
| **Python → Go** | ❌ FAIL | Known P-521 Python issue |
| **Python → Python** | ❌ FAIL | Known P-521 Python issue |
| Python → Ruby  | ✅ PASS | |
| **Python → Rust** | ❌ FAIL | CA cert + P-521 issues |
| **Ruby → Go**  | ❌ FAIL | P-521 handshake issue |
| **Ruby → Python** | ❌ FAIL | P-521 handshake issue |
| Ruby → Ruby    | ✅ PASS | |
| **Ruby → Rust** | ❌ FAIL | CA cert mismatch |
| **Rust → Go**  | ❌ FAIL | CA cert mismatch |
| **Rust → Python** | ❌ FAIL | CA cert mismatch |
| **Rust → Ruby** | ✅ PASS | Ruby accepts CA:FALSE |
| **Rust → Rust** | ✅ PASS | Both use CA:FALSE |
| Go → C#        | ✅ PASS | |
| Python → C#    | ✅ PASS | |
| Ruby → C#      | ✅ PASS | |
| **Rust → C#**  | ❌ FAIL | CA cert mismatch |

### Success Patterns

✅ **Working Combinations**:
- Rust client ↔ Rust server (all curves)
- Rust client → Ruby server (all curves)

❌ **Failing Combinations**:
- Any language → Rust server (except Ruby and Rust)
- Rust client → Go/Python/C# servers

## Root Cause Analysis

### Certificate Mismatch Issue

The primary issue is a **certificate constraint mismatch** between Rust and other languages:

**Rust Implementation:**
- Defaults to `ca_mode=false`
- Loads `ca-false-{curve}-mtls-*.crt` certificates
- Certificates have `basicConstraints=CA:FALSE` (RFC-compliant)
- Rustls enforces strict validation, rejects CA:TRUE certs via `CaUsedAsEndEntity` error

**Go/Python/Ruby/C# Implementation:**
- Use standard `{curve}-mtls-*.crt` certificates
- Certificates have `basicConstraints=CA:TRUE` (go-plugin compatible)
- Accept both CA:TRUE and CA:FALSE certificates (lenient validation)

**Why Ruby → Rust Works:**
Ruby server is lenient and accepts CA:FALSE certificates from Rust client.

**Why Other → Rust Fails:**
Rust server (even in CA:FALSE mode) validates client certificates against the CA:FALSE client cert. But Go/Python/C# clients present CA:TRUE certificates, causing validation failure.

### Error Examples

**Rust Server Log** (Go client → Rust server):
```
[INFO] 🔐 Certificate CA mode: CA:FALSE (strict validation)
[INFO] 🔐   Client CA: ./certs/ca-false-ec-secp384r1-mtls-client.crt
```
The server expects CA:FALSE client cert, but Go client presents CA:TRUE cert.

**Rust Client Log** (Rust client → Go server):
```
[INFO] 🔐 Certificate CA mode: CA:FALSE (strict validation)
[INFO] 🔐   Server CA: ./certs/ca-false-ec-secp384r1-mtls-server.crt
```
The client expects CA:FALSE server cert, but Go server presents CA:TRUE cert.

### Tonic Connector Limitation

Even with custom certificate verifiers, tonic has a known limitation (issue #2360):
- `connect_with_connector()` allows custom HTTPS connectors
- But internally enforces tonic's own TlsConnector for HTTPS URIs
- This prevents the custom rustls config from being used properly

**What Works:**
- Custom verifier successfully validates and accepts CA:TRUE certs
- TLS handshake completes successfully
- Certificate pinning functions correctly

**What Doesn't Work:**
- Tonic's transport layer rejects the connection after successful cert validation
- Error: `HttpsUriWithoutTlsSupport`

## Potential Solutions

### Option 1: Switch Rust to CA:TRUE Certificates (Simple)

**Approach**: Change Rust default from `ca_mode=false` to `ca_mode=true`

**Changes needed:**
```rust
// rust/src/client.rs and rust/src/server.rs
#[arg(long = "ca-mode", value_name = "BOOL", default_value = "true", ...)]
ca_mode: bool,
```

**Pros:**
- Rust uses same certs as other languages
- Rust client → Ruby/Go/Python servers would work
- Simple one-line change

**Cons:**
- Rust server still rejects CA:TRUE client certs (strict validation)
- Doesn't solve Go/Python → Rust server
- Violates RFC compliance

**Expected Results:**
- ✅ Rust → All languages (Rust client works)
- ❌ All → Rust server (Rust server still strict)

### Option 2: Implement Server-Side Lenient Verifier (Complex)

**Approach**: Complete the server-side custom verifier integration

**Challenges:**
- Tonic's `Server::builder().tls_config()` doesn't accept custom `rustls::ServerConfig`
- Would require using tonic's lower-level APIs or direct hyper integration
- More complex than client-side due to tonic's architecture

**Pros:**
- Would enable full CA:TRUE support
- True cross-language compatibility

**Cons:**
- Significant implementation complexity
- May require forking/patching tonic
- Ongoing maintenance burden

### Option 3: Use CA:FALSE Across All Languages (Ideal)

**Approach**: Generate and use CA:FALSE certificates for all languages

**Implementation:**
1. Generate `ca-false-*` certificates for all curves
2. Modify env.sh to load CA:FALSE certs
3. Update Go/Python/Ruby to use CA:FALSE certs
4. Fully RFC-compliant implementation

**Pros:**
- Proper RFC compliance
- All languages use same cert type
- Rust works without custom verifiers
- Better security posture

**Cons:**
- Breaks go-plugin compatibility (requires CA:TRUE)
- Requires cert regeneration
- Changes needed across all language implementations

### Option 4: Dual Certificate Test Mode (Pragmatic)

**Approach**: Modify test script to use appropriate certs for Rust

**Implementation:**
```bash
# In test-curve-matrix.sh
start_server() {
    local lang=$1
    case $lang in
        rust)
            # Load CA:FALSE certs for Rust
            export RUST_CERT_PREFIX="ca-false-"
            ;;
        *)
            # Load standard CA:TRUE certs for others
            export RUST_CERT_PREFIX=""
            ;;
    esac
}
```

**Pros:**
- Allows testing Rust with appropriate certs
- Doesn't break existing Go/Python/Ruby compatibility
- Documents the limitation clearly

**Cons:**
- Rust still doesn't work with other languages
- Only solves testing, not real-world use

### Option 5: Document Limitation (Current)

**Approach**: Accept and document that Rust has limited cross-language support

**Rust Compatibility Matrix:**
- ✅ Rust ↔ Rust (full support)
- ✅ Rust → Ruby (Ruby is lenient)
- ⚠️ Rust ↔ Go/Python/C# (not supported)

**Use Cases:**
- Pure Rust microservices
- Rust clients talking to Ruby services
- Development/testing with Rust-only stack

## Recommendations

**Short Term (Immediate)**:
1. **Document the limitation** - This document
2. **Update CLAUDE.md** with Rust-specific notes
3. **Update README.md** with compatibility matrix
4. **Create test variant** for Rust-only testing

**Medium Term (Next Sprint)**:
1. **Investigate tonic server-side verifier** integration
2. **Evaluate alternative gRPC frameworks** (e.g., grpc-rs with C++ core)
3. **Consider hybrid approach** - Rust uses CA:TRUE for client, documents server limitation

**Long Term (Future)**:
1. **Contribute to tonic** to add custom verifier support
2. **Standardize on CA:FALSE** across all languages (if go-plugin compatibility not needed)
3. **Implement certificate translation layer** for cross-language compatibility

## Current Status Summary

**What Works** ✅:
- Rust client ↔ Rust server (all curves, CA:FALSE mode)
- Rust client → Ruby server (all curves)
- Custom certificate verifier implementation
- Certificate pinning and validation
- TLS 1.3 support

**What Doesn't Work** ❌:
- Rust server ← Go/Python/C# clients (CA cert mismatch)
- Rust client → Go/Python/C# servers (CA cert mismatch)
- CA:TRUE mode (tonic connector limitation)

**Test Results**:
- **P-256/P-384**: 70% passing (Rust-only and Rust-Ruby work)
- **P-521**: 45% passing (adds known P-521 Python/Ruby issues)
- **Overall**: 61% passing across all languages and curves

## Next Steps

1. ✅ Complete this documentation
2. ⬜ Update main README.md and CLAUDE.md
3. ⬜ Create Rust-specific test script using CA:FALSE certs
4. ⬜ Decide on long-term solution (Option 1, 2, 3, or 5)
5. ⬜ Update test matrix script to handle Rust appropriately

## References

- Rustls issue #439: "CaUsedAsEndEntity error with self-signed certificates"
- Tonic issue #2360: "Abstraction Conflict: Custom Connector Allowed, but Internally Enforced"
- RFC 5280: Internet X.509 Public Key Infrastructure Certificate
- go-plugin: HashiCorp's plugin system requiring P-521 + CA:TRUE certs

---

*Last Updated: 2025-11-07*
*Test Matrix Version: 1.0*
*Rust Implementation: 0.1.0*
