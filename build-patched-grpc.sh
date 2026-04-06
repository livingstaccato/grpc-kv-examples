#!/bin/bash
#
# Build patched gRPC with P-384/P-521 elliptic curve support
#
# This script clones gRPC, applies the EC curves patch, and builds
# the Python grpcio package with the fix.
#
# Usage:
#   ./build-patched-grpc.sh [--python] [--cpp] [--ruby] [--all] [--install]
#
# Options:
#   --python    Build Python grpcio
#   --cpp       Build C++ gRPC
#   --ruby      Build Ruby gRPC gem
#   --all       Build all of the above
#   --install   Install to build/patched-grpc/install
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

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${CYAN}[BUILD]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_prereqs() {
    log "Checking prerequisites..."
    for cmd in git cmake make g++; do
        if ! command -v $cmd &> /dev/null; then
            error "$cmd is required but not installed."
        fi
    done
    
    if ! command -v uv &> /dev/null; then
        warn "uv not found, trying to install..."
        curl -LsSf https://astral.sh/uv/install.sh | sh || true
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
}

clone_grpc() {
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [ -d "grpc" ]; then
        log "gRPC source already exists, skipping clone"
    else
        log "Cloning gRPC $GRPC_VERSION..."
        git clone --depth 1 --branch $GRPC_VERSION \
            --recurse-submodules --shallow-submodules \
            https://github.com/grpc/grpc.git
        cd grpc
        # Remove .git to save space
        find . -name ".git" -type d -exec rm -rf {} + || true
    fi

    success "gRPC source ready"
}

apply_patch() {
    log "Applying EC curves patch..."
    cd "$BUILD_DIR/grpc"

    if [ ! -f "$PATCH_FILE" ]; then
        error "Patch file not found: $PATCH_FILE"
    fi

    # Check if already patched
    if grep -q "NID_secp384r1" src/core/tsi/ssl_transport_security.cc; then
        log "Patch already applied, skipping"
        return
    fi

    log "Patching src/core/tsi/ssl_transport_security.cc..."
    
    # Simple search and replace for the curve list
    sed -i 's/NID_X9_62_prime256v1}/NID_X9_62_prime256v1, NID_secp384r1, NID_secp521r1}/g' \
        src/core/tsi/ssl_transport_security.cc

    # Disable Ruby gem build artifact cleanup which fails on some filesystems
    log "Disabling Ruby build cleanup in extconf.rb..."
    sed -i 's/rm -f #{grpc_lib_dir}\/\*\.a/:/g' src/ruby/ext/grpc/extconf.rb || true
    sed -i 's/rm -rf #{grpc_obj_dir}/:/g' src/ruby/ext/grpc/extconf.rb || true

    # Check if it worked
    if grep -q "NID_secp384r1" src/core/tsi/ssl_transport_security.cc; then
        success "Patch applied successfully - P-384/P-521 support enabled"
    else
        error "Failed to apply patch"
    fi

    log "Verifying patch contents..."
    grep -nE "OPENSSL_IS_BORINGSSL|NID_secp384r1|kSslEcCurveNames" src/core/tsi/ssl_transport_security.cc || true
}

build_python() {
    log "Building Python grpcio with patch..."
    log "NOTE: This will take 20-30 minutes..."

    cd "$BUILD_DIR/grpc"

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

    log "Verifying grpcio installation..."
    python -c "import grpc; print(f'grpcio version: {grpc.__version__}')" || error "grpcio import failed"

    success "Virtual environment with patched grpcio: $BUILD_DIR/venv"
    log "Activate with: source $BUILD_DIR/venv/bin/activate"
}

build_cpp() {
    log "Building C++ gRPC with patch..."

    cd "$BUILD_DIR/grpc"

    mkdir -p cmake/build
    cd cmake/build

    log "Running cmake configuration..."
    cmake ../.. \
        -DgRPC_INSTALL=ON \
        -DgRPC_BUILD_TESTS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install"

    log "Running make (this takes 30-40 minutes)..."
    if make -j$(nproc) 2>&1 | tee "$BUILD_DIR/cpp-build.log"; then
        success "C++ gRPC built successfully"
    else
        error "C++ gRPC build FAILED. Check $BUILD_DIR/cpp-build.log"
    fi

    log "Running make install..."
    if make install 2>&1 | tee -a "$BUILD_DIR/cpp-build.log"; then
        success "C++ gRPC installed to $BUILD_DIR/install"
        # Clean up build directory to save space (gRPC build is HUGE)
        log "Cleaning up C++ build directory..."
        rm -rf "$BUILD_DIR/grpc/cmake/build"
        df -h /workspace || true
    else
        error "C++ gRPC install FAILED. Check $BUILD_DIR/cpp-build.log"
    fi
}

# Build Ruby gRPC
build_ruby() {
    log "Building Ruby gRPC gem against patched C++ gRPC..."

    cd "$BUILD_DIR/grpc"

    # Check if C++ build exists
    if [ ! -d "$BUILD_DIR/install" ]; then
        error "C++ gRPC build not found at $BUILD_DIR/install. Build C++ first."
    fi

    # Build the gem against system (our patched) libraries
    cd src/ruby
    export GRPC_RUBY_USE_SYSTEM_LIBRARIES=1
    export CMAKE_PREFIX_PATH="$BUILD_DIR/install"
    export LD_LIBRARY_PATH="$BUILD_DIR/install/lib:$LD_LIBRARY_PATH"
    
    log "Running bundle install..."
    bundle install
    
    log "Running rake compile using patched system libraries..."
    if bundle exec rake compile -- \
        --with-grpc-include="$BUILD_DIR/install/include" \
        --with-grpc-lib="$BUILD_DIR/install/lib" 2>&1 | tee "$BUILD_DIR/ruby-build.log"; then
        success "Ruby extension compiled successfully against patched libraries"
    else
        error "Ruby extension compilation FAILED. Check $BUILD_DIR/ruby-build.log"
    fi

    log "Building the gem package..."
    gem build grpc.gemspec
    mkdir -p pkg
    mv grpc-*.gem pkg/ || true

    ls -la pkg/*.gem || error "No gems found in pkg/"

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
    df -h /workspace || true
    free -m || true
    clone_grpc
    apply_patch

    if $BUILD_PYTHON; then
        build_python
        df -h /workspace || true
        free -m || true
    fi

    if $BUILD_CPP; then
        build_cpp
        df -h /workspace || true
        free -m || true
    fi

    if $BUILD_RUBY; then
        build_ruby
        df -h /workspace || true
        free -m || true
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

# Parse arguments
if [ $# -eq 0 ]; then
    error "No options specified. Use --python, --cpp, --ruby, or --all."
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --python)
            BUILD_PYTHON=true
            ;;
        --cpp)
            BUILD_CPP=true
            ;;
        --ruby)
            BUILD_RUBY=true
            ;;
        --all)
            BUILD_PYTHON=true
            BUILD_CPP=true
            BUILD_RUBY=true
            ;;
        --install)
            DO_INSTALL=true
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
    shift
done

main
