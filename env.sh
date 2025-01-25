#!/bin/sh

BASE_PATH=$(pwd)

DEFAULT_PLUGIN_HOST="localhost"
DEFAULT_PLUGIN_PORT="50051"

PLUGIN_HOST=${PLUGIN_HOST:-${DEFAULT_PLUGIN_HOST}}
PLUGIN_PORT=${PLUGIN_PORT:-${DEFAULT_PLUGIN_PORT}}

#
# Algorithms verified to work:
#    rsa, ec-secp2561, ec-secp384r1
#
# Algorithms not working:
#     ec-secp521r1
#
PLUGIN_ALGO=${PLUGIN_ALGO:-"ec-secp256r1"}

PLUGIN_CLIENT_ALGO="${PLUGIN_CLIENT_ALGO:-${PLUGIN_ALGO}}"

PLUGIN_CLIENT_CERT_FILE="${BASE_PATH}/certs/${PLUGIN_CLIENT_ALGO}-mtls-client.crt)"
PLUGIN_CLIENT_CERT="$(cat ${PLUGIN_CLIENT_CERT_FILE})"

PLUGIN_CLIENT_KEY_FILE="$(cat ${BASE_PATH}/certs/${PLUGIN_CLIENT_ALGO}-mtls-client.key)"
PLUGIN_CLIENT_KEY="$(cat ${PLUGIN_CLIENT_KEY_FILE})"

PLUGIN_SERVER_ALGO="${PLUGIN_SERVER_ALGO:-${PLUGIN_ALGO}}"
PLUGIN_SERVER_CERT="$(cat ./certs/${PLUGIN_SERVER_ALGO}-mtls-server.crt)"
PLUGIN_SERVER_KEY="$(cat ./certs/${PLUGIN_SERVER_ALGO}-mtls-server.key)"

PLUGIN_SERVER_ENDPOINT="tcp:${PLUGIN_HOST}:${PLUGIN_POST}"
PLUGIN_SERVER_ENDPOINT_PYTHON="${PLUGIN_HOST}:${PLUGIN_PORT}"
PLUGIN_SERVER_ENDPOINT_CLIENT="https://${PLUGIN_HOST}:${PLUGIN_PORT}"

# socat TCP-LISTEN:12345 UNIX-CONNECT:<path to server unix socket>

export PYTHONPATH="${BASE_PATH}/python:${BASE_PATH}:${PYTHONPATH}"

alias ossl-client='openssl s_client -connect localhost:50051 \
   -cert <(echo "$PLUGIN_CLIENT_CERT") \
   -key <(echo "$PLUGIN_CLIENT_KEY") \
   -CAfile <(echo "$PLUGIN_SERVER_CERT") \
   -servername localhost
'

alias ossl-check-server-cert='openssl crl2pkcs7 \
    -nocrl \
    -certfile <(echo "$PLUGIN_SERVER_CERT") \
    | openssl pkcs7 -print_certs -text -noout
'

alias ossl-server='openssl s_server \
    -cert <(echo "$PLUGIN_SERVER_CERT") \
    -key <(echo "$PLUGIN_SERVER_KEY") \
    -accept 50051 \
    -verify_return_error \
    -Verify 2
'

# socat TCP-LISTEN:12345 UNIX-CONNECT:<path to server unix socket>

alias go-client="(${BASE_PATH}; source env.sh; ./go/build/simple-go-client)"
alias go-server="(${BASE_PATH}; source env.sh; ./go/build/simple-go-server)"

alias py-client="(cd ${BASE_PATH}; source env.sh; ./python/simple-py-client.py)"
alias py-server="(cd ${BASE_PATH}; source env.sh; ./python/simple-py-server.py)"

alias rb-client="(cd ${BASE_PATH}; source env.sh; ./ruby/simple-rb-client.rb)"
alias rb-server="(cd ${BASE_PATH}; source env.sh; ./ruby/simple-rb-server.rb)"

alias cs-build="(cd ${BASE_PATH}; source env.sh; cd ./csharp; dotnet build)"
alias cs-client="(cd ${BASE_PATH}; source env.sh; cd ./csharp; dotnet run)"

export PLUGIN_HOST \
    PLUGIN_PORT \
    PLUGIN_ALGO \
    \
    PLUGIN_CLIENT_ALGO \
    PLUGIN_CLIENT_CERT \
    PLUGIN_CLIENT_KEY \
    \
    PLUGIN_SERVER_ALGO \
    PLUGIN_SERVER_CERT \
    PLUGIN_SERVER_KEY \
    PLUGIN_SERVER_ENDPOINT \
    PLUGIN_PYTHON_SERVER_ENDPOINT \
    PLUGIN_CS_SERVER_ENDPOINT
###

export PYTHONPATH

cat <<EOF
PLUGIN_ALGO=${PLUGIN_ALGO}

PLUGIN_CLIENT_ALGO = ${PLUGIN_CLIENT_ALGO}
PLUGIN_CLIENT_CERT = "$(wc -c ${PLUGIN_CLIENT_CERT})"
PLUGIN_CLIENT_KEY  = "$(wc -c ${PLUGIN_CLIENT_KEY})"

PLUGIN_SERVER_ALGO="${PLUGIN_SERVER_ALGO:-${PLUGIN_ALGO}}"
PLUGIN_SERVER_CERT="$(cat ./certs/${PLUGIN_SERVER_ALGO}-mtls-server.crt)"
PLUGIN_SERVER_KEY="$(cat ./certs/${PLUGIN_SERVER_ALGO}-mtls-server.key)"

PLUGIN_SERVER_ENDPOINT="tcp:${PLUGIN_HOST}:${PLUGIN_POST}"
PLUGIN_SERVER_ENDPOINT_PYTHON="${PLUGIN_HOST}:${PLUGIN_PORT}"
PLUGIN_SERVER_ENDPOINT_CLIENT="https://${PLUGIN_HOST}:${PLUGIN_PORT}"
EOF

echo "gRPC Endpoint: ${PLUGIN_HOST}"
echo "gRPC Port: ${PLUGIN_PORT}"
echo "🔑 Using ${ALGO}"
echo "✅ Setup the environment."
