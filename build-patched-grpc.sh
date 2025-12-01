#!/bin/bash
#
# Build patched gRPC with P-384/P-521 elliptic curve support
#
# This script clones gRPC, applies the EC curves patch, and builds
# the Python grpcio package with the fix.
#
# Usage:
#   ./build-patched-grpc.sh [--python] [--cpp] [--ruby] [--install]
#
# Options:
#   --python   Build patched Python grpcio wheel
#   --cpp      Build patched C++ gRPC library
#   --ruby     Build patched Ruby gRPC gem
#   --install  Install after building (default: just build)
#   --all      Build all languages
#
# Output:
#   ./build/patched-grpc/   - Built artifacts
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patches/grpc-ec-curves-p384-p521.patch"
BUILD_DIR="$SCRIPT_DIR/build/patched-grpc"
GRPC_VERSION="v1.62.0"  # Use a stable version

BUILD_PYTHON=false
BUILD_CPP=false
BUILD_RUBY=false
DO_INSTALL=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[BUILD]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --python) BUILD_PYTHON=true; shift ;;
        --cpp) BUILD_CPP=true; shift ;;
        --ruby) BUILD_RUBY=true; shift ;;
        --install) DO_INSTALL=true; shift ;;
        --all) BUILD_PYTHON=true; BUILD_CPP=true; BUILD_RUBY=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Default to Python if nothing specified
if ! $BUILD_PYTHON && ! $BUILD_CPP && ! $BUILD_RUBY; then
    BUILD_PYTHON=true
fi

# Check prerequisites
check_prereqs() {
    log "Checking prerequisites..."

    command -v git >/dev/null || error "git not found"
    command -v cmake >/dev/null || error "cmake not found"

    if $BUILD_PYTHON; then
        command -v python3 >/dev/null || error "python3 not found"
        command -v pip3 >/dev/null || error "pip3 not found"
    fi

    if $BUILD_RUBY; then
        command -v ruby >/dev/null || error "ruby not found"
        command -v gem >/dev/null || error "gem not found"
    fi

    [ -f "$PATCH_FILE" ] || error "Patch file not found: $PATCH_FILE"

    success "Prerequisites OK"
}

# Clone gRPC source
clone_grpc() {
    log "Cloning gRPC $GRPC_VERSION..."

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [ -d "grpc" ]; then
        log "gRPC source already exists, updating..."
        cd grpc
        git fetch origin
        git checkout $GRPC_VERSION
        git submodule update --init --recursive
    else
        git clone --depth 1 --branch $GRPC_VERSION \
            --recurse-submodules --shallow-submodules \
            https://github.com/grpc/grpc.git
        cd grpc
    fi

    success "gRPC source ready"
}

# Apply patch
apply_patch() {
    log "Applying EC curves patch..."

    cd "$BUILD_DIR/grpc"

    # Check if patch already applied
    if git diff --quiet src/core/tsi/ssl_transport_security.cc 2>/dev/null; then
        # Try to apply
        if git apply --check "$PATCH_FILE" 2>/dev/null; then
            git apply "$PATCH_FILE"
            success "Patch applied successfully"
        else
            log "Patch may already be applied or conflicts exist"
            # Force apply
            patch -p1 < "$PATCH_FILE" || true
        fi
    else
        log "Source already modified, skipping patch"
    fi

    # Verify patch
    if grep -q "NID_secp384r1" src/core/tsi/ssl_transport_security.cc; then
        success "Patch verified - P-384/P-521 support enabled"
    else
        error "Patch verification failed"
    fi
}

# Build Python grpcio
build_python() {
    log "Building Python grpcio with patch..."

    cd "$BUILD_DIR/grpc"

    # Set environment for building
    export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=false
    export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=false
    export GRPC_PYTHON_BUILD_SYSTEM_CARES=false
    export GRPC_BUILD_WITH_BORING_SSL_ASM=false

    # Build the wheel
    pip3 wheel . --no-deps -w "$BUILD_DIR/wheels/" \
        --config-settings="--build-option=--enable-epoll" \
        2>&1 | tee "$BUILD_DIR/python-build.log"

    success "Python wheel built: $BUILD_DIR/wheels/"
    ls -la "$BUILD_DIR/wheels/"*.whl

    if $DO_INSTALL; then
        log "Installing patched grpcio..."
        pip3 install --force-reinstall "$BUILD_DIR/wheels/"grpcio*.whl
        success "Patched grpcio installed"
    fi
}

# Build C++ gRPC
build_cpp() {
    log "Building C++ gRPC with patch..."

    cd "$BUILD_DIR/grpc"

    mkdir -p cmake/build
    cd cmake/build

    cmake ../.. \
        -DgRPC_INSTALL=ON \
        -DgRPC_BUILD_TESTS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install"

    make -j$(nproc)

    if $DO_INSTALL; then
        make install
        success "C++ gRPC installed to $BUILD_DIR/install"
    else
        success "C++ gRPC built in $BUILD_DIR/grpc/cmake/build"
    fi
}

# Build Ruby gRPC
build_ruby() {
    log "Building Ruby gRPC gem with patch..."

    cd "$BUILD_DIR/grpc"

    # Build the gem
    cd src/ruby
    bundle install
    rake native_gem

    success "Ruby gem built"
    ls -la pkg/*.gem

    if $DO_INSTALL; then
        gem install pkg/*.gem
        success "Patched Ruby gRPC gem installed"
    fi
}

# Main
main() {
    echo ""
    log "=========================================="
    log "  Building Patched gRPC"
    log "  (P-384 + P-521 Elliptic Curve Support)"
    log "=========================================="
    echo ""

    check_prereqs
    clone_grpc
    apply_patch

    if $BUILD_PYTHON; then
        build_python
    fi

    if $BUILD_CPP; then
        build_cpp
    fi

    if $BUILD_RUBY; then
        build_ruby
    fi

    echo ""
    success "Build complete!"
    echo ""
    echo "Artifacts location: $BUILD_DIR/"
    echo ""
    echo "To test with patched gRPC:"
    echo "  Python: pip install $BUILD_DIR/wheels/grpcio*.whl"
    echo "  C++:    export CMAKE_PREFIX_PATH=$BUILD_DIR/install"
    echo "  Ruby:   gem install $BUILD_DIR/grpc/src/ruby/pkg/*.gem"
    echo ""
}

main
