#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Clean build directory
rm -rf build

# Configure and build
cmake -B build -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}"
cmake --build build
