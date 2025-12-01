# gRPC Cross-Language Cipher Compatibility Matrix

**Generated:** December 2025

## Test Environment

| Language | Version | gRPC Library | TLS Backend |
|----------|---------|--------------|-------------|
| **Go** | 1.24.7 | google.golang.org/grpc v1.69.2 | Go crypto/tls |
| **Node.js** | v22.21.1 | @grpc/grpc-js ^1.10.0 | BoringSSL |
| **Ruby** | 3.3.6 | grpc 1.76.0 | BoringSSL |
| **Python** | 3.11.14 | grpcio 1.76.0 | BoringSSL |
| **Java** | OpenJDK 21.0.8 | grpc-netty-shaded 1.60.0 | Netty/OpenSSL |
| **Kotlin** | 1.9.22 | grpc-kotlin 1.4.1 | Netty/OpenSSL |
| **Swift** | 5.10.1 | grpc-swift 1.21.0 | SwiftNIO SSL |
| **Rust** | 1.75+ | tonic 0.11 | rustls |
| **C++** | C++17 | grpc 1.60+ | BoringSSL |
| **C#** | .NET 9.0 | Grpc.Net.Client 2.67.0 | .NET SslStream |

---

## Algorithm: ec-secp256r1 (P-256)

| Server ↓ \ Client → | Go | Node | Ruby | Python | Java | Kotlin | Swift | Rust | C++ | C# |
|---------------------|:--:|:----:|:----:|:------:|:----:|:------:|:-----:|:----:|:---:|:--:|
| **Go**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Node.js**         | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Ruby**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Python**          | ⚠️ | ⚠️   | ⚠️   | ⚠️     | ⚠️   | ⚠️     | ⚠️    | ⚠️   | ⚠️  | ✅ |
| **Java**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Kotlin**          | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Swift**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Rust**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **C++**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **C#**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |

---

## Algorithm: ec-secp384r1 (P-384) - RECOMMENDED ⭐

| Server ↓ \ Client → | Go | Node | Ruby | Python | Java | Kotlin | Swift | Rust | C++ | C# |
|---------------------|:--:|:----:|:----:|:------:|:----:|:------:|:-----:|:----:|:---:|:--:|
| **Go**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Node.js**         | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Ruby**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Python**          | ⚠️ | ⚠️   | ⚠️   | ⚠️     | ⚠️   | ⚠️     | ⚠️    | ⚠️   | ⚠️  | ✅ |
| **Java**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Kotlin**          | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Swift**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Rust**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **C++**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **C#**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |

---

## Algorithm: ec-secp521r1 (P-521) - PROBLEMATIC ⚠️

| Server ↓ \ Client → | Go | Node | Ruby | Python | Java | Kotlin | Swift | Rust | C++ | C# |
|---------------------|:--:|:----:|:----:|:------:|:----:|:------:|:-----:|:----:|:---:|:--:|
| **Go**              | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ✅?  | ❌  | ✅ |
| **Node.js**         | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ |
| **Ruby**            | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ |
| **Python**          | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ |
| **Java**            | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ✅?  | ❌  | ✅ |
| **Kotlin**          | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ✅?  | ❌  | ✅ |
| **Swift**           | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ |
| **Rust**            | ✅?| ❌   | ❌   | ❌     | ✅?  | ✅?    | ❌    | ✅?  | ❌  | ✅ |
| **C++**             | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ |
| **C#**              | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ✅?  | ❌  | ✅ |

**Note:** ✅? indicates Rust may work with P-521 due to using rustls instead of BoringSSL - needs testing.

---

## Algorithm: rsa-2048

| Server ↓ \ Client → | Go | Node | Ruby | Python | Java | Kotlin | Swift | Rust | C++ | C# |
|---------------------|:--:|:----:|:----:|:------:|:----:|:------:|:-----:|:----:|:---:|:--:|
| **Go**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Node.js**         | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Ruby**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Python**          | ✅ | ✅   | ❌   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Java**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Kotlin**          | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Swift**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **Rust**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **C++**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |
| **C#**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ |

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Verified working |
| ❌ | Known failure |
| ⚠️ | Environment-dependent |
| ✅? | Expected to work (needs verification) |
| - | Not tested |

---

## TLS Backend Comparison

| TLS Backend | Languages | P-521 Support | Notes |
|-------------|-----------|:-------------:|-------|
| **Go crypto/tls** | Go | ✅ | Native Go, full curve support |
| **BoringSSL** | Node.js, Ruby, Python, C++ | ❌ | Google's OpenSSL fork, limited P-521 |
| **Netty/OpenSSL** | Java, Kotlin | ✅ | JVM with native SSL |
| **rustls** | Rust | ✅? | Pure Rust, uses ring crypto |
| **SwiftNIO SSL** | Swift | ❌ | Uses BoringSSL internally |
| **.NET SslStream** | C# | ✅ | .NET native, full support |

---

## TLS 1.3 Cipher Suite Negotiation

| Server | Default TLS 1.3 Cipher |
|--------|------------------------|
| Go | TLS_AES_128_GCM_SHA256 |
| Python | TLS_AES_256_GCM_SHA384 |
| Ruby | TLS_CHACHA20_POLY1305_SHA256 |
| Node.js | TLS_AES_256_GCM_SHA384 |
| Java/Kotlin | TLS_AES_256_GCM_SHA384 |
| Rust | TLS_AES_256_GCM_SHA384 |
| C++ | TLS_AES_128_GCM_SHA256 |

---

## Key Findings

### Recommended Configuration
- **Use ec-secp384r1 (P-384)** for maximum cross-language compatibility
- Set TLS minimum version to **TLS 1.2** (not TLS 1.3) for C# compatibility
- Use **self-signed certificates** with proper SAN extensions

### Known Issues

#### 1. secp521r1 (P-521) Widespread Incompatibility
- **Affected:** Node.js, Ruby, Python, Swift, C++ (BoringSSL-based)
- **Cause:** BoringSSL has limited/no P-521 support
- **Solution:** Avoid P-521; use P-384 instead
- **Exception:** Rust (rustls) and Go may work with P-521

#### 2. Python Cryptography Library Conflicts
- **Symptom:** `pyo3_runtime.PanicException: Python API call failed`
- **Cause:** System cryptography package conflicts
- **Solution:** Use virtual environment

#### 3. Go Client TLS 1.3 MinVersion
- **Symptom:** C# clients fail to connect
- **Solution:** Use `MinVersion: tls.VersionTLS12`

---

## Implementation Status

| Language | Server | Client | Build System | Status |
|----------|:------:|:------:|--------------|--------|
| Go | ✅ | ✅ | go build | Production ready |
| Node.js | ✅ | ✅ | npm | Production ready |
| Ruby | ✅ | ✅ | bundler | Production ready |
| Python | ✅ | ✅ | pip | Environment-dependent |
| Java | ✅ | ✅ | Gradle | Requires network |
| Kotlin | ✅ | ✅ | Gradle | Requires network |
| Swift | ✅ | ✅ | Swift PM | Requires network |
| Rust | ✅ | ✅ | Cargo | Requires network |
| C++ | ✅ | ✅ | CMake | Requires gRPC installed |
| C# | ✅ | ✅ | dotnet | Production ready |

---

## Quick Start Commands

### Go
```bash
source env.sh && ./go/bin/go-kv-server  # Server
source env.sh && ./go/bin/go-kv-client  # Client
```

### Node.js
```bash
cd nodejs && npm install
source env.sh && node kv-server.js  # Server
source env.sh && node kv-client.js  # Client
```

### Ruby
```bash
source env.sh && ruby ruby/rb-kv-server.rb  # Server
source env.sh && ruby ruby/rb-kv-client.rb  # Client
```

### Java
```bash
cd java && gradle build
source env.sh && gradle runServer  # Server
source env.sh && gradle runClient  # Client
```

### Kotlin
```bash
cd kotlin && gradle build
source env.sh && gradle runServer  # Server
source env.sh && gradle runClient  # Client
```

### Rust
```bash
cd rust && cargo build --release
source env.sh && ./target/release/kv-server  # Server
source env.sh && ./target/release/kv-client  # Client
```

### C++
```bash
cd cpp && mkdir build && cd build && cmake .. && make
source env.sh && ./kv-server  # Server
source env.sh && ./kv-client  # Client
```

### Swift
```bash
cd swift && swift build
source env.sh && .build/debug/kv-server  # Server
source env.sh && .build/debug/kv-client  # Client
```

---

## Project Structure

```
grpc-kv-examples/
├── proto/kv.proto          # Shared protobuf definition
├── certs/                  # TLS certificates
├── go/                     # Go implementation
├── nodejs/                 # Node.js implementation
├── ruby/                   # Ruby implementation
├── python/                 # Python implementation
├── java/                   # Java implementation
├── kotlin/                 # Kotlin implementation
├── swift/                  # Swift implementation
├── rust/                   # Rust implementation
├── cpp/                    # C++ implementation
├── csharp/                 # C# implementation
└── env.sh                  # Environment setup
```
