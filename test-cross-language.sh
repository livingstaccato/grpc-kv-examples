#!/bin/bash
#
# Test script for cross-language gRPC compatibility with different elliptic curves
# Tests all client/server combinations with specified curve
#

set -e

# Parse arguments
CURVE=${1:-ec-secp384r1}
TEST_TIMEOUT=10

echo "=================================="
echo "Cross-Language gRPC Compatibility Test"
echo "=================================="
echo "Curve: $CURVE"
echo "Timeout: ${TEST_TIMEOUT}s"
echo "=================================="
echo ""

# Setup environment
export PLUGIN_CLIENT_ALGO="$CURVE"
export PLUGIN_SERVER_ALGO="$CURVE"
source ./env.sh

# Test combinations (server, client, description)
declare -a tests=(
    "go:go:Go Server + Go Client"
    "go:python:Go Server + Python Client"
    "go:ruby:Go Server + Ruby Client"
    "python:go:Python Server + Go Client"
    "python:python:Python Server + Python Client"
    "ruby:go:Ruby Server + Go Client"
    "ruby:ruby:Ruby Server + Ruby Client"
)

# Function to start server
start_server() {
    local lang=$1
    case $lang in
        go)
            ./go/bin/go-kv-server > /tmp/grpc-test-server.log 2>&1 &
            ;;
        python)
            uv run python ./python/example-py-server.py > /tmp/grpc-test-server.log 2>&1 &
            ;;
        ruby)
            ./ruby/rb-kv-server.rb > /tmp/grpc-test-server.log 2>&1 &
            ;;
    esac
    SERVER_PID=$!
    echo "Started $lang server (PID: $SERVER_PID)"
    sleep 3  # Give server time to start
}

# Function to stop server
stop_server() {
    if [ -n "$SERVER_PID" ]; then
        echo "Stopping server (PID: $SERVER_PID)"
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        SERVER_PID=""
    fi
}

# Function to run client
run_client() {
    local lang=$1
    case $lang in
        go)
            timeout $TEST_TIMEOUT ./go/bin/go-kv-client
            ;;
        python)
            timeout $TEST_TIMEOUT uv run python ./python/example-py-client.py
            ;;
        ruby)
            timeout $TEST_TIMEOUT ./ruby/rb-kv-client.rb
            ;;
    esac
}

# Run tests
PASSED=0
FAILED=0

for test in "${tests[@]}"; do
    IFS=':' read -r server client desc <<< "$test"

    echo ""
    echo "-----------------------------------"
    echo "Test: $desc"
    echo "-----------------------------------"

    # Start server
    start_server $server

    # Run client
    if run_client $client > /tmp/grpc-test-client.log 2>&1; then
        echo "✅ PASSED: $desc"
        ((PASSED++))
    else
        echo "❌ FAILED: $desc"
        echo "Server log:"
        tail -20 /tmp/grpc-test-server.log
        echo "Client log:"
        tail -20 /tmp/grpc-test-client.log
        ((FAILED++))
    fi

    # Stop server
    stop_server

    # Clean up any lingering processes
    pkill -f "go-kv-server|example-py-server|rb-kv-server" 2>/dev/null || true
    sleep 1
done

echo ""
echo "=================================="
echo "Test Results"
echo "=================================="
echo "Curve: $CURVE"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Total:  $((PASSED + FAILED))"
echo "=================================="

if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi
