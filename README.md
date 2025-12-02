# gRPC Elliptic Curve Compatibility Testing

This repository demonstrates and tests a **critical bug in gRPC's BoringSSL TLS implementation** that prevents P-384 (secp384r1) and P-521 (secp521r1) elliptic curves from working, despite these curves being fully supported by BoringSSL itself.

## The Problem

gRPC uses BoringSSL for TLS in Python, Ruby, and C++ implementations. Due to a version check bug in `ssl_transport_security.cc`, gRPC only advertises **P-256 (prime256v1)** support during TLS handshakes, even though BoringSSL fully supports P-384 and P-521.

### Root Cause

The bug is in gRPC's `src/core/tsi/ssl_transport_security.cc`:

```cpp
// gRPC checks for OpenSSL 3.0+ to use SSL_CTX_set1_groups
#if OPENSSL_VERSION_NUMBER >= 0x30000000
static const int kSslEcCurveNames[] = {NID_X9_62_prime256v1};  // Only P-256!
#endif
```

BoringSSL reports `OPENSSL_VERSION_NUMBER` as `0x1010107f` (~OpenSSL 1.1.1g), which is less than `0x30000000` (OpenSSL 3.0). This causes gRPC to take a legacy code path that only sets **one curve** using `SSL_CTX_set_tmp_ecdh()`.

**However**, BoringSSL actually supports `SSL_CTX_set1_groups()` which can set multiple curves. The fix is to check for `OPENSSL_IS_BORINGSSL` in addition to the version number.

### Impact

| Language | TLS Backend | P-256 | P-384 | P-521 | Bug Affected? |
|----------|-------------|-------|-------|-------|---------------|
| Go | crypto/tls | PASS | PASS | PASS | No |
| Node.js | OpenSSL | PASS | PASS | PASS | No |
| Java/Kotlin/Scala | Netty/JDK | PASS | PASS | PASS | No |
| Rust | rustls | PASS | PASS | PASS | No |
| Dart | Native TLS | PASS | PASS | PASS | No |
| C# | SslStream | PASS | PASS | PASS | No |
| **Python** | gRPC/BoringSSL | PASS | **FAIL** | **FAIL** | **Yes** |
| **Ruby** | gRPC/BoringSSL | PASS | **FAIL** | **FAIL** | **Yes** |
| **C++** | gRPC/BoringSSL | PASS | **FAIL** | **FAIL** | **Yes** |

This is a significant issue for organizations that:
- Require P-384 or P-521 for compliance (CNSA, FIPS 140-2, etc.)
- Need to interoperate with servers/clients that mandate these curves
- Use mutual TLS (mTLS) with EC certificates larger than P-256

## Repository Contents

```
grpc-kv-examples/
├── certs/                  # Pre-generated test certificates (P-256, P-384, P-521, RSA)
├── patches/                # The gRPC patch to fix the bug
│   └── grpc-ec-curves-p384-p521.patch
├── go/                     # Go server + client (working reference)
├── python/                 # Python client (affected by bug)
├── ruby/                   # Ruby client (affected by bug)
├── cpp/                    # C++ client (affected by bug)
├── nodejs/                 # Node.js client (uses OpenSSL - not affected)
├── java/                   # Java client (uses Netty - not affected)
├── kotlin/                 # Kotlin client (uses Java gRPC)
├── scala/                  # Scala client (uses Java gRPC)
├── rust/                   # Rust client (uses rustls - not affected)
├── dart/                   # Dart client (not affected)
├── csharp/                 # C# client (not affected)
├── build-patched-grpc.sh   # Script to build patched gRPC
├── test-all-curves.sh      # Comprehensive test script
├── Dockerfile              # Multi-language test environment
└── .dockerignore           # Excludes build artifacts from Docker
```

## Quick Start

### Option 1: Docker (Recommended)

Build the test environment:

```bash
docker build -t grpc-curve-test .
docker run -it grpc-curve-test
```

Inside the container, run the test suite:

```bash
./test-all-curves.sh
```

### Option 2: Native (Requires all language runtimes)

```bash
# Generate certificates if needed
./tools/gen-certs.sh

# Build Go server
cd go && go build -o bin/go-kv-server go-kv-server.go && cd ..

# Run tests
./test-all-curves.sh
```

## Testing Unpatched vs Patched gRPC

### Step 1: Test Unpatched (Demonstrates the Bug)

```bash
# Build and run the container
docker build -t grpc-curve-test .
docker run -it grpc-curve-test

# Run the test suite - observe P-384/P-521 failures for Python/Ruby/C++
./test-all-curves.sh
```

Expected output (abbreviated):
```
=== Testing with p256 (secp256r1) ===
[PASS] Go + p256 (crypto/tls)
[PASS] Python + p256 (gRPC/BoringSSL)
[PASS] Ruby + p256 (gRPC/BoringSSL)

=== Testing with p384 (secp384r1) ===
[PASS] Go + p384 (crypto/tls)
[EXPECTED FAIL] Python + p384 (gRPC/BoringSSL) - needs patched gRPC
[EXPECTED FAIL] Ruby + p384 (gRPC/BoringSSL) - needs patched gRPC

=== Testing with p521 (secp521r1) ===
[PASS] Go + p521 (crypto/tls)
[EXPECTED FAIL] Python + p521 (gRPC/BoringSSL) - needs patched gRPC
[EXPECTED FAIL] Ruby + p521 (gRPC/BoringSSL) - needs patched gRPC
```

### Step 2: Build and Test Patched gRPC

Inside the container:

```bash
# Build patched Python gRPC (takes 20-30 minutes)
./build-patched-grpc.sh --python

# Activate the patched virtual environment
source /workspace/build/patched-grpc/venv/bin/activate

# Re-run tests - Python should now pass all curves
./test-all-curves.sh --language python
```

Expected output after patching:
```
=== Testing with p384 (secp384r1) ===
[PASS] Python + p384 (gRPC/BoringSSL)

=== Testing with p521 (secp521r1) ===
[PASS] Python + p521 (gRPC/BoringSSL)
```

## Building Patched gRPC

The `build-patched-grpc.sh` script clones gRPC source, applies the EC curve fix, and builds the patched library.

### Usage

```bash
./build-patched-grpc.sh [OPTIONS]

Options:
  --python    Build patched Python grpcio (default if no options specified)
  --cpp       Build patched C++ gRPC library
  --ruby      Build patched Ruby gRPC gem
  --all       Build all languages
  --install   Install after building (for C++/Ruby)
```

### Examples

```bash
# Build only Python (creates venv at ./build/patched-grpc/venv)
./build-patched-grpc.sh --python

# Build all languages
./build-patched-grpc.sh --all

# Build C++ and install to ./build/patched-grpc/install
./build-patched-grpc.sh --cpp --install
```

### Build Output

After building, artifacts are located at:
- **Python**: `./build/patched-grpc/venv/` (activate with `source ./build/patched-grpc/venv/bin/activate`)
- **C++**: `./build/patched-grpc/install/` (use with `CMAKE_PREFIX_PATH`)
- **Ruby**: `./build/patched-grpc/grpc/src/ruby/pkg/*.gem`

## The Patch

The patch (`patches/grpc-ec-curves-p384-p521.patch`) makes two key changes:

1. **Adds BoringSSL detection**: Uses `SSL_CTX_set1_groups()` for BoringSSL (not just OpenSSL 3.0+)
2. **Enables multiple curves**: Adds P-384 and P-521 to the supported curves array

```diff
-#if OPENSSL_VERSION_NUMBER >= 0x30000000
-static const int kSslEcCurveNames[] = {NID_X9_62_prime256v1};
+#if (OPENSSL_VERSION_NUMBER >= 0x30000000) || defined(OPENSSL_IS_BORINGSSL)
+static const int kSslEcCurveNames[] = {NID_X9_62_prime256v1, NID_secp384r1, NID_secp521r1};
```

## Test Scripts

### `test-all-curves.sh`

Comprehensive test that starts a Go server with each curve type and tests all language clients:

```bash
# Test all languages with all curves
./test-all-curves.sh

# Verbose output
./test-all-curves.sh --verbose

# Test specific language
./test-all-curves.sh --language python

# Test specific curve
./test-all-curves.sh --curve p384
```

### `test-compatibility.sh`

Cross-language server/client compatibility matrix:

```bash
./test-compatibility.sh
```

### `full-compatibility-test.sh`

Full N×N test matrix of all server/client combinations:

```bash
./full-compatibility-test.sh
```

## Certificate Generation

Test certificates are pre-generated in `certs/`. To regenerate:

```bash
./tools/gen-certs.sh
```

This creates certificates for:
- `ec-secp256r1` (P-256)
- `ec-secp384r1` (P-384)
- `ec-secp521r1` (P-521)
- `rsa-2048`

Each algorithm has both server and client mTLS certificates signed by a common CA.

## Environment Variables

The test framework uses these environment variables:

| Variable | Description |
|----------|-------------|
| `PLUGIN_HOST` | Server hostname (default: `localhost`) |
| `PLUGIN_PORT` | Server port (default: `50051`) |
| `PLUGIN_SERVER_CERT` | Server certificate (PEM content) |
| `PLUGIN_SERVER_KEY` | Server private key (PEM content) |
| `PLUGIN_CLIENT_CERT` | Client certificate (PEM content) |
| `PLUGIN_CLIENT_KEY` | Client private key (PEM content) |

## Upstream Status

This bug has been identified in gRPC. The patch in this repository demonstrates the fix. For production use, track the upstream gRPC issue or apply this patch to your gRPC build.

## Troubleshooting

### "No matching cipher" or "Handshake failed"

This is the expected error when testing P-384/P-521 with unpatched gRPC. The client only advertises P-256, but the server certificate uses P-384 or P-521.

### Build fails with "externally-managed-environment"

The Docker container uses `uv` for Python package management. If running outside Docker, install `uv`:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Rust client fails with "invalid private key"

Rust's `rustls` requires PKCS#8 format keys. The Dockerfile automatically converts EC keys:

```bash
openssl pkcs8 -topk8 -nocrypt -in client.key -out client.pkcs8.key
```

## License

MIT
