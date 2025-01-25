#!/bin/sh

BASE_PATH=$(pwd)

ALGO=${ALGO:-"secp256r1"}

# ALGO=rsa-          # this works
# ALGO=ec-secp256r1- # this works
# ALGO=ec-secp384r1- # this works
# ALGO=ec-secp521r1- # this does not on Python 3.13 and Ruby 3.4 on macOS 15.2

export PLUGIN_HOST="localhost"
export PLUGIN_PORT="50051"

export PLUGIN_SERVER_ENDPOINT="tcp:${PLUGIN_HOST}:${PLUGIN_POST}"
export PLUGIN_PYTHON_SERVER_ENDPOINT="${PLUGIN_HOST}:${PLUGIN_PORT}"
export PLUGIN_CS_SERVER_ENDPOINT="https://${PLUGIN_HOST}:${PLUGIN_PORT}"

export PLUGIN_CLIENT_CERT="$(cat ./certs/${ALGO}mtls-client.crt)"
export PLUGIN_CLIENT_KEY="$(cat ./certs/${ALGO}mtls-client.key)"

export PLUGIN_SERVER_CERT="$(cat ./certs/${ALGO}mtls-server.crt)"
export PLUGIN_SERVER_KEY="$(cat ./certs/${ALGO}mtls-server.key)"

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
    PLUGIN_SERVER_ENDPOINT \
    PLUGIN_PYTHON_SERVER_ENDPOINT \
    PLUGIN_CS_SERVER_ENDPOINT \
    PLUGIN_CLIENT_CERT \
    PLUGIN_CLIENT_KEY \
    PLUGIN_SERVER_CERT \
    PLUGIN_SERVER_KEY

export PYTHONPATH

echo "🔑 Using ${ALGO}"
echo "✅ Setup the environment."
