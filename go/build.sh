#!/bin/sh

set -e # Exit on any error

export KV_CLIENT="$(pwd)/kv-go-client"
export KV_PLUGIN="$(pwd)/kv-go-server"

echo "Cleaning up previous builds..."
rm -f ${KV_CLIENT} ${KV_PLUGIN}

# Initialize module if needed
if [ ! -f go.mod ]; then
	echo "Initializing Go module..."
	go mod init github.com/provide-io/pyvider-rpcplugin/examples/grpc

	echo "Installing buf dependencies..."
	go install github.com/bufbuild/buf/cmd/buf@latest

	echo "Generating protobuf code..."
	buf generate
fi

echo "Updating Go dependencies..."
go mod tidy

echo "Building client and server..."
go build -o kv-go-client ./plugin-go-client
go build -o kv-go-server ./plugin-go-server

echo "Build complete. Binary information:"
file ${KV_CLIENT}
file ${KV_PLUGIN}

echo "\nNext steps:"
echo "1. Set environment variables: source env.sh"
echo "2. Run tests: ./test.sh"
