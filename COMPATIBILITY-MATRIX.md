# gRPC Cross-Language Cipher Compatibility Matrix

**Generated:** December 2025

## Test Environment

| Language | Version | gRPC Library |
|----------|---------|--------------|
| **Go** | 1.24.7 | google.golang.org/grpc v1.69.2 |
| **Node.js** | v22.21.1 | @grpc/grpc-js ^1.10.0 |
| **Ruby** | 3.3.6 | grpc 1.76.0 |
| **Python** | 3.11.14 | grpcio 1.76.0 |
| **Java** | OpenJDK 21.0.8 | grpc-netty-shaded 1.60.0 |
| **Swift** | 5.10.1 | grpc-swift 1.21.0 |
| **C#** | .NET 9.0 | Grpc.Net.Client 2.67.0 |

---

## Algorithm: ec-secp256r1 (P-256)

| Server ↓ \ Client → | Go | Node.js | Ruby | Python | Java | Swift | C# |
|---------------------|:--:|:-------:|:----:|:------:|:----:|:-----:|:--:|
| **Go**              | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Node.js**         | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Ruby**            | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Python**          | ⚠️ | ⚠️      | ⚠️   | ⚠️     | ⚠️   | ⚠️    | ✅ |
| **Java**            | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Swift**           | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **C#**              | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |

---

## Algorithm: ec-secp384r1 (P-384) - RECOMMENDED

| Server ↓ \ Client → | Go | Node.js | Ruby | Python | Java | Swift | C# |
|---------------------|:--:|:-------:|:----:|:------:|:----:|:-----:|:--:|
| **Go**              | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Node.js**         | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Ruby**            | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Python**          | ⚠️ | ⚠️      | ⚠️   | ⚠️     | ⚠️   | ⚠️    | ✅ |
| **Java**            | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Swift**           | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **C#**              | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |

---

## Algorithm: ec-secp521r1 (P-521) - PROBLEMATIC

| Server ↓ \ Client → | Go | Node.js | Ruby | Python | Java | Swift | C# |
|---------------------|:--:|:-------:|:----:|:------:|:----:|:-----:|:--:|
| **Go**              | ✅ | ❌      | ❌   | ❌     | ✅   | ❌    | ✅ |
| **Node.js**         | ❌ | ❌      | ❌   | ❌     | ❌   | ❌    | ✅ |
| **Ruby**            | ❌ | ❌      | ❌   | ❌     | ❌   | ❌    | ✅ |
| **Python**          | ❌ | ❌      | ❌   | ❌     | ❌   | ❌    | ✅ |
| **Java**            | ✅ | ❌      | ❌   | ❌     | ✅   | ❌    | ✅ |
| **Swift**           | ❌ | ❌      | ❌   | ❌     | ❌   | ❌    | ✅ |
| **C#**              | ✅ | ❌      | ❌   | ❌     | ✅   | ❌    | ✅ |

---

## Algorithm: rsa-2048

| Server ↓ \ Client → | Go | Node.js | Ruby | Python | Java | Swift | C# |
|---------------------|:--:|:-------:|:----:|:------:|:----:|:-----:|:--:|
| **Go**              | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Node.js**         | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Ruby**            | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Python**          | ✅ | ✅      | ❌   | ⚠️     | ✅   | ✅    | ✅ |
| **Java**            | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **Swift**           | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |
| **C#**              | ✅ | ✅      | ✅   | ⚠️     | ✅   | ✅    | ✅ |

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Verified working |
| ❌ | Known failure |
| ⚠️ | Environment-dependent (works in some environments, fails in others) |
| - | Not tested |

---

## TLS 1.3 Cipher Suite Negotiation

Different server implementations negotiate different TLS 1.3 cipher suites:

| Server | Default TLS 1.3 Cipher |
|--------|------------------------|
| Go | TLS_AES_128_GCM_SHA256 |
| Python | TLS_AES_256_GCM_SHA384 |
| Ruby | TLS_CHACHA20_POLY1305_SHA256 |
| Node.js | TLS_AES_256_GCM_SHA384 |
| Java | TLS_AES_256_GCM_SHA384 |

---

## Key Findings

### Recommended Configuration
- **Use ec-secp384r1 (P-384)** for maximum cross-language compatibility
- Set TLS minimum version to **TLS 1.2** (not TLS 1.3) for C# compatibility
- Use **self-signed certificates** with proper SAN extensions

### Known Issues

#### 1. secp521r1 (P-521) Widespread Incompatibility
- **Affected:** Python, Ruby, Node.js (via grpc-js), Swift
- **Cause:** Many gRPC implementations use BoringSSL which has limited P-521 support
- **Solution:** Avoid P-521; use P-384 instead

#### 2. Python Cryptography Library Conflicts
- **Symptom:** `pyo3_runtime.PanicException: Python API call failed`
- **Cause:** System cryptography package conflicts with pip-installed version
- **Solution:** Use virtual environment or match system package version

#### 3. Go Client TLS 1.3 MinVersion
- **Symptom:** C# clients fail to connect to Go server
- **Cause:** Setting `MinVersion: tls.VersionTLS13` in Go
- **Solution:** Use `MinVersion: tls.VersionTLS12`

#### 4. Certificate Verification Failures
- **Symptom:** `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`
- **Cause:** Self-signed certificates without proper trust chain
- **Solution:** Ensure client trusts server's CA certificate

---

## Implementation Status

| Language | Server | Client | Status |
|----------|:------:|:------:|--------|
| Go | ✅ | ✅ | Production ready |
| Node.js | ✅ | ✅ | Production ready |
| Ruby | ✅ | ✅ | Production ready |
| Python | ✅ | ✅ | Environment-dependent |
| Java | ✅ | ✅ | Requires network for build |
| Swift | ✅ | ✅ | Requires network for build |
| C# | ✅ | ✅ | Production ready |

---

## Quick Start Commands

### Go
```bash
source env.sh
./go/bin/go-kv-server  # Terminal 1
./go/bin/go-kv-client  # Terminal 2
```

### Node.js
```bash
source env.sh
node nodejs/kv-server.js  # Terminal 1
node nodejs/kv-client.js  # Terminal 2
```

### Ruby
```bash
source env.sh
ruby ruby/rb-kv-server.rb  # Terminal 1
ruby ruby/rb-kv-client.rb  # Terminal 2
```

### Java (requires gradle build first)
```bash
cd java && gradle build
source env.sh
gradle runServer  # Terminal 1
gradle runClient  # Terminal 2
```

### Swift (requires swift build first)
```bash
cd swift && swift build
source env.sh
.build/debug/kv-server  # Terminal 1
.build/debug/kv-client  # Terminal 2
```

---

## Cross-Language Testing

Start any server, then connect with any client:

```bash
# Example: Go server with Node.js client
source env.sh
./go/bin/go-kv-server &
node nodejs/kv-client.js

# Example: Node.js server with Ruby client
node nodejs/kv-server.js &
ruby ruby/rb-kv-client.rb
```

---

## Certificate Generation

Generate new certificates for any algorithm:

```bash
./tools/gen-certs.sh ec-secp384r1  # Recommended
./tools/gen-certs.sh ec-secp256r1
./tools/gen-certs.sh rsa-2048
# Avoid: ./tools/gen-certs.sh ec-secp521r1
```
