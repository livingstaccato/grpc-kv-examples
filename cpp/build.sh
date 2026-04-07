#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configure if build directory doesn't exist
if [ ! -d "build" ]; then
    cmake -B build -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}"
fi

# Build
cmake --build build
