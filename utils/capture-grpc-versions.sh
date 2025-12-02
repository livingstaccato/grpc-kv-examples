#!/bin/bash
# Capture gRPC versions and environment metadata
# Usage: ./capture-grpc-versions.sh <baseline|patched>

set -euo pipefail

ENVIRONMENT="${1:-unknown}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "{"
echo "  \"timestamp\": \"$TIMESTAMP\","
echo "  \"environment\": \"$ENVIRONMENT\","
echo "  \"grpc_versions\": {"

# Python version
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c "import grpc; print(grpc.__version__)" 2>/dev/null || echo "not-installed")
    PYTHON_LOCATION=$(python3 -c "import grpc; print(grpc.__file__)" 2>/dev/null || echo "not-found")
    PYTHON_PATCHED="false"
    if [[ "$PYTHON_LOCATION" == *"build/patched-grpc"* ]]; then
        PYTHON_PATCHED="true"
    fi
    echo "    \"python\": {"
    echo "      \"version\": \"$PYTHON_VERSION\","
    echo "      \"package_location\": \"$PYTHON_LOCATION\","
    echo "      \"patched\": $PYTHON_PATCHED,"
    echo "      \"tls_backend\": \"BoringSSL\""
    echo "    },"
fi

# Ruby version
if command -v ruby &> /dev/null; then
    RUBY_VERSION=$(ruby -e "require 'grpc'; puts GRPC::VERSION" 2>/dev/null || echo "not-installed")
    RUBY_GEM_PATH=$(ruby -e "require 'grpc'; puts $LOAD_PATH.grep(/grpc/).first" 2>/dev/null || echo "not-found")
    RUBY_PATCHED="false"
    if [[ "$RUBY_GEM_PATH" == *"build/patched-grpc"* ]]; then
        RUBY_PATCHED="true"
    fi
    echo "    \"ruby\": {"
    echo "      \"version\": \"$RUBY_VERSION\","
    echo "      \"gem_location\": \"$RUBY_GEM_PATH\","
    echo "      \"patched\": $RUBY_PATCHED,"
    echo "      \"tls_backend\": \"BoringSSL\""
    echo "    },"
fi

# C++ version (check installed package)
if command -v pkg-config &> /dev/null && pkg-config --exists grpc++ 2>/dev/null; then
    CPP_VERSION=$(pkg-config --modversion grpc++ 2>/dev/null || echo "not-installed")
    CPP_PREFIX=$(pkg-config --variable=prefix grpc++ 2>/dev/null || echo "not-found")
    CPP_PATCHED="false"
    if [[ "$CPP_PREFIX" == *"build/patched-grpc"* ]] || [[ "${CMAKE_PREFIX_PATH:-}" == *"build/patched-grpc"* ]]; then
        CPP_PATCHED="true"
    fi
    echo "    \"cpp\": {"
    echo "      \"version\": \"$CPP_VERSION\","
    echo "      \"install_prefix\": \"$CPP_PREFIX\","
    echo "      \"patched\": $CPP_PATCHED,"
    echo "      \"tls_backend\": \"BoringSSL\""
    echo "    },"
fi

# Go version (not affected by bug, but included for completeness)
if command -v go &> /dev/null; then
    GO_VERSION=$(go list -m google.golang.org/grpc 2>/dev/null | awk '{print $2}' || echo "not-installed")
    echo "    \"go\": {"
    echo "      \"version\": \"$GO_VERSION\","
    echo "      \"patched\": false,"
    echo "      \"tls_backend\": \"crypto/tls\","
    echo "      \"affected_by_bug\": false"
    echo "    }"
fi

echo "  },"
echo "  \"system_info\": {"
echo "    \"os\": \"$(uname -s)\","
echo "    \"kernel\": \"$(uname -r)\","
echo "    \"arch\": \"$(uname -m)\""
echo "  }"
echo "}"
