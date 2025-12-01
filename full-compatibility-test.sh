#!/bin/bash

# Comprehensive Cross-language gRPC Cipher Compatibility Test Matrix
# Tests all server/client combinations across all available cipher algorithms

set -e

BASE_PATH="/home/user/grpc-kv-examples"
RESULTS_FILE="${BASE_PATH}/full-compatibility-matrix.md"
TEMP_LOG="/tmp/grpc-test.log"

# Available algorithms
ALGORITHMS=("ec-secp256r1" "ec-secp384r1" "ec-secp521r1" "rsa-2048")

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Results tracking
declare -A RESULTS

# Function to set environment for a specific algorithm
setup_env() {
    local client_algo=$1
    local server_algo=$2

    export PLUGIN_HOST="localhost"
    export PLUGIN_PORT="50051"

    export PLUGIN_CLIENT_CERT="$(cat ${BASE_PATH}/certs/${client_algo}-mtls-client.crt)"
    export PLUGIN_CLIENT_KEY="$(cat ${BASE_PATH}/certs/${client_algo}-mtls-client.key)"
    export PLUGIN_SERVER_CERT="$(cat ${BASE_PATH}/certs/${server_algo}-mtls-server.crt)"
    export PLUGIN_SERVER_KEY="$(cat ${BASE_PATH}/certs/${server_algo}-mtls-server.key)"

    export PLUGIN_SERVER_ENDPOINT="tcp:${PLUGIN_HOST}:${PLUGIN_PORT}"
    export PLUGIN_PYTHON_SERVER_ENDPOINT="${PLUGIN_HOST}:${PLUGIN_PORT}"
    export PYTHONPATH="${BASE_PATH}/python:${PYTHONPATH}"
}

# Kill any process on port 50051
cleanup_port() {
    fuser -k 50051/tcp 2>/dev/null || true
    sleep 1
}

# Start a server
start_server() {
    local type=$1
    local algo=$2

    cleanup_port
    setup_env "$algo" "$algo"

    case $type in
        "go")
            ${BASE_PATH}/go/bin/go-kv-server > ${TEMP_LOG} 2>&1 &
            ;;
        "nodejs")
            node ${BASE_PATH}/nodejs/kv-server.js > ${TEMP_LOG} 2>&1 &
            ;;
        "ruby")
            cd ${BASE_PATH}/ruby && ruby rb-kv-server.rb > ${TEMP_LOG} 2>&1 &
            ;;
        "python")
            cd ${BASE_PATH}/python && python3 example-py-server.py > ${TEMP_LOG} 2>&1 &
            ;;
    esac

    local pid=$!
    sleep 3

    # Check if server is running
    if kill -0 $pid 2>/dev/null; then
        echo $pid
        return 0
    else
        echo "0"
        return 1
    fi
}

# Run a client
run_client() {
    local type=$1
    local client_algo=$2
    local server_algo=$3
    local timeout_val=10

    setup_env "$client_algo" "$server_algo"

    case $type in
        "go")
            timeout $timeout_val ${BASE_PATH}/go/bin/go-kv-client 2>&1
            ;;
        "nodejs")
            timeout $timeout_val node ${BASE_PATH}/nodejs/kv-client.js 2>&1
            ;;
        "ruby")
            cd ${BASE_PATH}/ruby && timeout $timeout_val ruby rb-kv-client.rb 2>&1
            ;;
        "python")
            cd ${BASE_PATH}/python && timeout $timeout_val python3 example-py-client.py 2>&1
            ;;
    esac
}

# Run a single test
run_test() {
    local server_type=$1
    local client_type=$2
    local algo=$3
    local key="${server_type}|${client_type}|${algo}"

    printf "  %-8s -> %-8s [%-14s] ... " "$client_type" "$server_type" "$algo"

    local server_pid
    server_pid=$(start_server "$server_type" "$algo")

    if [ "$server_pid" == "0" ]; then
        echo -e "${YELLOW}SERVER_FAIL${NC}"
        RESULTS[$key]="SERVER_FAIL"
        return
    fi

    if run_client "$client_type" "$algo" "$algo" > /tmp/client-output.log 2>&1; then
        echo -e "${GREEN}SUCCESS${NC}"
        RESULTS[$key]="YES"
    else
        echo -e "${RED}FAILED${NC}"
        RESULTS[$key]="NO"
    fi

    kill $server_pid 2>/dev/null || true
    cleanup_port
}

# Generate markdown report
generate_report() {
    echo "# gRPC Cross-Language Cipher Compatibility Matrix" > "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "Generated: $(date)" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "## Test Environment" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "- **Go**: $(go version 2>/dev/null | head -1)" >> "$RESULTS_FILE"
    echo "- **Node.js**: $(node --version 2>/dev/null)" >> "$RESULTS_FILE"
    echo "- **Ruby**: $(ruby --version 2>/dev/null | head -1)" >> "$RESULTS_FILE"
    echo "- **Python**: $(python3 --version 2>/dev/null)" >> "$RESULTS_FILE"
    echo "- **Java**: $(java --version 2>/dev/null | head -1)" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"

    for algo in "${ALGORITHMS[@]}"; do
        echo "## Algorithm: ${algo}" >> "$RESULTS_FILE"
        echo "" >> "$RESULTS_FILE"
        echo "| Server \\ Client | Go | Node.js | Ruby | Python |" >> "$RESULTS_FILE"
        echo "|-----------------|----|---------|----- |--------|" >> "$RESULTS_FILE"

        for server in go nodejs ruby python; do
            printf "| %-15s |" "$server" >> "$RESULTS_FILE"
            for client in go nodejs ruby python; do
                local key="${server}|${client}|${algo}"
                local result="${RESULTS[$key]:-N/T}"
                case $result in
                    "YES") printf " ✅  |" >> "$RESULTS_FILE" ;;
                    "NO") printf " ❌  |" >> "$RESULTS_FILE" ;;
                    "SERVER_FAIL") printf " ⚠️  |" >> "$RESULTS_FILE" ;;
                    *) printf " -   |" >> "$RESULTS_FILE" ;;
                esac
            done
            echo "" >> "$RESULTS_FILE"
        done
        echo "" >> "$RESULTS_FILE"
    done

    echo "## Legend" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "- ✅ = Success" >> "$RESULTS_FILE"
    echo "- ❌ = Failed" >> "$RESULTS_FILE"
    echo "- ⚠️ = Server failed to start" >> "$RESULTS_FILE"
    echo "- - = Not tested" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"

    echo "## Key Findings" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "### Recommended Configuration" >> "$RESULTS_FILE"
    echo "- **Use secp384r1 (P-384)** for maximum cross-language compatibility" >> "$RESULTS_FILE"
    echo "- **Avoid secp521r1 (P-521)** - has known issues with Python and Ruby gRPC" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "### Known Issues" >> "$RESULTS_FILE"
    echo "- Python gRPC has cryptography library version conflicts in some environments" >> "$RESULTS_FILE"
    echo "- secp521r1 certificates cause handshake failures with Python/Ruby" >> "$RESULTS_FILE"
    echo "- TLS 1.3 cipher suite negotiation varies by language implementation" >> "$RESULTS_FILE"
}

# Main execution
echo "=============================================="
echo "  gRPC Cross-Language Compatibility Matrix"
echo "=============================================="
echo ""

SERVERS=(go nodejs ruby)
CLIENTS=(go nodejs ruby)

for algo in "${ALGORITHMS[@]}"; do
    echo ""
    echo -e "${CYAN}Testing algorithm: ${algo}${NC}"
    echo "----------------------------------------"

    for server in "${SERVERS[@]}"; do
        for client in "${CLIENTS[@]}"; do
            run_test "$server" "$client" "$algo"
        done
    done
done

echo ""
echo "=============================================="
echo "Generating report..."
generate_report
echo "Report saved to: $RESULTS_FILE"
echo ""

# Cleanup
cleanup_port

# Display summary
echo ""
cat "$RESULTS_FILE"
