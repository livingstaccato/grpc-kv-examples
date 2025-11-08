#!/bin/bash
#
# Generate PHP proto files from kv.proto
#
# Requirements:
# - composer install (to get grpc-tools)
# - protoc compiler
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROTO_DIR="$PROJECT_ROOT/proto"
PHP_OUT_DIR="$SCRIPT_DIR/proto"

echo "🔨 Generating PHP proto files..."
echo "📂 Proto dir: $PROTO_DIR"
echo "📂 Output dir: $PHP_OUT_DIR"

# Create output directory
mkdir -p "$PHP_OUT_DIR"

# Generate PHP files using protoc
protoc --proto_path="$PROTO_DIR" \
    --php_out="$PHP_OUT_DIR" \
    --grpc_out="$PHP_OUT_DIR" \
    --plugin=protoc-gen-grpc="$(which grpc_php_plugin)" \
    "$PROTO_DIR/kv.proto"

echo "✅ Proto files generated successfully!"
echo ""
echo "Generated files:"
ls -lh "$PHP_OUT_DIR"
