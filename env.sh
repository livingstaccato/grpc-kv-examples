#!/bin/sh

# TODO: Make sure to notify if what is set is what's different than the default.

# Base configuration
BASE_PATH=$(pwd)

local DEFAULT_PLUGIN_HOST="localhost"
local DEFAULT_PLUGIN_PORT="50051"

local DEFAULT_PLUGIN_ALGO="ec-secp256r1"

PLUGIN_HOST=${PLUGIN_HOST:-${DEFAULT_PLUGIN_HOST}}
PLUGIN_PORT=${PLUGIN_PORT:-${DEFAULT_PLUGIN_PORT}}

# TLS algorithm configuration
PLUGIN_ALGO=${PLUGIN_ALGO:-${DEFAULT_PLUGIN_ALGO}}
local PLUGIN_CLIENT_ALGO="${PLUGIN_CLIENT_ALGO:-${PLUGIN_ALGO}}"
local PLUGIN_SERVER_ALGO="${PLUGIN_SERVER_ALGO:-${PLUGIN_ALGO}}"

# Certificate paths
PLUGIN_CLIENT_CERT_FILE="${BASE_PATH}/certs/${PLUGIN_CLIENT_ALGO}-mtls-client.crt"
PLUGIN_CLIENT_KEY_FILE="${BASE_PATH}/certs/${PLUGIN_CLIENT_ALGO}-mtls-client.key"

# Load certificates
if [ ! -f "${PLUGIN_CLIENT_CERT_FILE}" ]; then
    echo "❌ Error: Client certificate not found at ${PLUGIN_CLIENT_CERT_FILE}"
    exit 1
fi

if [ ! -f "${PLUGIN_CLIENT_KEY_FILE}" ]; then
    echo "❌ Error: Client key not found at ${PLUGIN_CLIENT_KEY_FILE}"
    exit 1
fi

PLUGIN_CLIENT_CERT="$(cat ${PLUGIN_CLIENT_CERT_FILE})"
PLUGIN_CLIENT_KEY="$(cat ${PLUGIN_CLIENT_KEY_FILE})"

PLUGIN_SERVER_CERT="$(cat ./certs/${PLUGIN_SERVER_ALGO}-mtls-server.crt)"
PLUGIN_SERVER_KEY="$(cat ./certs/${PLUGIN_SERVER_ALGO}-mtls-server.key)"

# Endpoint configuration
PLUGIN_SERVER_ENDPOINT="tcp:${PLUGIN_HOST}:${PLUGIN_PORT}"
PLUGIN_PYTHON_SERVER_ENDPOINT="${PLUGIN_HOST}:${PLUGIN_PORT}"
PLUGIN_CS_SERVER_ENDPOINT="https://${PLUGIN_HOST}:${PLUGIN_PORT}"

# Path configuration
export PYTHONPATH="${BASE_PATH}/python:${BASE_PATH}:${PYTHONPATH}"

# OpenSSL aliases
alias ossl-client='openssl s_client -connect localhost:50051 \
   -cert <(echo "$PLUGIN_CLIENT_CERT") \
   -key <(echo "$PLUGIN_CLIENT_KEY") \
   -CAfile <(echo "$PLUGIN_SERVER_CERT") \
   -servername localhost'

alias ossl-check-server-cert='openssl crl2pkcs7 \
    -nocrl \
    -certfile <(echo "$PLUGIN_SERVER_CERT") \
    | openssl pkcs7 -print_certs -text -noout'

alias ossl-server='openssl s_server \
    -cert <(echo "$PLUGIN_SERVER_CERT") \
    -key <(echo "$PLUGIN_SERVER_KEY") \
    -accept 50051 \
    -verify_return_error \
    -Verify 2'

# Client/Server aliases with proper directory handling
alias go-client="(cd ${BASE_PATH} && source env.sh && ./go/build/simple-go-client)"
alias go-server="(cd ${BASE_PATH} && source env.sh && ./go/build/simple-go-server)"
alias py-client="(cd ${BASE_PATH} && source env.sh && ./python/simple-py-client.py)"
alias py-server="(cd ${BASE_PATH} && source env.sh && ./python/simple-py-server.py)"
alias rb-client="(cd ${BASE_PATH} && source env.sh && ./ruby/simple-rb-client.rb)"
alias rb-server="(cd ${BASE_PATH} && source env.sh && ./ruby/simple-rb-server.rb)"
alias cs-build="(cd ${BASE_PATH}/csharp && dotnet build)"
alias cs-client="(cd ${BASE_PATH}/csharp && dotnet run)"

# Export all necessary environment variables
export PLUGIN_HOST \
    PLUGIN_PORT \
    PLUGIN_ALGO \
    PLUGIN_CLIENT_CERT \
    PLUGIN_CLIENT_KEY \
    PLUGIN_SERVER_CERT \
    PLUGIN_SERVER_KEY \
    PLUGIN_SERVER_ENDPOINT \
    PLUGIN_PYTHON_SERVER_ENDPOINT \
    PLUGIN_CS_SERVER_ENDPOINT \
    PYTHONPATH

echo ""
echo "🔐 TLS Configuration:"
echo "   • Algorithm: ${PLUGIN_ALGO}"
echo "   • Client Algorithm: ${PLUGIN_CLIENT_ALGO}"
echo "   • Server Algorithm: ${PLUGIN_SERVER_ALGO}"
echo ""
echo "📊 Environment Status:"
echo "   • Client Cert Size: $(echo "$PLUGIN_CLIENT_CERT" | wc -c | tr -d ' ') bytes"
echo "   • Client  Key Size: $(echo "$PLUGIN_CLIENT_KEY" | wc -c | tr -d ' ') bytes"
echo "   • Server Cert Size: $(echo "$PLUGIN_SERVER_CERT" | wc -c | tr -d ' ') bytes"
echo "   • Server  Key Size: $(echo "$PLUGIN_SERVER_KEY" | wc -c | tr -d ' ') bytes"
echo ""
echo "🌐 Network Configuration:"
echo "   • Host: ${PLUGIN_HOST}"
echo "   • Port: ${PLUGIN_PORT}"
echo "   • gRPC Endpoint: ${PLUGIN_SERVER_ENDPOINT}"
echo ""
echo "🚀 Environment setup complete!"
echo ""
