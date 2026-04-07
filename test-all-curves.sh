#!/bin/bash
#
# Comprehensive gRPC EC Curve Compatibility Test
#
# This script tests all language implementations against P-256, P-384, and P-521 curves.
# It starts a Go server with each curve and tests clients from each language.
#
# Usage: ./test-all-curves.sh [--verbose] [--language LANG] [--curve CURVE]
#
# Options:
#   --verbose     Show detailed output
#   --language    Test only specified language (go, python, ruby, cpp, nodejs, java, rust, dart, csharp)
#   --curve       Test only specified curve (p256, p384, p521)
#
# Requirements:
#   - All language runtimes installed (see Dockerfile)
#   - Certificates in ./certs/ directory
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
SERVER_PORT=50051
VERBOSE=false
TEST_LANGUAGE=""
TEST_CURVE=""
# Use environment variable if set, otherwise default to script directory
RESULTS_FILE="${RESULTS_FILE:-$SCRIPT_DIR/curve-test-results.txt}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --language|-l)
            TEST_LANGUAGE="$2"
            shift 2
            ;;
        --curve|-c)
            TEST_CURVE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Curve configurations
declare -A CURVES
CURVES[p256]="secp256r1"
CURVES[p384]="secp384r1"
CURVES[p521]="secp521r1"

# Language configurations
# Format: "name:dir:build_cmd:client_cmd:tls_backend:has_bug"
declare -A LANGUAGES
LANGUAGES[go]="Go:go:true:go run go-kv-client.go:crypto/tls:no"
LANGUAGES[python]="Python:python:true:python3 example-py-client.py:gRPC/BoringSSL:yes"
LANGUAGES[ruby]="Ruby:ruby:true:ruby rb-kv-client.rb:gRPC/BoringSSL:yes"
LANGUAGES[nodejs]="Node.js:nodejs:npm install:node kv-client.js:OpenSSL:no"
LANGUAGES[java]="Java:java:gradle build:gradle run --args=client:Netty/JDK:no"
LANGUAGES[rust]="Rust:rust:cargo build --release:./target/release/kv-client:rustls:no"
LANGUAGES[dart]="Dart:dart:dart pub get:dart run bin/client.dart:Native TLS:no"
LANGUAGES[csharp]="C#:csharp:dotnet build:dotnet run:SslStream:no"
LANGUAGES[cpp]="C++:cpp:rm -rf build && cmake -B build -DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH:-} && cmake --build build:./build/kv-client:gRPC/BoringSSL:yes"

# Results tracking
declare -A RESULTS

log() {
    echo -e "$1"
}

log_verbose() {
    if $VERBOSE; then
        echo -e "$1"
    fi
}

# Start Go server with specified curve
start_server() {
    local curve_name=$1
    local curve_id=${CURVES[$curve_name]}

    log_verbose "${BLUE}Starting Go server with $curve_name ($curve_id) certificates...${NC}"

    export PLUGIN_SERVER_CERT="$(cat certs/ec-${curve_id}-mtls-server.crt)"
    export PLUGIN_SERVER_KEY="$(cat certs/ec-${curve_id}-mtls-server.key)"
    export PLUGIN_CLIENT_CERT="$(cat certs/ec-${curve_id}-mtls-client.crt)"
    export PLUGIN_HOST="localhost"
    export PLUGIN_PORT="$SERVER_PORT"

    cd go
    go run go-kv-server.go &
    SERVER_PID=$!
    cd ..

    # Wait for server to start
    sleep 2

    if ! kill -0 $SERVER_PID 2>/dev/null; then
        log "${RED}ERROR: Server failed to start${NC}"
        return 1
    fi

    log_verbose "${GREEN}Server started (PID: $SERVER_PID)${NC}"
    return 0
}

stop_server() {
    if [ -n "$SERVER_PID" ] && kill -0 $SERVER_PID 2>/dev/null; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        log_verbose "${BLUE}Server stopped${NC}"
    fi
}

# Test a language client
test_client() {
    local lang_key=$1
    local curve_name=$2
    local curve_id=${CURVES[$curve_name]}

    IFS=':' read -r name dir build_cmd client_cmd tls_backend has_bug <<< "${LANGUAGES[$lang_key]}"

    log_verbose "${BLUE}Testing $name with $curve_name...${NC}"

    # Set up environment for client
    export PLUGIN_SERVER_CERT="$(cat certs/ec-${curve_id}-mtls-server.crt)"
    export PLUGIN_CLIENT_CERT="$(cat certs/ec-${curve_id}-mtls-client.crt)"
    export PLUGIN_CLIENT_KEY="$(cat certs/ec-${curve_id}-mtls-client.key)"
    export PLUGIN_HOST="localhost"
    export PLUGIN_PORT="$SERVER_PORT"

    # For Rust, use PKCS#8 key if available
    if [ "$lang_key" = "rust" ] && [ -f "certs/ec-${curve_id}-mtls-client.pkcs8.key" ]; then
        export PLUGIN_CLIENT_KEY="$(cat certs/ec-${curve_id}-mtls-client.pkcs8.key)"
    fi

    cd "$dir"

    # Build if needed
    if [ "$build_cmd" != "true" ]; then
        log_verbose "Building $name..."
        eval "$build_cmd" > /dev/null 2>&1 || {
            log_verbose "${YELLOW}Build failed for $name${NC}"
            cd ..
            RESULTS["${lang_key}_${curve_name}"]="BUILD_FAILED"
            return 1
        }
    fi

    # Run client and capture result
    local output
    local exit_code

    set +e
    output=$(timeout 30 bash -c "$client_cmd" 2>&1)
    exit_code=$?
    set -e

    cd ..

    # Analyze result
    local result
    if [ $exit_code -eq 0 ]; then
        result="PASS"
        log "${GREEN}[PASS]${NC} $name + $curve_name ($tls_backend)"
    elif [ $exit_code -eq 124 ]; then
        result="TIMEOUT"
        log "${YELLOW}[TIMEOUT]${NC} $name + $curve_name ($tls_backend)"
    else
        # Check if this is expected failure (BoringSSL bug with P-384/P-521)
        if [ "$has_bug" = "yes" ] && [ "$curve_name" != "p256" ]; then
            result="EXPECTED_FAIL"
            log "${YELLOW}[EXPECTED FAIL]${NC} $name + $curve_name ($tls_backend) - needs patched gRPC"
        else
            result="FAIL"
            log "${RED}[FAIL]${NC} $name + $curve_name ($tls_backend)"
        fi

        if $VERBOSE; then
            echo "$output" | head -20
        fi
    fi

    RESULTS["${lang_key}_${curve_name}"]="$result"
}

# Print results summary
print_summary() {
    echo ""
    echo "============================================================"
    echo "               EC CURVE COMPATIBILITY RESULTS"
    echo "============================================================"
    echo ""
    printf "%-12s | %-18s | %-8s | %-8s | %-8s\n" "Language" "TLS Backend" "P-256" "P-384" "P-521"
    printf "%-12s-+-%-18s-+-%-8s-+-%-8s-+-%-8s\n" "------------" "------------------" "--------" "--------" "--------"

    for lang_key in go python ruby nodejs java rust dart csharp cpp; do
        if [ -z "${LANGUAGES[$lang_key]}" ]; then
            continue
        fi

        IFS=':' read -r name dir build_cmd client_cmd tls_backend has_bug <<< "${LANGUAGES[$lang_key]}"

        p256_result="${RESULTS[${lang_key}_p256]:-SKIPPED}"
        p384_result="${RESULTS[${lang_key}_p384]:-SKIPPED}"
        p521_result="${RESULTS[${lang_key}_p521]:-SKIPPED}"

        # Color coding for terminal
        case $p256_result in
            PASS) p256_display="${GREEN}PASS${NC}" ;;
            FAIL) p256_display="${RED}FAIL${NC}" ;;
            EXPECTED_FAIL) p256_display="${YELLOW}BUG${NC}" ;;
            *) p256_display="$p256_result" ;;
        esac

        case $p384_result in
            PASS) p384_display="${GREEN}PASS${NC}" ;;
            FAIL) p384_display="${RED}FAIL${NC}" ;;
            EXPECTED_FAIL) p384_display="${YELLOW}BUG${NC}" ;;
            *) p384_display="$p384_result" ;;
        esac

        case $p521_result in
            PASS) p521_display="${GREEN}PASS${NC}" ;;
            FAIL) p521_display="${RED}FAIL${NC}" ;;
            EXPECTED_FAIL) p521_display="${YELLOW}BUG${NC}" ;;
            *) p521_display="$p521_result" ;;
        esac

        printf "%-12s | %-18s | " "$name" "$tls_backend"
        echo -e "${p256_display}     | ${p384_display}     | ${p521_display}"
    done

    echo ""
    echo "Legend:"
    echo "  PASS         - TLS handshake succeeded"
    echo "  BUG          - Expected failure due to gRPC BoringSSL P-256 only bug"
    echo "  FAIL         - Unexpected failure"
    echo "  SKIPPED      - Test not run"
    echo "  BUILD_FAILED - Could not build client"
    echo ""
    echo "Languages marked with BUG need the patched gRPC library."
    echo "See: patches/grpc-ec-curves-p384-p521.patch"
}

# Save results to file
save_results() {
    log "Saving results to $RESULTS_FILE (Append: ${APPEND_RESULTS:-false})..."
    # If APPEND_RESULTS is true, don't write the header and use append mode
    if [[ "${APPEND_RESULTS:-false}" == "true" ]]; then
        if [ ! -f "$RESULTS_FILE" ]; then
            log "Creating new results file for appending..."
            echo "# EC Curve Compatibility Test Results (Appended)" > "$RESULTS_FILE"
        fi
        for key in "${!RESULTS[@]}"; do
            # Check if key already exists in file to avoid duplicates (last one wins)
            if grep -q "^$key=" "$RESULTS_FILE" 2>/dev/null; then
                sed -i "s|^$key=.*|$key=${RESULTS[$key]}|" "$RESULTS_FILE"
            else
                echo "$key=${RESULTS[$key]}" >> "$RESULTS_FILE"
            fi
        done
    else
        {
            echo "# EC Curve Compatibility Test Results"
            echo "# Generated: $(date -Iseconds)"
            echo ""
            for key in "${!RESULTS[@]}"; do
                echo "$key=${RESULTS[$key]}"
            done
        } > "$RESULTS_FILE"
    fi
    if [ -f "$RESULTS_FILE" ]; then
        log "Results successfully saved to $RESULTS_FILE"
        log "File size: $(stat -c%s "$RESULTS_FILE") bytes"
    else
        log "${RED}FAILED to save results to $RESULTS_FILE${NC}"
    fi
}

# Main test loop
main() {
    log "${BLUE}============================================================${NC}"
    log "${BLUE}     gRPC EC Curve Compatibility Test Suite${NC}"
    log "${BLUE}============================================================${NC}"
    echo ""

    # Determine curves to test
    local curves_to_test
    if [ -n "$TEST_CURVE" ]; then
        curves_to_test=("$TEST_CURVE")
    else
        curves_to_test=(p256 p384 p521)
    fi

    # Determine languages to test
    local langs_to_test
    if [ -n "$TEST_LANGUAGE" ]; then
        if [[ "$TEST_LANGUAGE" == *","* ]]; then
            IFS=',' read -ra langs_to_test <<< "$TEST_LANGUAGE"
        else
            langs_to_test=("$TEST_LANGUAGE")
        fi
    else
        langs_to_test=(go python ruby nodejs java rust dart csharp cpp)
    fi

    # Run tests for each curve
    for curve in "${curves_to_test[@]}"; do
        log ""
        log "${YELLOW}=== Testing with $curve (${CURVES[$curve]}) ===${NC}"

        # Start server
        if ! start_server "$curve"; then
            log "${RED}Failed to start server for $curve${NC}"
            continue
        fi

        # Test each language
        for lang in "${langs_to_test[@]}"; do
            if [ -z "${LANGUAGES[$lang]}" ]; then
                log "${YELLOW}Unknown language: $lang${NC}"
                continue
            fi

            # Don't let a single client failure stop the whole suite
            # We want to record failures in the results file
            test_client "$lang" "$curve" || true
        done

        # Stop server
        stop_server
    done

    # Print summary
    print_summary
}

# Cleanup on exit
cleanup() {
    stop_server
    save_results
}
trap cleanup EXIT

# Run main
main
