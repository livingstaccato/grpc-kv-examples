#!/bin/bash
# Generate Swift protobuf and gRPC code from kv.proto
# Requires: protoc, protoc-gen-swift, protoc-gen-grpc-swift (2.x)
#
# Install the plugins:
#   brew install swift-protobuf grpc-swift
# Or build from source:
#   git clone https://github.com/grpc/grpc-swift-protobuf.git
#   cd grpc-swift-protobuf && swift build -c release
#   cp .build/release/protoc-gen-grpc-swift /usr/local/bin/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_DIR="$SCRIPT_DIR/../proto"
OUTPUT_DIR="$SCRIPT_DIR/Sources"

echo "Generating Swift protobuf code..."

# Generate for both KVServer and KVClient
for target in KVServer KVClient; do
    mkdir -p "$OUTPUT_DIR/$target"

    # Generate protobuf messages (kv.pb.swift)
    protoc \
        --proto_path="$PROTO_DIR" \
        --swift_out="$OUTPUT_DIR/$target" \
        --swift_opt=Visibility=Public \
        "$PROTO_DIR/kv.proto"

    # Generate gRPC service code (kv.grpc.swift)
    protoc \
        --proto_path="$PROTO_DIR" \
        --grpc-swift_out="$OUTPUT_DIR/$target" \
        --grpc-swift_opt=Visibility=Public \
        "$PROTO_DIR/kv.proto"

    echo "Generated proto files for $target"
done

echo "Done! Generated files:"
find "$OUTPUT_DIR" -name "*.swift" -newer "$PROTO_DIR/kv.proto" | head -10
