#!/bin/bash
# gRPC Environment Manager
# Manages switching between system (unpatched) and patched gRPC installations
#
# Usage:
#   source utils/grpc-environment-manager.sh activate python
#   source utils/grpc-environment-manager.sh deactivate
#   source utils/grpc-environment-manager.sh status

set -euo pipefail

ACTION="${1:-status}"
LANGUAGE="${2:-python}"

STATE_FILE="/tmp/grpc-env-state.json"
BUILD_DIR="${PWD}/build/patched-grpc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

activate_python() {
    local VENV_PATH="$BUILD_DIR/venv"

    if [[ ! -d "$VENV_PATH" ]]; then
        echo -e "${RED}Error: Patched Python venv not found at $VENV_PATH${NC}"
        echo "Run: ./build-patched-grpc.sh --python"
        return 1
    fi

    # Deactivate any existing venv first
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        deactivate 2>/dev/null || true
    fi

    # Activate patched venv
    source "$VENV_PATH/bin/activate"

    # Verify patch is applied
    if python3 -c "import grpc; loc = grpc.__file__; exit(0 if 'patched-grpc' in loc else 1)" 2>/dev/null; then
        echo -e "${GREEN}✓ Activated patched Python gRPC${NC}"
        python3 -c "import grpc; print(f'  Version: {grpc.__version__}'); print(f'  Location: {grpc.__file__}')"

        # Save state
        echo "{\"active\": true, \"language\": \"python\", \"venv\": \"$VENV_PATH\"}" > "$STATE_FILE"
        return 0
    else
        echo -e "${RED}Error: Activated venv but gRPC is not from patched location${NC}"
        return 1
    fi
}

activate_ruby() {
    local RUBY_GEMS_DIR="$BUILD_DIR/ruby-gems"

    if [[ ! -d "$RUBY_GEMS_DIR" ]]; then
        # Fallback to checking for the .gem file to install it
        local GEM_PATH="$BUILD_DIR/grpc/pkg"
        if [[ ! -d "$GEM_PATH" ]] || ! ls "$GEM_PATH"/*.gem &>/dev/null; then
            echo -e "${RED}Error: Patched Ruby gem not found at $GEM_PATH and $RUBY_GEMS_DIR doesn't exist${NC}"
            echo "Run: ./build-patched-grpc.sh --ruby --install"
            return 1
        fi
    fi

    # Set GEM_HOME to use patched gem
    export GEM_HOME="$RUBY_GEMS_DIR"
    # Capture current GEM_PATH or use default if empty
    local CURRENT_GEM_PATH="${GEM_PATH:-$(ruby -e 'puts Gem.path.join(":")')}"
    export GEM_PATH="$GEM_HOME:$CURRENT_GEM_PATH"
    export PATH="$GEM_HOME/bin:$PATH"

    echo -e "${GREEN}✓ Activated patched Ruby gRPC${NC}"
    echo "  GEM_HOME: $GEM_HOME"

    # Save state
    echo "{\"active\": true, \"language\": \"ruby\", \"gem_home\": \"$GEM_HOME\"}" > "$STATE_FILE"
    return 0
}

activate_cpp() {
    local INSTALL_PREFIX="$BUILD_DIR/install"

    if [[ ! -d "$INSTALL_PREFIX" ]]; then
        echo -e "${RED}Error: Patched C++ gRPC not found at $INSTALL_PREFIX${NC}"
        echo "Run: ./build-patched-grpc.sh --cpp --install"
        return 1
    fi

    # Set CMake prefix path
    export CMAKE_PREFIX_PATH="$INSTALL_PREFIX:${CMAKE_PREFIX_PATH:-}"
    export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:${LD_LIBRARY_PATH:-}"
    export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

    echo -e "${GREEN}✓ Activated patched C++ gRPC${NC}"
    echo "  Install prefix: $INSTALL_PREFIX"
    echo "  CMAKE_PREFIX_PATH: $CMAKE_PREFIX_PATH"

    # Save state
    echo "{\"active\": true, \"language\": \"cpp\", \"prefix\": \"$INSTALL_PREFIX\"}" > "$STATE_FILE"
    return 0
}

deactivate_env() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${YELLOW}No active patched environment${NC}"
        return 0
    fi

    local LANG=$(grep -o '"language": "[^"]*"' "$STATE_FILE" | cut -d'"' -f4 2>/dev/null || echo "unknown")

    case "$LANG" in
        python)
            if [[ -n "${VIRTUAL_ENV:-}" ]]; then
                deactivate 2>/dev/null || true
                echo -e "${GREEN}✓ Deactivated patched Python environment${NC}"
            fi
            ;;
        ruby)
            unset GEM_HOME
            unset GEM_PATH
            # Restore PATH (simplified - removes our GEM_HOME/bin)
            export PATH=$(echo "$PATH" | sed "s|$BUILD_DIR/ruby-gems/bin:||g")
            echo -e "${GREEN}✓ Deactivated patched Ruby environment${NC}"
            ;;
        cpp)
            unset CMAKE_PREFIX_PATH
            unset LD_LIBRARY_PATH
            unset PKG_CONFIG_PATH
            echo -e "${GREEN}✓ Deactivated patched C++ environment${NC}"
            ;;
    esac

    rm -f "$STATE_FILE"
    echo -e "${BLUE}Restored system gRPC environment${NC}"
}

show_status() {
    echo -e "${BLUE}=== gRPC Environment Status ===${NC}"

    if [[ -f "$STATE_FILE" ]]; then
        echo -e "${GREEN}Active patched environment:${NC}"
        cat "$STATE_FILE" | python3 -m json.tool 2>/dev/null || cat "$STATE_FILE"
    else
        echo -e "${YELLOW}No patched environment active (using system gRPC)${NC}"
    fi

    echo ""
    echo "Current gRPC installations:"

    if command -v python3 &>/dev/null; then
        echo -n "  Python: "
        python3 -c "import grpc; print(f'{grpc.__version__} @ {grpc.__file__}')" 2>/dev/null || echo "not installed"
    fi

    if command -v ruby &>/dev/null; then
        echo -n "  Ruby: "
        ruby -e "require 'grpc'; puts \"#{GRPC::VERSION} @ #{$LOAD_PATH.grep(/grpc/).first}\"" 2>/dev/null || echo "not installed"
    fi

    if command -v pkg-config &>/dev/null; then
        echo -n "  C++: "
        pkg-config --modversion grpc++ 2>/dev/null || echo "not installed"
    fi
}

# Main logic
case "$ACTION" in
    activate)
        case "$LANGUAGE" in
            python)
                activate_python
                ;;
            ruby)
                activate_ruby
                ;;
            cpp)
                activate_cpp
                ;;
            *)
                echo -e "${RED}Error: Unknown language '$LANGUAGE'${NC}"
                echo "Usage: source $0 activate <python|ruby|cpp>"
                return 1
                ;;
        esac
        ;;
    deactivate)
        deactivate_env
        ;;
    status)
        show_status
        ;;
    *)
        echo -e "${RED}Error: Unknown action '$ACTION'${NC}"
        echo "Usage: source $0 <activate|deactivate|status> [language]"
        return 1
        ;;
esac
