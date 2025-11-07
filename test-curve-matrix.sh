#!/bin/bash
#
# Comprehensive cross-language + cross-curve compatibility matrix test
# Tests all client/server combinations with all available elliptic curves
#

set -e

# Configuration
TEST_TIMEOUT=8
CURVES=("ec-secp256r1" "ec-secp384r1" "ec-secp521r1")
BASE_DIR=$(pwd)

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   gRPC Cross-Language + Cross-Curve Compatibility Test    ║${NC}"
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Build Go binaries first
echo -e "${BLUE}🔨 Building Go binaries...${NC}"
cd "$BASE_DIR/go"
./build.sh > /dev/null 2>&1
cd "$BASE_DIR"
echo -e "${GREEN}✅ Go build complete${NC}"
echo ""

# Check Ruby availability
if command -v rv &> /dev/null && [ -f "$BASE_DIR/ruby/Gemfile" ]; then
    echo -e "${GREEN}✅ Ruby 3.2.9 (via rv) available${NC}"
    HAS_RUBY=true
else
    echo -e "${YELLOW}⚠️  rv or Ruby not available, skipping Ruby tests${NC}"
    HAS_RUBY=false
fi
echo ""

# Verify C# is built
if ! command -v dotnet &> /dev/null; then
    echo -e "${YELLOW}⚠️  .NET not available, skipping C# tests${NC}"
    HAS_CSHARP=false
else
    echo -e "${BLUE}🔨 Building C# project...${NC}"
    cd "$BASE_DIR/csharp"
    dotnet build > /dev/null 2>&1
    cd "$BASE_DIR"
    echo -e "${GREEN}✅ C# build complete${NC}"
    HAS_CSHARP=true
fi
echo ""

# Check Rust availability
if command -v cargo &> /dev/null && [ -f "$BASE_DIR/rust/Cargo.toml" ]; then
    echo -e "${BLUE}🔨 Building Rust project...${NC}"
    cd "$BASE_DIR/rust"
    cargo build --release > /dev/null 2>&1
    cd "$BASE_DIR"
    echo -e "${GREEN}✅ Rust build complete${NC}"
    HAS_RUST=true
else
    echo -e "${YELLOW}⚠️  Rust/Cargo not available, skipping Rust tests${NC}"
    HAS_RUST=false
fi
echo ""

# Test matrix: server:client:description
# Note: C# and Rust client-only tests added at the end
declare -a test_combinations=(
    "go:go:Go → Go"
    "go:python:Go → Python"
    "go:ruby:Go → Ruby"
    "go:rust:Go → Rust"
    "python:go:Python → Go"
    "python:python:Python → Python"
    "python:ruby:Python → Ruby"
    "python:rust:Python → Rust"
    "ruby:go:Ruby → Go"
    "ruby:python:Ruby → Python"
    "ruby:ruby:Ruby → Ruby"
    "ruby:rust:Ruby → Rust"
    "rust:go:Rust → Go"
    "rust:python:Rust → Python"
    "rust:ruby:Rust → Ruby"
    "rust:rust:Rust → Rust"
)

# Filter test combinations based on what's available
filtered_combinations=()
for test in "${test_combinations[@]}"; do
    IFS=':' read -r server client desc <<< "$test"

    # Skip Ruby tests if Ruby is not available
    if [ "$HAS_RUBY" = false ] && ( [ "$server" = "ruby" ] || [ "$client" = "ruby" ] ); then
        continue
    fi

    # Skip Rust tests if Rust is not available
    if [ "$HAS_RUST" = false ] && ( [ "$server" = "rust" ] || [ "$client" = "rust" ] ); then
        continue
    fi

    filtered_combinations+=("$test")
done

# Add C# client tests if available
if [ "$HAS_CSHARP" = true ]; then
    filtered_combinations+=(
        "go:csharp:Go → C#"
        "python:csharp:Python → C#"
    )
    if [ "$HAS_RUBY" = true ]; then
        filtered_combinations+=("ruby:csharp:Ruby → C#")
    fi
    if [ "$HAS_RUST" = true ]; then
        filtered_combinations+=("rust:csharp:Rust → C#")
    fi
fi

test_combinations=("${filtered_combinations[@]}")

# Function to start server
start_server() {
    local lang=$1
    local log_file="/tmp/grpc-test-server-${lang}.log"

    case $lang in
        go)
            "$BASE_DIR/go/bin/go-kv-server" > "$log_file" 2>&1 &
            ;;
        python)
            cd "$BASE_DIR"
            uv run python ./python/example-py-server.py > "$log_file" 2>&1 &
            ;;
        ruby)
            cd "$BASE_DIR/ruby"
            ~/.data/rv/rubies/ruby-3.2.9/bin/bundle exec ~/.data/rv/rubies/ruby-3.2.9/bin/ruby ./rb-kv-server.rb > "$log_file" 2>&1 &
            cd "$BASE_DIR"
            ;;
        rust)
            "$BASE_DIR/rust/target/release/rust-kv-server" --ca-mode=true > "$log_file" 2>&1 &
            ;;
    esac
    SERVER_PID=$!
    sleep 3  # Give server time to start
}

# Function to stop server
stop_server() {
    if [ -n "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        SERVER_PID=""
    fi
    # Kill any lingering server processes
    pkill -f "go-kv-server|example-py-server|rb-kv-server|rust-kv-server" 2>/dev/null || true
    sleep 1
}

# Function to run client
run_client() {
    local lang=$1
    local log_file="/tmp/grpc-test-client-${lang}.log"

    case $lang in
        go)
            timeout $TEST_TIMEOUT "$BASE_DIR/go/bin/go-kv-client" > "$log_file" 2>&1
            ;;
        python)
            cd "$BASE_DIR"
            timeout $TEST_TIMEOUT uv run python ./python/example-py-client.py > "$log_file" 2>&1
            ;;
        ruby)
            cd "$BASE_DIR/ruby"
            timeout $TEST_TIMEOUT ~/.data/rv/rubies/ruby-3.2.9/bin/bundle exec ~/.data/rv/rubies/ruby-3.2.9/bin/ruby ./rb-kv-client.rb > "$log_file" 2>&1
            cd "$BASE_DIR"
            ;;
        csharp)
            cd "$BASE_DIR/csharp"
            timeout $TEST_TIMEOUT dotnet run > "$log_file" 2>&1
            ;;
        rust)
            timeout $TEST_TIMEOUT "$BASE_DIR/rust/target/release/rust-kv-client" > "$log_file" 2>&1
            ;;
    esac
    return $?
}

# Initialize results storage (bash 3.2 compatible)
RESULTS_FILE="/tmp/grpc-test-results-$$.txt"
> "$RESULTS_FILE"  # Clear file

# Run tests for each curve
for curve in "${CURVES[@]}"; do
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}Testing with curve: ${YELLOW}${curve}${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    # Setup environment for this curve
    export PLUGIN_CLIENT_ALGO="$curve"
    export PLUGIN_SERVER_ALGO="$curve"

    # Source env.sh to load certificates
    cd "$BASE_DIR"
    source ./env.sh > /dev/null 2>&1

    # Run all test combinations
    for test in "${test_combinations[@]}"; do
        IFS=':' read -r server client desc <<< "$test"

        echo -n "  Testing ${desc}... "

        # Start server
        start_server "$server"

        # Run client
        if run_client "$client"; then
            echo -e "${GREEN}✅ PASS${NC}"
            echo "${curve}|${desc}|PASS" >> "$RESULTS_FILE"
        else
            echo -e "${RED}❌ FAIL${NC}"
            echo "${curve}|${desc}|FAIL" >> "$RESULTS_FILE"
        fi

        # Stop server
        stop_server
    done

    echo ""
done

# Display results matrix
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    RESULTS MATRIX                          ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Print header
printf "${BOLD}%-25s" "Server → Client"
for curve in "${CURVES[@]}"; do
    # Shorten curve name for display
    curve_short=$(echo "$curve" | sed 's/ec-secp/P-/' | sed 's/r1//')
    printf "%-15s" "$curve_short"
done
printf "${NC}\n"

echo "─────────────────────────────────────────────────────────────────────"

# Helper function to get result from file
get_result() {
    local curve=$1
    local desc=$2
    grep "^${curve}|${desc}|" "$RESULTS_FILE" | cut -d'|' -f3
}

# Print results for each test combination
for test in "${test_combinations[@]}"; do
    IFS=':' read -r server client desc <<< "$test"

    printf "%-25s" "$desc"

    for curve in "${CURVES[@]}"; do
        result=$(get_result "$curve" "$desc")

        if [ "$result" = "PASS" ]; then
            printf "${GREEN}%-15s${NC}" "✅ PASS"
        else
            printf "${RED}%-15s${NC}" "❌ FAIL"
        fi
    done
    printf "\n"
done

echo ""

# Calculate statistics
TOTAL_TESTS=$(wc -l < "$RESULTS_FILE" | tr -d ' ')
PASSED_TESTS=$(grep -c "PASS$" "$RESULTS_FILE" || echo 0)
FAILED_TESTS=$(grep -c "FAIL$" "$RESULTS_FILE" || echo 0)

# Display summary
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                        SUMMARY                             ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Total Tests:${NC}  $TOTAL_TESTS"
echo -e "  ${GREEN}${BOLD}Passed:${NC}       $PASSED_TESTS"
echo -e "  ${RED}${BOLD}Failed:${NC}       $FAILED_TESTS"
echo -e "  ${BOLD}Success Rate:${NC} $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
echo ""

# Key findings
echo -e "${BOLD}${YELLOW}Key Findings:${NC}"
echo ""

# Check each curve
for curve in "${CURVES[@]}"; do
    curve_passed=$(grep "^${curve}|" "$RESULTS_FILE" | grep -c "PASS$" || echo 0)
    curve_total=$(grep -c "^${curve}|" "$RESULTS_FILE")

    curve_short=$(echo "$curve" | sed 's/ec-secp/P-/' | sed 's/r1//')

    if [ $curve_passed -eq $curve_total ]; then
        echo -e "  ${GREEN}✅ ${curve_short}: All combinations work (${curve_passed}/${curve_total})${NC}"
    elif [ $curve_passed -eq 0 ]; then
        echo -e "  ${RED}❌ ${curve_short}: No combinations work (${curve_passed}/${curve_total})${NC}"
    else
        echo -e "  ${YELLOW}⚠️  ${curve_short}: Partial support (${curve_passed}/${curve_total} working)${NC}"
    fi
done

echo ""

# Cleanup
rm -f "$RESULTS_FILE"

# Exit with appropriate code
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✅ ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "${YELLOW}${BOLD}⚠️  Some tests failed. See results above for details.${NC}"
    exit 1
fi
