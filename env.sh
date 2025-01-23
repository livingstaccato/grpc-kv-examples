#!/bin/sh

export PLUGIN_CLIENT_CERT="$(cat ./certs/mtls-client.pem)"
export PLUGIN_CLIENT_KEY="$(cat ./certs/mtls-client.key)"
export PLUGIN_SERVER_CERT="$(cat ./certs/mtls-server.pem)"
export PLUGIN_SERVER_KEY="$(cat ./certs/mtls-server.key)"

# socat TCP-LISTEN:12345 UNIX-CONNECT:<path to server unix socket>

# openssl s_client -connect localhost:12345 \
#   -cert <(echo "$PLUGIN_CLIENT_CERT") \
#   -key <(echo "$PLUGIN_CLIENT_KEY") \
#   -CAfile <(echo "$PLUGIN_SERVER_CERT") \
#   -servername localhost
