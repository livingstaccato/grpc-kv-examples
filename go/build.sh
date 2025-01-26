#!/bin/sh

set -e # Exit on any error

export KV_CLIENT="$(pwd)/bin/go-kv-client"
export KV_SERVER="$(pwd)/bin/go-kv-server"

echo "Cleaning up previous builds..."
rm -f ${KV_CLIENT} ${KV_SERVER}

# Initialize module if needed
if [ ! -f go.mod ]; then
	echo "Initializing Go module..."
	go mod init github.com/livingstaccato/grpc-kv-examples

	echo "Installing buf dependencies..."
	go install github.com/bufbuild/buf/cmd/buf@latest

	echo "Generating protobuf code..."
	buf generate
fi

echo "Updating Go dependencies..."
go mod tidy

echo "Building client and server..."
go build -o ${KV_CLIENT} ./go-kv-client.go
go build -o ${KV_SERVER} ./go-kv-server.go

echo "Build complete. Binary information:"
file ${KV_CLIENT}
file ${KV_SERVER}
