#!/bin/bash

# Cross-language gRPC cipher compatibility test script

set -e

BASE_PATH="/home/user/grpc-kv-examples"
RESULTS_FILE="${BASE_PATH}/compatibility-results.txt"

# Available algorithms
ALGORITHMS=("ec-secp256r1" "ec-secp384r1" "ec-secp521r1" "rsa-2048")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Function to start a server
start_server() {
    local type=$1
    local algo=$2
    local pid_file="/tmp/grpc-server-${type}.pid"

    # Kill any existing server on port 50051
    pkill -f "50051" 2>/dev/null || true
    sleep 1

    setup_env "$algo" "$algo"

    case $type in
        "go")
            ${BASE_PATH}/go/bin/go-kv-server > /tmp/server-${type}.log 2>&1 &
            ;;
        "python")
            cd ${BASE_PATH}/python && python3 example-py-server.py > /tmp/server-${type}.log 2>&1 &
            ;;
        "ruby")
            cd ${BASE_PATH}/ruby && ruby rb-kv-server.rb > /tmp/server-${type}.log 2>&1 &
            ;;
    esac

    echo $! > "$pid_file"
    sleep 2  # Give server time to start
}

# Function to stop server
stop_server() {
    local type=$1
    local pid_file="/tmp/grpc-server-${type}.pid"

    if [ -f "$pid_file" ]; then
        kill $(cat "$pid_file") 2>/dev/null || true
        rm "$pid_file"
    fi
    pkill -f "50051" 2>/dev/null || true
    sleep 1
}

# Function to run a client
run_client() {
    local type=$1
    local client_algo=$2
    local server_algo=$3
    local timeout=10

    setup_env "$client_algo" "$server_algo"

    case $type in
        "go")
            timeout $timeout ${BASE_PATH}/go/bin/go-kv-client 2>&1
            ;;
        "python")
            cd ${BASE_PATH}/python && timeout $timeout python3 example-py-client.py 2>&1
            ;;
        "ruby")
            cd ${BASE_PATH}/ruby && timeout $timeout ruby rb-kv-client.rb 2>&1
            ;;
    esac
}

# Run a single test
run_test() {
    local server_type=$1
    local server_algo=$2
    local client_type=$3
    local client_algo=$4

    echo -n "Testing: Server=$server_type($server_algo) <- Client=$client_type($client_algo) ... "

    start_server "$server_type" "$server_algo"

    if run_client "$client_type" "$client_algo" "$server_algo" > /tmp/client-output.log 2>&1; then
        echo -e "${GREEN}SUCCESS${NC}"
        echo "| $server_type | $server_algo | $client_type | $client_algo | YES |" >> "$RESULTS_FILE"
    else
        echo -e "${RED}FAILED${NC}"
        echo "| $server_type | $server_algo | $client_type | $client_algo | NO |" >> "$RESULTS_FILE"
        # Show last few lines of error log
        echo "  Error details:"
        tail -5 /tmp/client-output.log 2>/dev/null | sed 's/^/    /'
    fi

    stop_server "$server_type"
}

# Main test matrix
echo "=============================================="
echo "  gRPC Cross-Language Cipher Compatibility"
echo "=============================================="
echo ""

# Initialize results file
echo "# Compatibility Test Results - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "| Server | Server Algo | Client | Client Algo | Works |" >> "$RESULTS_FILE"
echo "| ------ | ----------- | ------ | ----------- | ----- |" >> "$RESULTS_FILE"

# Define test scenarios - focus on secp384r1 as the most compatible
SERVERS=("go" "python" "ruby")
CLIENTS=("go" "python" "ruby")
TEST_ALGO="ec-secp384r1"  # Most compatible algorithm

echo "Testing with algorithm: $TEST_ALGO"
echo ""

for server in "${SERVERS[@]}"; do
    for client in "${CLIENTS[@]}"; do
        run_test "$server" "$TEST_ALGO" "$client" "$TEST_ALGO"
    done
done

echo ""
echo "=============================================="
echo "Testing secp521r1 compatibility (known issues)"
echo "=============================================="
echo ""

TEST_ALGO="ec-secp521r1"
for server in "${SERVERS[@]}"; do
    for client in "${CLIENTS[@]}"; do
        run_test "$server" "$TEST_ALGO" "$client" "$TEST_ALGO"
    done
done

echo ""
echo "Results saved to: $RESULTS_FILE"
echo ""
cat "$RESULTS_FILE"

# Cleanup
pkill -f "50051" 2>/dev/null || true
