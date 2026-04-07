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

    # Setup ccache
    if command -v ccache &> /dev/null; then
        log "Enabling ccache for faster builds..."
        export PATH="/usr/lib/ccache:$PATH"
        export CMAKE_CXX_COMPILER_LAUNCHER=ccache
        export CMAKE_C_COMPILER_LAUNCHER=ccache
        ccache --max-size=2G
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

    # Verify gemspec exists if we're doing anything with Ruby
    if [ -f "grpc.gemspec" ]; then
        success "Found grpc.gemspec in root"
    else
        warn "grpc.gemspec NOT found in root. Checking src/ruby..."
        if [ -f "src/ruby/grpc.gemspec" ]; then
            log "Found grpc.gemspec in src/ruby"
        else
            warn "grpc.gemspec not found anywhere!"
        fi
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
    
    if [ ! -f "src/core/tsi/ssl_transport_security.cc" ]; then
        error "Target file not found: src/core/tsi/ssl_transport_security.cc"
    fi

    # Try different variants of the Curve list to be robust
    if grep -q "NID_X9_62_prime256v1}" src/core/tsi/ssl_transport_security.cc; then
        sed -i 's/NID_X9_62_prime256v1}/NID_X9_62_prime256v1, NID_secp384r1, NID_secp521r1}/g' \
            src/core/tsi/ssl_transport_security.cc
    elif grep -q "NID_X9_62_prime256v1 }" src/core/tsi/ssl_transport_security.cc; then
        sed -i 's/NID_X9_62_prime256v1 }/NID_X9_62_prime256v1, NID_secp384r1, NID_secp521r1 }/g' \
            src/core/tsi/ssl_transport_security.cc
    else
        warn "Could not find standard curve list pattern. Trying more general pattern..."
        sed -i 's/NID_X9_62_prime256v1/NID_X9_62_prime256v1, NID_secp384r1, NID_secp521r1/g' \
            src/core/tsi/ssl_transport_security.cc
    fi

    # Disable Ruby gem build artifact cleanup which fails on some filesystems
    if [ -f "src/ruby/ext/grpc/extconf.rb" ]; then
        log "Disabling Ruby build cleanup in src/ruby/ext/grpc/extconf.rb..."
        sed -i 's/rm_grpc_core_libs = .*/rm_grpc_core_libs = "true"/' src/ruby/ext/grpc/extconf.rb || true
        sed -i 's/rm_obj_cmd = .*/rm_obj_cmd = "true"/' src/ruby/ext/grpc/extconf.rb || true
        sed -i 's/strip_tool = .*/strip_tool = "true"/' src/ruby/ext/grpc/extconf.rb || true
    elif [ -f "ext/grpc/extconf.rb" ]; then
        log "Disabling Ruby build cleanup in ext/grpc/extconf.rb..."
        sed -i 's/rm_grpc_core_libs = .*/rm_grpc_core_libs = "true"/' ext/grpc/extconf.rb || true
        sed -i 's/rm_obj_cmd = .*/rm_obj_cmd = "true"/' ext/grpc/extconf.rb || true
        sed -i 's/strip_tool = .*/strip_tool = "true"/' ext/grpc/extconf.rb || true
    fi

    # Insert BoringSSL check for set1_groups
    if ! grep -q "OPENSSL_IS_BORINGSSL" src/core/tsi/ssl_transport_security.cc; then
        log "Adding BoringSSL check to src/core/tsi/ssl_transport_security.cc..."
        sed -i 's/OPENSSL_VERSION_NUMBER >= 0x30000000/OPENSSL_VERSION_NUMBER >= 0x30000000 || defined(OPENSSL_IS_BORINGSSL)/g' \
            src/core/tsi/ssl_transport_security.cc
    fi

    # Check if it worked
    if grep -q "NID_secp384r1" src/core/tsi/ssl_transport_security.cc; then
        success "Patch applied successfully - P-384/P-521 support enabled"
    else
        error "Failed to apply curve list patch"
    fi
    
    if grep -q "OPENSSL_IS_BORINGSSL" src/core/tsi/ssl_transport_security.cc; then
        success "BoringSSL API check added successfully"
        # Also need to update the size parameter in set1_groups call
        log "Updating SSL_CTX_set1_groups count parameter..."
        sed -i 's/kSslEcCurveNames, 1)/kSslEcCurveNames, sizeof(kSslEcCurveNames)\/sizeof(kSslEcCurveNames[0]))/g' \
            src/core/tsi/ssl_transport_security.cc
    else
        warn "Failed to add BoringSSL API check - fix might not work as expected"
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
    
    # Also install project requirements
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        log "Installing project requirements..."
        uv pip install -r "$SCRIPT_DIR/requirements.txt"
    fi

    # Set environment for building
    export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=false
    export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=false
    export GRPC_PYTHON_BUILD_SYSTEM_CARES=false
    export GRPC_BUILD_WITH_BORING_SSL_ASM=false
    export GRPC_PYTHON_LDFLAGS="-lstdc++"
    export GRPC_PYTHON_BUILD_WITH_CYTHON=1
    # Force language level 3 for Cython
    export GRPC_PYTHON_CYTHON_OPTIONS="--language-level=3"
    
    # Use ccache for extension compilation
    if command -v ccache &> /dev/null; then
        export CC="ccache gcc"
        export CXX="ccache g++"
    fi

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

    # Instead of rake compile which is brittle, use gem install directly
    # with flags to point to our patched libraries
    export GRPC_RUBY_USE_SYSTEM_LIBRARIES=1
    
    log "Building the gem package..."
    # grpc.gemspec is in the root of the repo in v1.80.0
    gem build grpc.gemspec
    mkdir -p pkg
    mv grpc-*.gem pkg/ || true
    
    log "Contents of pkg directory:"
    ls -la pkg/
    
    local GEM_FILE=$(ls pkg/grpc-*.gem 2>/dev/null | head -n 1 || ls grpc-*.gem 2>/dev/null | head -n 1)
    [ -n "$GEM_FILE" ] || error "No gem file found!"
    log "Found gem file: $GEM_FILE"

    if $DO_INSTALL; then
        local RUBY_GEMS_DIR="$BUILD_DIR/ruby-gems"
        mkdir -p "$RUBY_GEMS_DIR"
        log "Installing gem $GEM_FILE to $RUBY_GEMS_DIR using patched libraries..."
        
        # This tells gem install to use our patched libraries during compilation
        # Set environment variables to disable -Werror and use ccache
        export CFLAGS="-Wno-unused-parameter -Wno-error"
        export CXXFLAGS="-Wno-unused-parameter -Wno-error"
        
        if command -v ccache &> /dev/null; then
            export CC="ccache gcc"
            export CXX="ccache g++"
        fi

        GEM_HOME="$RUBY_GEMS_DIR" gem install "$GEM_FILE" -- \
            --with-grpc-include="$BUILD_DIR/install/include" \
            --with-grpc-lib="$BUILD_DIR/install/lib" \
            --with-grpc-config=opt
            
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
