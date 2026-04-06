#!/bin/bash
# gRPC Patch Comparison Orchestrator
# Runs comprehensive comparison between unpatched and patched gRPC
#
# Usage: ./compare-grpc-versions.sh [OPTIONS]
#
# Options:
#   --language <lang>   Test specific language (python, ruby, cpp, all)
#   --quick             Skip build if patched version already exists
#   --output <file>     Output report to specific file
#   --help              Show this help message

set -euo pipefail

# Default values
LANGUAGE="python"
QUICK_MODE=false
OUTPUT_FILE=""
SKIP_BUILD=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directories
RESULTS_DIR="results"
BASELINE_DIR="$RESULTS_DIR/baseline"
PATCHED_DIR="$RESULTS_DIR/patched"
REPORTS_DIR="reports"

usage() {
    cat <<EOF
gRPC Patch Comparison Tool

Usage: $0 [OPTIONS]

Runs a comprehensive comparison between unpatched (baseline) and patched gRPC
implementations to demonstrate the fix for P-384/P-521 elliptic curve support.

Options:
    --language <lang>   Test specific language: python, ruby, cpp, or all
                        (default: python)
    --quick             Skip build if patched version already exists
    --output <file>     Custom output file for report
    --skip-build        Skip patching/building (use existing patched version)
    --help              Show this help message

Examples:
    # Compare Python (fastest, ~25 min build)
    $0 --language python

    # Compare all affected languages (~1 hour build)
    $0 --language all

    # Quick comparison if already built
    $0 --language python --quick

Environment:
    This script should be run inside the Docker container:

    docker build -t grpc-curve-test .
    docker run -it grpc-curve-test
    ./compare-grpc-versions.sh --language python

Output:
    Results saved to:
    - $BASELINE_DIR/        (unpatched test results)
    - $PATCHED_DIR/         (patched test results)
    - $REPORTS_DIR/         (comparison report)

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

# Validate language
if [[ "$LANGUAGE" == "all" ]]; then
    TEST_LANGUAGES=("python" "ruby" "cpp")
elif [[ "$LANGUAGE" == *","* ]]; then
    IFS=',' read -ra TEST_LANGUAGES <<< "$LANGUAGE"
else
    TEST_LANGUAGES=("$LANGUAGE")
fi

for lang in "${TEST_LANGUAGES[@]}"; do
    case "$lang" in
        python|ruby|cpp)
            ;;
        *)
            echo -e "${RED}Error: Invalid language '$lang'${NC}"
            echo "Must be one of: python, ruby, cpp, all"
            exit 1
            ;;
    esac
done

# Set default output file if not specified
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="$REPORTS_DIR/comparison-$(date +%Y%m%d-%H%M%S).md"
fi

# Print header
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        gRPC Elliptic Curve Patch Comparison Tool          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Language(s): ${TEST_LANGUAGES[*]}"
echo "  Quick mode: $QUICK_MODE"
echo "  Output: $OUTPUT_FILE"
echo ""

# Create directories
mkdir -p "$BASELINE_DIR" "$PATCHED_DIR" "$REPORTS_DIR"

# Step 1: Run baseline tests (unpatched)
echo -e "${YELLOW}[1/5] Running baseline tests (unpatched gRPC)...${NC}"
echo ""

# Ensure we're using system gRPC
if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    echo -e "${YELLOW}Deactivating virtual environment...${NC}"
    deactivate || true
fi

# Run baseline tests for each language
rm -f "$SCRIPT_DIR/curve-test-results.txt"
for lang in "${TEST_LANGUAGES[@]}"; do
    echo -e "${BLUE}Testing $lang (baseline)...${NC}"
    APPEND_RESULTS=true ./test-all-curves.sh --language "$lang" > "$BASELINE_DIR/${lang}.log" 2>&1 || true
done

# Copy results
if [[ -f "$SCRIPT_DIR/curve-test-results.txt" ]]; then
    cp "$SCRIPT_DIR/curve-test-results.txt" "$BASELINE_DIR/"
    echo -e "${GREEN}✓ Baseline results saved to $BASELINE_DIR/curve-test-results.txt${NC}"
else
    echo -e "${RED}Error: curve-test-results.txt not found in $SCRIPT_DIR!${NC}"
fi

# Capture baseline versions
echo -e "${BLUE}Capturing baseline version information...${NC}"
./utils/capture-grpc-versions.sh baseline > "$BASELINE_DIR/grpc-versions.json"

echo -e "${GREEN}✓ Baseline tests complete${NC}"
echo ""

# Step 2: Build patched gRPC
if [[ "$SKIP_BUILD" == "false" ]]; then
    echo -e "${YELLOW}[2/5] Building patched gRPC...${NC}"
    echo ""

    BUILD_NEEDED=false

    for lang in "${TEST_LANGUAGES[@]}"; do
        case "$lang" in
            python)
                if [[ ! -d "build/patched-grpc/venv" ]] || [[ "$QUICK_MODE" == "false" ]]; then
                    BUILD_NEEDED=true
                    echo -e "${BLUE}Building patched Python gRPC (this takes ~20-30 minutes)...${NC}"
                    ./build-patched-grpc.sh --python 2>&1 | tee "$PATCHED_DIR/python-build.log"
                else
                    echo -e "${GREEN}✓ Patched Python gRPC already exists (skipping build)${NC}"
                fi
                ;;
            ruby)
                if [[ ! -d "build/patched-grpc/grpc/src/ruby/pkg" ]] || [[ "$QUICK_MODE" == "false" ]]; then
                    BUILD_NEEDED=true
                    echo -e "${BLUE}Building patched Ruby gRPC (this takes ~15-20 minutes)...${NC}"
                    ./build-patched-grpc.sh --ruby --install 2>&1 | tee "$PATCHED_DIR/ruby-build.log"
                else
                    echo -e "${GREEN}✓ Patched Ruby gRPC already exists (skipping build)${NC}"
                fi
                ;;
            cpp)
                if [[ ! -d "build/patched-grpc/install" ]] || [[ "$QUICK_MODE" == "false" ]]; then
                    BUILD_NEEDED=true
                    echo -e "${BLUE}Building patched C++ gRPC (this takes ~30-40 minutes)...${NC}"
                    ./build-patched-grpc.sh --cpp --install 2>&1 | tee "$PATCHED_DIR/cpp-build.log"
                else
                    echo -e "${GREEN}✓ Patched C++ gRPC already exists (skipping build)${NC}"
                fi
                ;;
        esac
    done

    if [[ "$BUILD_NEEDED" == "false" ]]; then
        echo -e "${GREEN}✓ All required patched builds already exist${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}[2/5] Skipping build (using existing patched version)...${NC}"
    echo ""
fi

# Step 3: Run patched tests
echo -e "${YELLOW}[3/5] Running patched tests...${NC}"
echo ""

rm -f "$SCRIPT_DIR/curve-test-results.txt"
for lang in "${TEST_LANGUAGES[@]}"; do
    echo -e "${BLUE}Activating patched $lang environment...${NC}"

    # Activate patched environment
    source ./utils/grpc-environment-manager.sh activate "$lang" || {
        echo -e "${RED}Failed to activate patched $lang environment${NC}"
        continue
    }

    echo -e "${BLUE}Testing $lang (patched)...${NC}"
    APPEND_RESULTS=true ./test-all-curves.sh --language "$lang" > "$PATCHED_DIR/${lang}.log" 2>&1 || true

    # Deactivate
    source ./utils/grpc-environment-manager.sh deactivate
done

# Copy patched results
if [[ -f "$SCRIPT_DIR/curve-test-results.txt" ]]; then
    cp "$SCRIPT_DIR/curve-test-results.txt" "$PATCHED_DIR/"
    echo -e "${GREEN}✓ Patched results saved to $PATCHED_DIR/curve-test-results.txt${NC}"
else
    echo -e "${RED}Error: curve-test-results.txt (patched) not found in $SCRIPT_DIR!${NC}"
fi

# Capture patched versions
echo -e "${BLUE}Capturing patched version information...${NC}"

# Need to activate one environment to get patched version info
source ./utils/grpc-environment-manager.sh activate "${TEST_LANGUAGES[0]}" > /dev/null 2>&1 || true
./utils/capture-grpc-versions.sh patched > "$PATCHED_DIR/grpc-versions.json"
source ./utils/grpc-environment-manager.sh deactivate > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Patched tests complete${NC}"
echo ""

# Step 4: Generate comparison report
echo -e "${YELLOW}[4/5] Generating comparison report...${NC}"
echo ""

./utils/generate-comparison-report.sh "$BASELINE_DIR" "$PATCHED_DIR" "$OUTPUT_FILE"

echo ""

# Step 5: Display summary
echo -e "${YELLOW}[5/5] Comparison complete!${NC}"
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      Summary                               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Baseline results:${NC} $BASELINE_DIR/"
echo -e "${GREEN}✓ Patched results:${NC} $PATCHED_DIR/"
echo -e "${GREEN}✓ Comparison report:${NC} $OUTPUT_FILE"
echo ""
echo -e "${BLUE}To view the report:${NC}"
echo "  cat $OUTPUT_FILE"
echo ""
echo -e "${BLUE}To view detailed logs:${NC}"
echo "  Baseline: ls -la $BASELINE_DIR/"
echo "  Patched:  ls -la $PATCHED_DIR/"
echo ""

# Extract and display key metrics from report
if [[ -f "$OUTPUT_FILE" ]]; then
    echo -e "${CYAN}Key Metrics:${NC}"
    grep "Tests Fixed:" "$OUTPUT_FILE" || true
    grep "Success Rate:" "$OUTPUT_FILE" || true
    echo ""
fi

echo -e "${GREEN}Comparison complete! 🎉${NC}"
