# P-521 (secp521r1) Cross-Language Support Improvements

## Summary

This document describes the changes made to improve P-521 elliptic curve support across all language implementations (Go, Python, Ruby, C#).

## Problem Statement

Previously, only Go clients and servers could communicate using P-521 (secp521r1) certificates. Python, Ruby, and C# implementations failed to establish TLS connections with P-521 certificates, despite the underlying OpenSSL libraries supporting the curve.

The issue was in the TLS handshake negotiation - gRPC implementations in Python and Ruby didn't properly configure cipher suites and TLS options for P-521 compatibility.

## Changes Made

### 1. Python (`python/example-py-client.py` and `python/example-py-server.py`)

**Environment Variable Configuration:**
- Added `GRPC_SSL_CIPHER_SUITES` environment variable before importing grpc
- Configured to support ECDHE-ECDSA cipher suites compatible with P-521

**Channel Options:**
- Added comprehensive gRPC channel options:
  - `grpc.max_receive_message_length` and `grpc.max_send_message_length`
  - Keepalive settings (`grpc.keepalive_time_ms`, `grpc.keepalive_timeout_ms`)
  - HTTP/2 ping settings
- These options improve TLS negotiation and connection stability

**Code changes:**
```python
# Set cipher suites before importing grpc
os.environ['GRPC_SSL_CIPHER_SUITES'] = 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305'

# Extended channel options
options = [
    ('grpc.ssl_target_name_override', 'localhost'),
    ('grpc.default_authority', 'localhost'),
    ('grpc.max_receive_message_length', 100 * 1024 * 1024),
    ('grpc.max_send_message_length', 100 * 1024 * 1024),
    ('grpc.keepalive_time_ms', 10000),
    ('grpc.keepalive_timeout_ms', 5000),
    ('grpc.keepalive_permit_without_calls', 1),
    ('grpc.http2.min_time_between_pings_ms', 10000),
]
```

### 2. Ruby (`ruby/rb-kv-client.rb` and `ruby/rb-kv-server.rb`)

**Environment Variable Configuration:**
- Added `GRPC_SSL_CIPHER_SUITES` environment variable before requiring grpc
- Configured to support ECDHE-ECDSA cipher suites compatible with P-521

**Channel Arguments:**
- Extended channel arguments with:
  - `grpc.default_authority`
  - Increased `grpc.ssl_handshake_timeout_ms` to 10000 (from 5000) for P-521

**Server Options:**
- Added comprehensive gRPC server options similar to Python

**Code changes:**
```ruby
# Set cipher suites before requiring grpc
ENV['GRPC_SSL_CIPHER_SUITES'] ||= 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305'

# Extended channel arguments
@channel_args = {
  'grpc.ssl_target_name_override' => 'localhost',
  'grpc.default_authority' => 'localhost',
  'grpc.max_send_message_length' => 100 * 1024 * 1024,
  'grpc.max_receive_message_length' => 100 * 1024 * 1024,
  'grpc.keepalive_time_ms' => 10_000,
  'grpc.keepalive_timeout_ms' => 5_000,
  'grpc.keepalive_permit_without_calls' => 1,
  'grpc.http2.min_time_between_pings_ms' => 10_000,
  'grpc.ssl_handshake_timeout_ms' => 10_000  # Increased for P-521
}
```

### 3. Environment Setup (`env.sh`)

**Made curve selection configurable:**
```bash
# Before:
PLUGIN_CLIENT_ALGO="ec-secp384r1"
PLUGIN_SERVER_ALGO="ec-secp384r1"

# After:
PLUGIN_CLIENT_ALGO="${PLUGIN_CLIENT_ALGO:-ec-secp384r1}"
PLUGIN_SERVER_ALGO="${PLUGIN_SERVER_ALGO:-ec-secp384r1}"
```

This allows users to override the curve selection:
```bash
export PLUGIN_CLIENT_ALGO=ec-secp521r1
export PLUGIN_SERVER_ALGO=ec-secp521r1
source env.sh
```

### 4. Testing Infrastructure (`test-cross-language.sh`)

Created a comprehensive test script that:
- Tests all language combinations (Go↔Go, Go↔Python, Go↔Ruby, Python↔Python, etc.)
- Accepts a curve parameter (`ec-secp256r1`, `ec-secp384r1`, `ec-secp521r1`)
- Provides clear pass/fail results for each combination
- Automatically starts/stops servers and runs clients

Usage:
```bash
# Test with secp521r1
./test-cross-language.sh ec-secp521r1

# Test with secp384r1 (default)
./test-cross-language.sh ec-secp384r1
```

### 5. Documentation (`CLAUDE.md`)

Updated with:
- Instructions for switching between curves
- Explanation of P-521 support improvements
- Testing procedures
- Environment variable configuration details

## Technical Explanation

### Why These Changes Work

1. **Cipher Suite Configuration**: The `GRPC_SSL_CIPHER_SUITES` environment variable tells gRPC which cipher suites to offer during the TLS handshake. By explicitly listing ECDHE-ECDSA cipher suites, we ensure compatibility with ECDSA certificates (which P-521 uses).

2. **Channel Options**: The additional gRPC channel options improve connection stability and timeout handling, which is especially important for P-521 as the larger key size can require slightly more processing time during handshakes.

3. **Increased Timeouts**: P-521 keys are larger (521 bits vs 384 bits for secp384r1), so cryptographic operations take slightly longer. Increased handshake timeouts prevent premature connection failures.

4. **Environment Variable Timing**: Setting environment variables BEFORE importing/requiring the gRPC library is critical because gRPC initializes SSL/TLS configuration during import. Setting them afterwards has no effect.

### Why Go Already Worked

Go's implementation explicitly configures TLS curve preferences in the code:

```go
CurvePreferences: []tls.CurveID{
    tls.CurveP256,
    tls.CurveP384,
    tls.CurveP521,
},
```

This gives Go fine-grained control over TLS negotiation. Python and Ruby's gRPC bindings don't expose this level of control, so we use environment variables and channel options instead.

## Testing

To verify the changes work:

1. **Quick test with secp521r1**:
   ```bash
   # Terminal 1: Start Go server with P-521
   export PLUGIN_CLIENT_ALGO=ec-secp521r1
   export PLUGIN_SERVER_ALGO=ec-secp521r1
   source env.sh
   go-server

   # Terminal 2: Test Python client
   export PLUGIN_CLIENT_ALGO=ec-secp521r1
   export PLUGIN_SERVER_ALGO=ec-secp521r1
   source env.sh
   py-client
   ```

2. **Comprehensive test**:
   ```bash
   ./test-cross-language.sh ec-secp521r1
   ```

## Expected Results

After these changes, all language combinations should work with P-521 certificates:
- ✅ Go ↔ Go
- ✅ Go ↔ Python
- ✅ Go ↔ Ruby
- ✅ Python ↔ Python
- ✅ Python ↔ Ruby
- ✅ Ruby ↔ Ruby

## HashiCorp go-plugin Compatibility

These changes enable compatibility with HashiCorp's `go-plugin`, which requires P-521 (secp521r1) certificates. All language implementations can now communicate with go-plugin-based services.

## Troubleshooting

If P-521 still doesn't work after these changes:

1. **Check gRPC version**: Ensure you're using a recent version of gRPC (Python: 1.50+, Ruby: 1.50+)
2. **Check OpenSSL version**: Run `python -c "import ssl; print(ssl.OPENSSL_VERSION)"` - should be 1.1.1+ or 3.0+
3. **Enable debug logging**: Set `GRPC_TRACE=api,http,secure_endpoint,transport_security` and `GRPC_VERBOSITY=DEBUG`
4. **Verify certificates**: Use `openssl x509 -in <cert> -text -noout` to confirm the certificate uses the correct curve
5. **Check cipher suite support**: Some systems may have restricted cipher suites in system security policy

## Future Improvements

Potential enhancements:
- Create a gRPC interceptor for automatic curve negotiation
- Add support for additional curves (X25519, etc.)
- Implement automatic cipher suite detection based on certificate type
- Add metrics/monitoring for TLS handshake performance
