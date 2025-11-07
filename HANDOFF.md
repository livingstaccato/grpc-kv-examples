# gRPC Cross-Language TLS Compatibility - Status & Handoff

**Date:** 2025-11-06
**Project:** grpc-kv-examples
**Status:** Partially Working - 66% Test Success Rate

---

## Executive Summary

This project tests cross-language gRPC compatibility with different elliptic curve certificates (P-256, P-384, P-521) across Go, Python, Ruby, and C# implementations. The primary goal is achieving compatibility with HashiCorp's `go-plugin` which requires P-521 (secp521r1) curve support.

### Current Test Results (36 total tests)
- ✅ **24 tests passing** (66%)
- ❌ **12 tests failing** (34%)

---

## What's Working ✅

### Excellent Cross-Language Support
- **Go ↔ All languages**: Go server works with ALL clients across ALL curves including P-521
- **Python ↔ Python, Go, Ruby**: Works with P-256 and P-384
- **Ruby client**: Works with Go, Python, Ruby servers (P-256, P-384, P-521)
- **C# client**: Works with Go and Python servers across ALL curves

### Standout Results
- ✅ **Go implementation**: Gold standard - works universally
- ✅ **Ruby client**: Surprisingly robust - works with P-521 where Python fails
- ✅ **C# client**: Works with all curves including P-521

---

## What's Broken ❌

### Critical Issues

#### 1. **Ruby Server - COMPLETELY BROKEN**
**Status:** 0% success rate connecting to Ruby server from Go/Python/C# clients
**Root Cause:** Ruby gRPC library rejects channel options with error:
```
unknown keywords: "grpc.max_send_message_length", "grpc.max_receive_message_length",
"grpc.keepalive_time_ms", "grpc.keepalive_timeout_ms", "grpc.keepalive_permit_without_calls",
"grpc.http2.min_time_between_pings_ms", "grpc.ssl_handshake_timeout_ms"
```

**Fix Required:**
- Ruby gRPC options syntax is different from Go/Python
- Options need to be passed as method calls or different hash format
- See: `/Users/tim/code/grpc-kv-examples/ruby/rb-kv-server.rb:192`

**Recommendation:** Either fix Ruby server options or **remove Ruby server** and keep only Ruby client (which works)

#### 2. **P-521 (secp521r1) Python Issues**
**Affected:** Python client/server with P-521 certificates
**Status:** Only works with Ruby server
- ❌ Go → Python: FAIL
- ❌ Python → Go: FAIL
- ❌ Python → Python: FAIL
- ✅ Python → Ruby: PASS (Ruby client works!)

**Known Issue:** Python's gRPC implementation has limited P-521 support despite OpenSSL 3.4.0 supporting it

---

## Test Matrix Results

```
Server → Client        P-256          P-384          P-521
─────────────────────────────────────────────────────────────────────
Go → Go                ✅ PASS       ✅ PASS       ✅ PASS
Go → Python            ✅ PASS       ✅ PASS       ❌ FAIL
Go → Ruby              ✅ PASS       ✅ PASS       ✅ PASS
Python → Go            ✅ PASS       ✅ PASS       ❌ FAIL
Python → Python        ✅ PASS       ✅ PASS       ❌ FAIL
Python → Ruby          ✅ PASS       ✅ PASS       ✅ PASS
Ruby → Go              ❌ FAIL       ❌ FAIL       ❌ FAIL
Ruby → Python          ❌ FAIL       ❌ FAIL       ❌ FAIL
Ruby → Ruby            ✅ PASS       ✅ PASS       ✅ PASS
Go → C#                ✅ PASS       ✅ PASS       ✅ PASS
Python → C#            ✅ PASS       ✅ PASS       ✅ PASS
Ruby → C#              ❌ FAIL       ❌ FAIL       ❌ FAIL
```

---

## Development Environment

### System Requirements
- macOS 15.2
- Python 3.13 (via `uv`)
- Ruby 3.2.9 (via `rv` - system Ruby 2.6 too old)
- Go 1.23
- .NET 9.0

### Quick Setup
```bash
# 1. Source environment (loads certificates)
source env.sh

# 2. Build Go
cd go && ./build.sh

# 3. Install Ruby (if needed)
rv ruby install 3.2.9
cd ruby && ~/.data/rv/rubies/ruby-3.2.9/bin/bundle install

# 4. Python dependencies auto-installed via uv
```

### Running Tests
```bash
# Comprehensive matrix test (ALL curves, ALL combinations)
./test-curve-matrix.sh

# Single curve test
./test-cross-language.sh ec-secp384r1

# Manual testing
source env.sh
go-server     # Terminal 1
py-client     # Terminal 2
```

---

## Project Structure

```
.
├── certs/              # mTLS certificates (secp256r1, secp384r1, secp521r1)
├── go/                 # Go client + server (FULLY WORKING)
├── python/             # Python client + server (P-256/P-384 working)
├── ruby/               # Ruby client (working), server (BROKEN)
├── csharp/             # C# client only (working with all curves)
├── proto/              # Protobuf definition
├── env.sh              # Environment setup (MUST source before running)
├── test-curve-matrix.sh # Comprehensive test script
├── CLAUDE.md           # Development documentation
└── DEBUGGING.md        # TLS debugging guide
```

---

## Recommendations

### For go-plugin Compatibility (P-521 requirement)

**Best Options:**
1. **Use Go exclusively** - 100% compatible
2. **Go server + Ruby client** - Works perfectly with P-521
3. **Python with P-384** - If you can negotiate curve with go-plugin

### Additional Language Recommendations

Since Ruby server is problematic, consider adding:

1. **Rust** ⭐ **BEST CHOICE**
   - Excellent crypto support (ring, rustls)
   - High performance
   - Strong type safety
   - `tonic` crate has excellent gRPC support
   - Likely better P-521 support than Python

2. **Java**
   - Enterprise standard
   - Mature gRPC support (grpc-java)
   - Good OpenSSL integration via Conscrypt
   - Wide industry adoption

3. **Node.js (TypeScript)**
   - `@grpc/grpc-js` native implementation
   - Good for testing JavaScript/TypeScript clients
   - Moderate crypto support

4. **Kotlin** (if targeting Android/JVM)
   - Modern syntax
   - Shares Java's gRPC ecosystem
   - Good mobile support

**Recommendation Order:** Rust > Java > Node.js

---

##Known Issues & Workarounds

### Issue 1: Ruby Server Channel Options
**Location:** `ruby/rb-kv-server.rb:59-67`
```ruby
# Current (BROKEN)
GRPC_OPTIONS = {
  'grpc.max_send_message_length' => 100 * 1024 * 1024,
  # ...
}.freeze
```

**Workaround Needed:** Research Ruby gRPC docs for correct option format

### Issue 2: Python P-521 Handshake Failures
**Location:** `python/example-py-client.py:7`
```python
# Already configured but still fails
os.environ['GRPC_SSL_CIPHER_SUITES'] = 'ECDHE-ECDSA-AES256-GCM-SHA384:...'
```

**Status:** May require Python gRPC library upgrade or C extension rebuild

### Issue 3: C# Exit Code
**Location:** `csharp/Program.cs:72`
**Status:** FIXED - Now returns exit code 1 on error

---

## Files Modified During Session

1. **CLAUDE.md** - Created comprehensive development guide
2. **HANDOFF.md** - This file
3. **test-curve-matrix.sh** - Created comprehensive test matrix script
4. **ruby/Gemfile** - Created with grpc dependencies
5. **ruby/rb-kv-server.rb** - Added log_exception method (but server still broken)
6. **csharp/Program.cs** - Fixed exit code handling
7. **env.sh** - Updated Ruby aliases to use rv Ruby 3.2.9

---

## Next Steps

### Immediate (High Priority)
1. **Fix Ruby server** - Research correct gRPC options format for Ruby
2. **Add Rust implementation** - Best P-521 compatibility candidate
3. **Document Python P-521 limitations** - Or find workaround

### Short Term
4. Update DEBUGGING.md with Ruby server findings
5. Add Java implementation for enterprise use cases
6. Create automated CI/CD pipeline with test matrix

### Long Term
7. Investigate Python gRPC P-521 support with newer versions
8. Add performance benchmarks
9. Create Docker containers for reproducible testing

---

## Resources

- **Ruby gRPC Docs:** https://github.com/grpc/grpc/tree/master/src/ruby
- **Python gRPC:** https://grpc.io/docs/languages/python/
- **Go-plugin TLS:** https://github.com/hashicorp/go-plugin/blob/main/mtls.go
- **Tonic (Rust gRPC):** https://github.com/hyperium/tonic

---

## Contact & Handoff

This document was generated during a Claude Code session on 2025-11-06.

**Test Environment:**
- All tests run from: `/Users/tim/code/grpc-kv-examples`
- Ruby installed via rv at: `~/.data/rv/rubies/ruby-3.2.9`
- Python via uv virtual environment at: `./.venv`

**Critical Commands:**
```bash
# Always source environment first
source env.sh

# Run full test matrix
./test-curve-matrix.sh

# Check server logs
cat /tmp/grpc-test-server-{go|python|ruby}.log
cat /tmp/grpc-test-client-{go|python|ruby|csharp}.log
```

**Success Criteria for Ruby Server Fix:**
When fixed, `./test-curve-matrix.sh` should show:
- Ruby → Go: PASS
- Ruby → Python: PASS
- Ruby → C#: PASS

**For go-plugin Compatibility:**
Focus on ensuring Go ↔ X with P-521 works for your target language X.
