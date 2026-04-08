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
    log "Applying EC curves patch using Python robust patcher..."
    cd "$BUILD_DIR/grpc"

    local TARGET_FILE="src/core/tsi/ssl_transport_security.cc"
    if [ ! -f "$TARGET_FILE" ]; then
        error "Target file not found: $TARGET_FILE"
    fi

    # Use Python for robust regex-based patching
    python3 <<EOF
import re
import sys

with open('$TARGET_FILE', 'r') as f:
    content = f.read()

# 1. Update kSslEcCurveNames definition guard and content
# Handle different indentation and spacing
pattern1 = r'#if OPENSSL_VERSION_NUMBER >= 0x30000000\s+static const int kSslEcCurveNames\[\] = {NID_X9_62_prime256v1};'
replacement1 = '#if OPENSSL_VERSION_NUMBER >= 0x30000000 || defined(OPENSSL_IS_BORINGSSL)\nstatic const int kSslEcCurveNames[] = {NID_X9_62_prime256v1, NID_secp384r1, NID_secp521r1};'
content = re.sub(pattern1, replacement1, content)

# 2. Update legacy path guard to EXCLUDE BoringSSL
content = content.replace(
    '#if OPENSSL_VERSION_NUMBER < 0x30000000L',
    '#if (OPENSSL_VERSION_NUMBER < 0x30000000L) && !defined(OPENSSL_IS_BORINGSSL)'
)
content = content.replace(
    '#if OPENSSL_VERSION_NUMBER < 0x30000000',
    '#if (OPENSSL_VERSION_NUMBER < 0x30000000) && !defined(OPENSSL_IS_BORINGSSL)'
)

# 3. Update modern path usage to include BoringSSL
# Look for the #else block that usually follows the legacy path
content = content.replace(
    '#else\n    if (!SSL_CTX_set1_groups(context, kSslEcCurveNames, 1)) {',
    '#else\n    if (!SSL_CTX_set1_groups(context, kSslEcCurveNames, sizeof(kSslEcCurveNames)/sizeof(kSslEcCurveNames[0]))) {'
)

# Alternative for cases where #else might have different content or spacing
content = re.sub(
    r'SSL_CTX_set1_groups\(context, kSslEcCurveNames, 1\)',
    'SSL_CTX_set1_groups(context, kSslEcCurveNames, sizeof(kSslEcCurveNames)/sizeof(kSslEcCurveNames[0]))',
    content
)

# 4. Definitive block replacement for the ECDH setup in populate_ssl_context
# This is more robust than separate replaces as it handles the whole logic at once
ecdh_setup_pattern = r'#if OPENSSL_VERSION_NUMBER < 0x30000000L\s+EC_KEY\* ecdh = EC_KEY_new_by_curve_name\(NID_X9_62_prime256v1\);\s+if \(!SSL_CTX_set_tmp_ecdh\(context, ecdh\)\) {\s+gpr_log\(GPR_ERROR, "Could not set ephemeral ECDH key."\);\s+EC_KEY_free\(ecdh\);\s+return TSI_INTERNAL_ERROR;\s+}\s+SSL_CTX_set_options\(context, SSL_OP_SINGLE_ECDH_USE\);\s+EC_KEY_free\(ecdh\);\s+#else\s+if \(!SSL_CTX_set1_groups\(context, kSslEcCurveNames, 1\)\) {\s+gpr_log\(GPR_ERROR, "Could not set ephemeral ECDH key."\);\s+return TSI_INTERNAL_ERROR;\s+}\s+SSL_CTX_set_options\(context, SSL_OP_SINGLE_ECDH_USE\);\s+#endif'

new_ecdh_setup = """#if (OPENSSL_VERSION_NUMBER < 0x30000000L) && !defined(OPENSSL_IS_BORINGSSL)
    EC_KEY* ecdh = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
    if (!SSL_CTX_set_tmp_ecdh(context, ecdh)) {
      gpr_log(GPR_ERROR, "Could not set ephemeral ECDH key.");
      EC_KEY_free(ecdh);
      return TSI_INTERNAL_ERROR;
    }
    SSL_CTX_set_options(context, SSL_OP_SINGLE_ECDH_USE);
    EC_KEY_free(ecdh);
#else
    if (!SSL_CTX_set1_groups(context, kSslEcCurveNames, sizeof(kSslEcCurveNames)/sizeof(kSslEcCurveNames[0]))) {
      gpr_log(GPR_ERROR, "Could not set ephemeral ECDH key.");
      return TSI_INTERNAL_ERROR;
    }
    SSL_CTX_set_options(context, SSL_OP_SINGLE_ECDH_USE);
#endif"""

if re.search(ecdh_setup_pattern, content):
    log("Found exact ECDH setup pattern, applying definitive replacement")
    content = re.sub(ecdh_setup_pattern, new_ecdh_setup, content)
else:
    print("Warning: Could not find exact ecdh_setup_pattern for block replacement")

with open('$TARGET_FILE', 'w') as f:
    f.write(content)
EOF

    # 4. Disable Ruby gem build artifact cleanup which fails on some filesystems
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

    # Verification
    if grep -q "NID_secp521r1" "$TARGET_FILE" && grep -q "sizeof(kSslEcCurveNames)" "$TARGET_FILE"; then
        success "Patch applied successfully - P-384/P-521 support enabled with correct size"
    else
        error "Failed to apply complete patch - verification failed in $TARGET_FILE"
    fi
    
    if grep -q "defined(OPENSSL_IS_BORINGSSL)" "$TARGET_FILE"; then
        success "BoringSSL compatibility logic inserted"
    else
        warn "BoringSSL check not found - patch might be incomplete"
    fi

    log "Final patch verification (line numbers):"
    grep -nE "OPENSSL_IS_BORINGSSL|NID_secp384r1|kSslEcCurveNames" "$TARGET_FILE" || true
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
        
        # Pre-compile the C++ client example against the patched gRPC
        log "Pre-compiling C++ client example with patched gRPC..."
        export CMAKE_PREFIX_PATH="$BUILD_DIR/install"
        cd "$SCRIPT_DIR/cpp"
        # Make sure build script is executable
        chmod +x ./build.sh
        ./build.sh
        
        # Copy the binary to the install prefix for easier transport/caching
        mkdir -p "$BUILD_DIR/install/bin"
        cp build/kv-client "$BUILD_DIR/install/bin/"
        success "C++ client pre-compiled successfully"
        
        # Clean up build directory to save space (gRPC build is HUGE)
        log "Cleaning up C++ build directory..."
        cd "$BUILD_DIR/grpc/cmake/build"
        rm -rf *
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
        
        # Install dependencies into our local gem home
        log "Installing dependencies to $RUBY_GEMS_DIR..."
        GEM_HOME="$RUBY_GEMS_DIR" GEM_PATH="$RUBY_GEMS_DIR:$(ruby -e 'puts Gem.path.join(":")')" gem install google-protobuf --no-document
        
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
