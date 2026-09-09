#!/bin/bash
#
# Injects the patched Python/C++/Ruby artifacts (built by build-patched-grpc.sh
# from livingstaccato/grpc@feature/ec-curve-fix, i.e. grpc/grpc#42086) into a
# fresh container and runs the full test-all-curves.sh matrix: all 9 languages
# x all 3 curves (P-256/P-384/P-521), with --patched so real failures are
# reported as FAIL rather than the unpatched-baseline EXPECTED_FAIL.
#
# Ruby is optional (matches build-ruby's continue-on-error in the workflow):
# if its artifact wasn't produced, Ruby runs against the unpatched system gem
# and will legitimately FAIL P-384/P-521 rather than being skipped.
set -euo pipefail

CONTAINER=full-compat-container

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
docker exec "$CONTAINER" chmod +x /workspace/build/patched-grpc/install/bin/*

docker exec "$CONTAINER" bash -c '
    set -e
    cd /workspace
    source ./utils/grpc-environment-manager.sh activate python
    source ./utils/grpc-environment-manager.sh activate cpp
    if [ -d build/patched-grpc/ruby-gems ]; then
        source ./utils/grpc-environment-manager.sh activate ruby
    fi

    # test-all-curves.sh swallows build_cmd output even under --verbose, so
    # build these directly first to surface real errors for BUILD_FAILED cases.
    echo "=== DIAGNOSTIC: C++ build ==="
    (cd cpp && ./build.sh) || echo "=== C++ build FAILED (see above) ==="
    echo "=== DIAGNOSTIC: Java build ==="
    (cd java && gradle build) || echo "=== Java build FAILED (see above) ==="
    echo "=== DIAGNOSTIC: Dart build ==="
    (cd dart && dart pub get) || echo "=== Dart build FAILED (see above) ==="

    ./test-all-curves.sh --patched --verbose
' 2>&1 | tee full-compat-container.log

docker cp "$CONTAINER":/workspace/curve-test-results.txt ./curve-test-results.txt
