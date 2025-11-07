#!/bin/bash
#
# Focused test script for Go<->Python with secp521r1
#

set -e

CURVE=${1:-ec-secp521r1}
TEST_TIMEOUT=10

echo "=================================="
echo "Go<->Python gRPC Test with P-521"
echo "=================================="
echo "Curve: $CURVE"
echo "=================================="
echo ""

# Setup environment
export PLUGIN_CLIENT_ALGO="$CURVE"
export PLUGIN_SERVER_ALGO="$CURVE"
source ./env.sh

# Test matrix
declare -a tests=(
    "go:go:Go Server → Go Client"
    "go:python:Go Server → Python Client"
    "python:go:Python Server → Go Client"
    "python:python:Python Server → Python Client"
)

start_server() {
    local lang=$1
    if [ "$lang" = "go" ]; then
        ./go/bin/go-kv-server > /tmp/test-server.log 2>&1 &
    else
        uv run python ./python/example-py-server.py > /tmp/test-server.log 2>&1 &
    fi
    SERVER_PID=$!
    echo "  Started $lang server (PID: $SERVER_PID)"
    sleep 3
}

stop_server() {
    if [ -n "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        SERVER_PID=""
    fi
}

run_client() {
    local lang=$1
    if [ "$lang" = "go" ]; then
        timeout $TEST_TIMEOUT ./go/bin/go-kv-client 2>&1
    else
        timeout $TEST_TIMEOUT uv run python ./python/example-py-client.py 2>&1
    fi
}

PASSED=0
FAILED=0

for test in "${tests[@]}"; do
    IFS=':' read -r server client desc <<< "$test"

    echo ""
    echo "Testing: $desc"
    echo "-----------------------------------"

    start_server $server

    if run_client $client > /tmp/test-client.log 2>&1; then
        echo "✅ PASSED"
        ((PASSED++))
    else
        echo "❌ FAILED"
        echo ""
        echo "Server log (last 30 lines):"
        tail -30 /tmp/test-server.log
        echo ""
        echo "Client log (last 30 lines):"
        tail -30 /tmp/test-client.log
        ((FAILED++))
    fi

    stop_server
    pkill -f "go-kv-server|example-py-server" 2>/dev/null || true
    sleep 1
done

echo ""
echo "=================================="
echo "Results Summary"
echo "=================================="
echo "Curve: $CURVE"
echo "Passed: $PASSED / $((PASSED + FAILED))"
echo "Failed: $FAILED / $((PASSED + FAILED))"
echo "=================================="

if [ $FAILED -eq 0 ]; then
    echo "✅ ALL TESTS PASSED!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi
