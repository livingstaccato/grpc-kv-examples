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
| **PHP** | 8.4 | grpc/grpc 1.74 | BoringSSL |
| **Dart** | 3.10.2 | grpc 4.1.0 | Dart Native TLS |
| **Objective-C** | Clang 18 | gRPC-ProtoRPC 1.62 | BoringSSL |
| **Scala** | 3.3.1 | grpc-netty 1.62.2 | Netty/OpenSSL |

---

## Algorithm: ec-secp256r1 (P-256)

| Server ↓ \ Client → | Go | Node | Ruby | Python | Java | Kotlin | Swift | Rust | C++ | C# | PHP | Dart | ObjC | Scala |
|---------------------|:--:|:----:|:----:|:------:|:----:|:------:|:-----:|:----:|:---:|:--:|:---:|:----:|:----:|:-----:|
| **Go**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Node.js**         | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Ruby**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Python**          | ⚠️ | ⚠️   | ⚠️   | ⚠️     | ⚠️   | ⚠️     | ⚠️    | ⚠️   | ⚠️  | ✅ | ⚠️  | ⚠️   | ⚠️   | ⚠️    |
| **Java**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Kotlin**          | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Swift**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Rust**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **C++**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **C#**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **PHP**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Dart**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Scala**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |

---

## Algorithm: ec-secp384r1 (P-384) - RECOMMENDED ⭐

| Server ↓ \ Client → | Go | Node | Ruby | Python | Java | Kotlin | Swift | Rust | C++ | C# | PHP | Dart | ObjC | Scala |
|---------------------|:--:|:----:|:----:|:------:|:----:|:------:|:-----:|:----:|:---:|:--:|:---:|:----:|:----:|:-----:|
| **Go**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Node.js**         | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Ruby**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Python**          | ⚠️ | ⚠️   | ⚠️   | ⚠️     | ⚠️   | ⚠️     | ⚠️    | ⚠️   | ⚠️  | ✅ | ⚠️  | ⚠️   | ⚠️   | ⚠️    |
| **Java**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Kotlin**          | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Swift**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Rust**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **C++**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **C#**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **PHP**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Dart**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Scala**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |

---

## Algorithm: ec-secp521r1 (P-521) - PROBLEMATIC ⚠️

| Server ↓ \ Client → | Go | Node | Ruby | Python | Java | Kotlin | Swift | Rust | C++ | C# | PHP | Dart | ObjC | Scala |
|---------------------|:--:|:----:|:----:|:------:|:----:|:------:|:-----:|:----:|:---:|:--:|:---:|:----:|:----:|:-----:|
| **Go**              | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ⚠️†  | ❌  | ✅ | ❌  | ❌   | ❌   | ✅    |
| **Node.js**         | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ | ❌  | ❌   | ❌   | ❌    |
| **Ruby**            | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ | ❌  | ❌   | ❌   | ❌    |
| **Python**          | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ | ❌  | ❌   | ❌   | ❌    |
| **Java**            | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ⚠️†  | ❌  | ✅ | ❌  | ❌   | ❌   | ✅    |
| **Kotlin**          | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ⚠️†  | ❌  | ✅ | ❌  | ❌   | ❌   | ✅    |
| **Swift**           | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ | ❌  | ❌   | ❌   | ❌    |
| **Rust**            | ⚠️†| ❌   | ❌   | ❌     | ⚠️†  | ⚠️†    | ❌    | ⚠️†  | ❌  | ✅ | ❌  | ❌   | ❌   | ⚠️†   |
| **C++**             | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ | ❌  | ❌   | ❌   | ❌    |
| **C#**              | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ⚠️†  | ❌  | ✅ | ❌  | ❌   | ❌   | ✅    |
| **PHP**             | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ | ❌  | ❌   | ❌   | ❌    |
| **Dart**            | ❌ | ❌   | ❌   | ❌     | ❌   | ❌     | ❌    | ❌   | ❌  | ✅ | ❌  | ❌   | ❌   | ❌    |
| **Scala**           | ✅ | ❌   | ❌   | ❌     | ✅   | ✅     | ❌    | ⚠️†  | ❌  | ✅ | ❌  | ❌   | ❌   | ✅    |

---

## Algorithm: rsa-2048

| Server ↓ \ Client → | Go | Node | Ruby | Python | Java | Kotlin | Swift | Rust | C++ | C# | PHP | Dart | ObjC | Scala |
|---------------------|:--:|:----:|:----:|:------:|:----:|:------:|:-----:|:----:|:---:|:--:|:---:|:----:|:----:|:-----:|
| **Go**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Node.js**         | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Ruby**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Python**          | ✅ | ✅   | ❌   | ⚠️     | ✅   | ✅     | ✅    | ⚠️   | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Java**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Kotlin**          | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Swift**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Rust**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ✅   | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **C++**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **C#**              | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **PHP**             | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Dart**            | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |
| **Scala**           | ✅ | ✅   | ✅   | ⚠️     | ✅   | ✅     | ✅    | ⚠️†  | ✅  | ✅ | ✅  | ✅   | ✅   | ✅    |

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Verified working |
| ❌ | Known failure |
| ⚠️ | Environment-dependent |
| ⚠️† | Rust/rustls certificate validation issue (see notes) |
| - | Not tested |

---

## TLS Backend Comparison

| TLS Backend | Languages | P-521 Support | Certificate Strictness | Notes |
|-------------|-----------|:-------------:|:----------------------:|-------|
| **Go crypto/tls** | Go | ✅ | Lenient | Native Go, full curve support |
| **BoringSSL** | Node.js, Ruby, Python, C++, PHP, Obj-C | ❌ | Lenient | Google's OpenSSL fork, limited P-521 |
| **Netty/OpenSSL** | Java, Kotlin, Scala | ✅ | Lenient | JVM with native SSL |
| **rustls** | Rust | ✅ | **Strict** | Pure Rust, RFC 5280 compliant |
| **SwiftNIO SSL** | Swift | ❌ | Lenient | Uses BoringSSL internally |
| **.NET SslStream** | C# | ✅ | Lenient | .NET native, full support |
| **Dart Native TLS** | Dart | ❌ | Lenient | Dart's native TLS implementation |

---

## TLS 1.3 Cipher Suite Negotiation

| Server | Default TLS 1.3 Cipher |
|--------|------------------------|
| Go | TLS_AES_128_GCM_SHA256 |
| Python | TLS_AES_256_GCM_SHA384 |
| Ruby | TLS_CHACHA20_POLY1305_SHA256 |
| Node.js | TLS_AES_256_GCM_SHA384 |
| Java/Kotlin/Scala | TLS_AES_256_GCM_SHA384 |
| Rust | TLS_AES_256_GCM_SHA384 |
| C++ | TLS_AES_128_GCM_SHA256 |
| PHP | TLS_AES_256_GCM_SHA384 |
| Dart | TLS_AES_256_GCM_SHA384 |

---

## Key Findings

### Recommended Configuration
- **Use ec-secp384r1 (P-384)** for maximum cross-language compatibility
- Set TLS minimum version to **TLS 1.2** (not TLS 1.3) for C# compatibility
- Use **properly-issued certificates** with correct CA constraints
- For Rust compatibility, ensure end-entity certificates do NOT have CA:TRUE

### Known Issues

#### 1. secp521r1 (P-521) Widespread Incompatibility
- **Affected:** Node.js, Ruby, Python, Swift, C++, PHP, Dart, Objective-C (BoringSSL-based)
- **Cause:** BoringSSL has limited/no P-521 support
- **Solution:** Avoid P-521; use P-384 instead
- **Exception:** Rust (rustls), Go, and JVM languages may work with P-521

#### 2. Rust/rustls Certificate Validation Strictness (†)
- **Symptom:** `InvalidCertificate(Other(OtherError(CaUsedAsEndEntity)))`
- **Cause:** rustls correctly enforces RFC 5280 - certificates with CA:TRUE cannot be used as end-entity certificates
- **Affected:** Test certificates in this project have CA:TRUE set on server/client certs
- **Solution:** Use properly-structured certificates where only the actual CA has CA:TRUE
- **Note:** This is technically correct behavior; other TLS implementations are more lenient

#### 3. Python Cryptography Library Conflicts
- **Symptom:** `pyo3_runtime.PanicException: Python API call failed`
- **Cause:** System cryptography package conflicts
- **Solution:** Use virtual environment

#### 4. Go Client TLS 1.3 MinVersion
- **Symptom:** C# clients fail to connect
- **Solution:** Use `MinVersion: tls.VersionTLS12`

#### 5. PHP gRPC Extension Requirement
- **Note:** PHP gRPC requires the native grpc extension for full functionality
- **Client:** Works with grpc/grpc Composer package
- **Server:** Requires RoadRunner, Swoole, or similar for production use

#### 6. Objective-C Server Limitation
- **Note:** gRPC Objective-C is primarily designed for client-side usage
- **Server:** Use Swift with grpc-swift or C++ with Objective-C++ bridging

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
| Rust | ✅ | ✅ | Cargo | Cert validation strict |
| C++ | ✅ | ✅ | CMake | Requires gRPC installed |
| C# | ✅ | ✅ | dotnet | Production ready |
| PHP | ⚠️ | ✅ | Composer | Server needs RoadRunner |
| Dart | ✅ | ✅ | pub | Production ready |
| Objective-C | ⚠️ | ✅ | CocoaPods | Client-focused |
| Scala | ✅ | ✅ | sbt | Requires network |

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

### PHP
```bash
cd php && composer install
source env.sh && php kv-client.php  # Client (server requires RoadRunner)
```

### Dart
```bash
cd dart && dart pub get
source env.sh && dart run bin/server.dart  # Server
source env.sh && dart run bin/client.dart  # Client
```

### Scala
```bash
cd scala && sbt compile
source env.sh && sbt "runMain kv.KVServer"  # Server
source env.sh && sbt "runMain kv.KVClient"  # Client
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
├── php/                    # PHP implementation
├── dart/                   # Dart implementation
├── objc/                   # Objective-C implementation
├── scala/                  # Scala implementation
└── env.sh                  # Environment setup
```
