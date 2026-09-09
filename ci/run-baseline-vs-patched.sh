#!/bin/bash
#
# Injects the patched Python/C++/Ruby artifacts into a fresh container and
# runs compare-grpc-versions.sh (baseline vs patched) for python/ruby/cpp,
# producing the comparison report and per-language logs.
set -euo pipefail

CONTAINER=proof-container

cleanup() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --name "$CONTAINER" -d -t grpc-curve-test:latest

docker exec "$CONTAINER" mkdir -p /workspace/build/patched-grpc
docker cp build/patched-grpc/python-site "$CONTAINER":/workspace/build/patched-grpc/
docker cp build/patched-grpc/install "$CONTAINER":/workspace/build/patched-grpc/
if [ -d "build/patched-grpc/ruby-gems" ]; then
    docker cp build/patched-grpc/ruby-gems "$CONTAINER":/workspace/build/patched-grpc/
fi

# actions/upload-artifact + download-artifact round-trips through a zip that
# doesn't reliably preserve the Unix execute bit, so protoc/grpc_cpp_plugin
# arrive non-executable even though the build step produced them correctly.
# The glob must expand inside the container, not on the runner's host shell.
docker exec "$CONTAINER" sh -c 'chmod +x /workspace/build/patched-grpc/install/bin/*'

docker exec "$CONTAINER" ./compare-grpc-versions.sh --language all --skip-build

docker cp "$CONTAINER":/workspace/reports . || true
docker cp "$CONTAINER":/workspace/results . || true
