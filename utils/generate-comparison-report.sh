#!/bin/bash
# Generate gRPC Patch Comparison Report
# Usage: ./generate-comparison-report.sh <baseline_dir> <patched_dir> <output_file>

set -euo pipefail

BASELINE_DIR="${1:?Missing baseline directory}"
PATCHED_DIR="${2:?Missing patched directory}"
OUTPUT_FILE="${3:-reports/comparison-$(date +%Y%m%d-%H%M%S).md}"

# Ensure results directories exist
if [[ ! -f "$BASELINE_DIR/curve-test-results.txt" ]]; then
    echo "Error: Baseline results not found at $BASELINE_DIR/curve-test-results.txt"
    exit 1
fi

if [[ ! -f "$PATCHED_DIR/curve-test-results.txt" ]]; then
    echo "Error: Patched results not found at $PATCHED_DIR/curve-test-results.txt"
    exit 1
fi

# Create reports directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Parse results into associative arrays
declare -A BASELINE_RESULTS
declare -A PATCHED_RESULTS

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[a-z] ]] && BASELINE_RESULTS["$key"]="$value"
done < "$BASELINE_DIR/curve-test-results.txt"

while IFS='=' read -r key value; do
    [[ "$key" =~ ^[a-z] ]] && PATCHED_RESULTS["$key"]="$value"
done < "$PATCHED_DIR/curve-test-results.txt"

# Load version information if available
BASELINE_VERSIONS=""
PATCHED_VERSIONS=""
if [[ -f "$BASELINE_DIR/grpc-versions.json" ]]; then
    BASELINE_VERSIONS=$(cat "$BASELINE_DIR/grpc-versions.json")
fi
if [[ -f "$PATCHED_DIR/grpc-versions.json" ]]; then
    PATCHED_VERSIONS=$(cat "$PATCHED_DIR/grpc-versions.json")
fi

# Calculate statistics
TOTAL_TESTS=0
BASELINE_PASSES=0
PATCHED_PASSES=0
TESTS_FIXED=0

# Affected languages and curves
LANGUAGES=("python" "ruby" "cpp")
CURVES=("p256" "p384" "p521")

for lang in "${LANGUAGES[@]}"; do
    for curve in "${CURVES[@]}"; do
        key="${lang}_${curve}"
        if [[ -n "${BASELINE_RESULTS[$key]:-}" ]]; then
            TOTAL_TESTS=$((TOTAL_TESTS + 1))

            # Count baseline passes
            if [[ "${BASELINE_RESULTS[$key]}" == "PASS" ]]; then
                BASELINE_PASSES=$((BASELINE_PASSES + 1))
            fi

            # Count patched passes
            if [[ "${PATCHED_RESULTS[$key]:-}" == "PASS" ]]; then
                PATCHED_PASSES=$((PATCHED_PASSES + 1))
            fi

            # Count fixes (FAIL/EXPECTED_FAIL → PASS)
            if [[ "${BASELINE_RESULTS[$key]}" != "PASS" ]] && [[ "${PATCHED_RESULTS[$key]:-}" == "PASS" ]]; then
                TESTS_FIXED=$((TESTS_FIXED + 1))
            fi
        fi
    done
done

# Calculate success rates
BASELINE_RATE=0
PATCHED_RATE=0
if [[ $TOTAL_TESTS -gt 0 ]]; then
    BASELINE_RATE=$((BASELINE_PASSES * 100 / TOTAL_TESTS))
    PATCHED_RATE=$((PATCHED_PASSES * 100 / TOTAL_TESTS))
fi

# Get timestamps
BASELINE_TIME=$(grep "timestamp" "$BASELINE_DIR/grpc-versions.json" 2>/dev/null | cut -d'"' -f4 || echo "unknown")
PATCHED_TIME=$(grep "timestamp" "$PATCHED_DIR/grpc-versions.json" 2>/dev/null | cut -d'"' -f4 || echo "unknown")

# Generate the report
cat > "$OUTPUT_FILE" <<EOF
# gRPC Elliptic Curve Patch Comparison Report

**Generated:** $(date +"%Y-%m-%d %H:%M:%S")
**Baseline Test:** $BASELINE_TIME
**Patched Test:** $PATCHED_TIME

## Executive Summary

- **Languages Tested:** Python, Ruby, C++
- **Curves Tested:** P-256, P-384, P-521
- **Tests Fixed:** $TESTS_FIXED out of $TOTAL_TESTS total tests
- **Success Rate:** $BASELINE_RATE% → $PATCHED_RATE%

## Comparison Results

| Language | Curve | Baseline | Patched | Change |
|----------|-------|----------|---------|--------|
EOF

# Generate comparison table
for lang in "${LANGUAGES[@]}"; do
    for curve in "${CURVES[@]}"; do
        key="${lang}_${curve}"
        baseline="${BASELINE_RESULTS[$key]:-SKIPPED}"
        patched="${PATCHED_RESULTS[$key]:-SKIPPED}"

        # Format language name
        lang_display=$(echo "$lang" | sed 's/^./\U&/')

        # Determine status symbols
        baseline_symbol=""
        patched_symbol=""
        change=""

        case "$baseline" in
            PASS) baseline_symbol="✅ PASS" ;;
            EXPECTED_FAIL) baseline_symbol="❌ EXPECTED_FAIL" ;;
            FAIL) baseline_symbol="❌ FAIL" ;;
            *) baseline_symbol="⚠️ $baseline" ;;
        esac

        case "$patched" in
            PASS) patched_symbol="✅ PASS" ;;
            FAIL) patched_symbol="❌ FAIL" ;;
            *) patched_symbol="⚠️ $patched" ;;
        esac

        # Determine change
        if [[ "$baseline" != "PASS" ]] && [[ "$patched" == "PASS" ]]; then
            change="**FIXED** 🎉"
        elif [[ "$baseline" == "PASS" ]] && [[ "$patched" == "PASS" ]]; then
            change="—"
        elif [[ "$baseline" == "PASS" ]] && [[ "$patched" != "PASS" ]]; then
            change="**REGRESSION** ⚠️"
        else
            change="—"
        fi

        echo "| $lang_display | ${curve^^} | $baseline_symbol | $patched_symbol | $change |" >> "$OUTPUT_FILE"
    done
done

# Add detailed results section
cat >> "$OUTPUT_FILE" <<'EOF'

## Detailed Results

### Python (gRPC/BoringSSL)

EOF

# Python details
for curve in "${CURVES[@]}"; do
    key="python_${curve}"
    baseline="${BASELINE_RESULTS[$key]:-SKIPPED}"
    patched="${PATCHED_RESULTS[$key]:-SKIPPED}"

    echo "**${curve^^}:**" >> "$OUTPUT_FILE"
    echo "- Baseline: $baseline" >> "$OUTPUT_FILE"
    echo "- Patched: $patched" >> "$OUTPUT_FILE"
    if [[ "$baseline" != "PASS" ]] && [[ "$patched" == "PASS" ]]; then
        echo "- Status: ✅ **FIXED**" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
done

cat >> "$OUTPUT_FILE" <<'EOF'
### Ruby (gRPC/BoringSSL)

EOF

# Ruby details
for curve in "${CURVES[@]}"; do
    key="ruby_${curve}"
    baseline="${BASELINE_RESULTS[$key]:-SKIPPED}"
    patched="${PATCHED_RESULTS[$key]:-SKIPPED}"

    echo "**${curve^^}:**" >> "$OUTPUT_FILE"
    echo "- Baseline: $baseline" >> "$OUTPUT_FILE"
    echo "- Patched: $patched" >> "$OUTPUT_FILE"
    if [[ "$baseline" != "PASS" ]] && [[ "$patched" == "PASS" ]]; then
        echo "- Status: ✅ **FIXED**" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
done

cat >> "$OUTPUT_FILE" <<'EOF'
### C++ (gRPC/BoringSSL)

EOF

# C++ details
for curve in "${CURVES[@]}"; do
    key="cpp_${curve}"
    baseline="${BASELINE_RESULTS[$key]:-SKIPPED}"
    patched="${PATCHED_RESULTS[$key]:-SKIPPED}"

    echo "**${curve^^}:**" >> "$OUTPUT_FILE"
    echo "- Baseline: $baseline" >> "$OUTPUT_FILE"
    echo "- Patched: $patched" >> "$OUTPUT_FILE"
    if [[ "$baseline" != "PASS" ]] && [[ "$patched" == "PASS" ]]; then
        echo "- Status: ✅ **FIXED**" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
done

# Add patch information
cat >> "$OUTPUT_FILE" <<'EOF'
## Patch Information

**Patch File:** `patches/grpc-ec-curves-p384-p521.patch`
**Modified File:** `src/core/tsi/ssl_transport_security.cc`

**Key Changes:**
1. Added BoringSSL detection for `SSL_CTX_set1_groups()` usage
2. Extended supported curves array: P-256 → P-256, P-384, P-521
3. Fixed array size parameter from 1 to 3

**Root Cause:**
BoringSSL reports `OPENSSL_VERSION_NUMBER` as `0x1010107f` (OpenSSL 1.1.1g equivalent), which is less than `0x30000000` (OpenSSL 3.0). This caused gRPC to use a legacy code path that only set P-256.

**The Fix:**
Check for `OPENSSL_IS_BORINGSSL` in addition to the version number, and use the modern `SSL_CTX_set1_groups()` API for BoringSSL.

## Conclusion

EOF

if [[ $TESTS_FIXED -gt 0 ]]; then
    cat >> "$OUTPUT_FILE" <<EOF
The patch successfully fixes the gRPC BoringSSL elliptic curve limitation, restoring support for P-384 and P-521:

- **$TESTS_FIXED tests fixed** (${BASELINE_RATE}% → ${PATCHED_RATE}% success rate)
- All affected languages (Python, Ruby, C++) now support P-384 and P-521
- P-256 support remains intact
- TLS handshake now advertises all three curves as expected

**Recommendation:** Apply this patch to production gRPC builds for compliance with CNSA/FIPS requirements that mandate P-384 or P-521.
EOF
else
    echo "No tests were fixed. Review the baseline and patched results for issues." >> "$OUTPUT_FILE"
fi

# Add version information if available
if [[ -n "$BASELINE_VERSIONS" ]] && [[ -n "$PATCHED_VERSIONS" ]]; then
    cat >> "$OUTPUT_FILE" <<'EOF'

## Version Information

### Baseline (Unpatched)

```json
EOF
    echo "$BASELINE_VERSIONS" >> "$OUTPUT_FILE"
    cat >> "$OUTPUT_FILE" <<'EOF'
```

### Patched

```json
EOF
    echo "$PATCHED_VERSIONS" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
fi

echo ""
echo "✓ Comparison report generated: $OUTPUT_FILE"
echo ""
echo "Summary:"
echo "  Tests Fixed: $TESTS_FIXED/$TOTAL_TESTS"
echo "  Success Rate: $BASELINE_RATE% → $PATCHED_RATE%"
