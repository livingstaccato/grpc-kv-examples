#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[CPP-BUILD] Starting C++ build in $SCRIPT_DIR"
echo "[CPP-BUILD] CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH:-not set}"

# Clean build directory to be sure
rm -rf build
mkdir -p build

# Configure
echo "[CPP-BUILD] Running CMake configuration..."
cmake -B build -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}"

# Build
echo "[CPP-BUILD] Running CMake build..."
cmake --build build -j$(nproc)

echo "[CPP-BUILD] Build successful!"
