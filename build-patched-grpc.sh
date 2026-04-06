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
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patches/grpc-ec-curves-p384-p521.patch"
BUILD_DIR="$SCRIPT_DIR/build/patched-grpc"
GRPC_VERSION="v1.80.0"  # Use a stable version

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
        command -v uv >/dev/null || error "uv not found (install with: curl -LsSf https://astral.sh/uv/install.sh | sh)"
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

# Apply patch using sed (more reliable than git apply across versions)
apply_patch() {
    log "Applying EC curves patch..."

    cd "$BUILD_DIR/grpc"

    local SSL_FILE="src/core/tsi/ssl_transport_security.cc"

    if [ ! -f "$SSL_FILE" ]; then
        error "Source file not found: $SSL_FILE"
    fi

    # Check if already patched
    if grep -q "NID_secp384r1" "$SSL_FILE"; then
        log "Patch already applied, skipping..."
        success "Patch verified - P-384/P-521 support enabled"
        return 0
    fi

    log "Patching $SSL_FILE..."

    # Patch 1: Update kSslEcCurveNames to include P-384 and P-521
    # Change: static const int kSslEcCurveNames[] = {NID_X9_62_prime256v1};
    # To:     static const int kSslEcCurveNames[] = {NID_X9_62_prime256v1, NID_secp384r1, NID_secp521r1};
    sed -i 's/static const int kSslEcCurveNames\[\] = {NID_X9_62_prime256v1};/static const int kSslEcCurveNames[] = {NID_X9_62_prime256v1, NID_secp384r1, NID_secp521r1};/' "$SSL_FILE"

    # Patch 2: Update #if condition to include BoringSSL
    # Change: #if OPENSSL_VERSION_NUMBER >= 0x30000000
    # To:     #if (OPENSSL_VERSION_NUMBER >= 0x30000000) || defined(OPENSSL_IS_BORINGSSL)
    sed -i 's/#if OPENSSL_VERSION_NUMBER >= 0x30000000$/#if (OPENSSL_VERSION_NUMBER >= 0x30000000) || defined(OPENSSL_IS_BORINGSSL)/' "$SSL_FILE"

    # Patch 3: Update the else condition
    # Change: #if OPENSSL_VERSION_NUMBER < 0x30000000L
    # To:     #if (OPENSSL_VERSION_NUMBER < 0x30000000L) && !defined(OPENSSL_IS_BORINGSSL)
    sed -i 's/#if OPENSSL_VERSION_NUMBER < 0x30000000L$/#if (OPENSSL_VERSION_NUMBER < 0x30000000L) \&\& !defined(OPENSSL_IS_BORINGSSL)/' "$SSL_FILE"

    # Patch 4: Update SSL_CTX_set1_groups call to use array size
    # Change: if (!SSL_CTX_set1_groups(context, kSslEcCurveNames, 1)) {
    # To:     if (!SSL_CTX_set1_groups(context, kSslEcCurveNames, sizeof(kSslEcCurveNames)/sizeof(kSslEcCurveNames[0]))) {
    sed -i 's/SSL_CTX_set1_groups(context, kSslEcCurveNames, 1)/SSL_CTX_set1_groups(context, kSslEcCurveNames, sizeof(kSslEcCurveNames)\/sizeof(kSslEcCurveNames[0]))/' "$SSL_FILE"

    # Verify patch
    if grep -q "NID_secp384r1" "$SSL_FILE"; then
        success "Patch applied successfully - P-384/P-521 support enabled"
    else
        error "Patch verification failed - NID_secp384r1 not found"
    fi

    # Show what was changed
    log "Verifying patch contents..."
    grep -n "kSslEcCurveNames\|OPENSSL_IS_BORINGSSL\|0x30000000" "$SSL_FILE" | head -10
}

# Build Python grpcio
build_python() {
    log "Building Python grpcio with patch..."
    log "NOTE: This will take 20-30 minutes..."

    cd "$BUILD_DIR/grpc"

    # Create virtual environment for the build
    log "Creating virtual environment..."
    uv venv "$BUILD_DIR/venv"
    export VIRTUAL_ENV="$BUILD_DIR/venv"
    export PATH="$BUILD_DIR/venv/bin:$PATH"

    # Install build dependencies for gRPC v1.80.0
    log "Installing build dependencies..."
    # Using exact versions from gRPC 1.80.0 requirements
    uv pip install "cython==3.1.1" "setuptools>=77.0.1" "wheel>=0.29" "build>=1.3.0"

    # Verify installed versions
    log "Installed build dependencies:"
    cython --version || echo "Cython not found in PATH"
    uv pip list | grep -E "cython|setuptools|wheel|build"

    # Set environment for building
    export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=false
    export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=false
    export GRPC_PYTHON_BUILD_SYSTEM_CARES=false
    export GRPC_BUILD_WITH_BORING_SSL_ASM=false
    export GRPC_PYTHON_LDFLAGS="-lstdc++"
    export GRPC_PYTHON_BUILD_WITH_CYTHON=1
    # Force language level 3 for Cython
    export GRPC_PYTHON_CYTHON_OPTIONS="--language-level=3"
    # Build and install directly
    log "Building grpcio from source (this takes 20-30 minutes)..."
    log "Build log: $BUILD_DIR/python-build.log"

    if uv pip install --no-build-isolation . 2>&1 | tee "$BUILD_DIR/python-build.log"; then
        success "Python grpcio built and installed successfully!"
    else
        error "Python grpcio build FAILED. Check $BUILD_DIR/python-build.log"
    fi

    # Verify installation
    log "Verifying grpcio installation..."
    python -c "import grpc; print(f'grpcio version: {grpc.__version__}')" || error "grpcio import failed"

    success "Virtual environment with patched grpcio: $BUILD_DIR/venv"
    log "Activate with: source $BUILD_DIR/venv/bin/activate"
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
    rake native

    success "Ruby gem built"
    ls -la pkg/*.gem

    if $DO_INSTALL; then
        local RUBY_GEMS_DIR="$BUILD_DIR/ruby-gems"
        mkdir -p "$RUBY_GEMS_DIR"
        GEM_HOME="$RUBY_GEMS_DIR" gem install pkg/*.gem
        success "Patched Ruby gRPC gem installed to $RUBY_GEMS_DIR"
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
    echo "  Python: source $BUILD_DIR/venv/bin/activate"
    echo "  C++:    export CMAKE_PREFIX_PATH=$BUILD_DIR/install"
    echo "  Ruby:   gem install $BUILD_DIR/grpc/src/ruby/pkg/*.gem"
    echo ""
}

main
/*.gem"
    echo ""
}

main
