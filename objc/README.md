# Objective-C gRPC KV Client

Objective-C implementation of the gRPC KV client with mTLS support.

## Prerequisites

- macOS 10.15+
- Xcode 12+
- CocoaPods

## Installation

```bash
# Install CocoaPods if not already installed
gem install cocoapods

# Install dependencies
pod install
```

## Building

```bash
# Open the workspace
open KV.xcworkspace

# Or build from command line
xcodebuild -workspace KV.xcworkspace -scheme KVClient
```

## Usage

```bash
# Set up certificates
export PLUGIN_SERVER_CERT="$(cat ../certs/ec-secp384r1-ca.crt)"
export PLUGIN_CLIENT_CERT="$(cat ../certs/ec-secp384r1-mtls-client.crt)"
export PLUGIN_CLIENT_KEY="$(cat ../certs/ec-secp384r1-mtls-client.key)"
export PLUGIN_HOST="localhost"
export PLUGIN_PORT="50051"

# Run the client
./build/KVClient
```

## Notes

- gRPC Objective-C is primarily designed for client-side usage (iOS/macOS apps)
- For server-side functionality, consider Swift with grpc-swift
- The client uses BoringSSL as the TLS backend (same as other gRPC implementations)
