#!/bin/sh

#ALGO=rsa-
#ALGO=ec-secp256r1- # this works
#ALGO=ec-secp384r1- # this works
ALGO=ec-secp521r1- # this does not with Python 3.13 and Ruby 3.4 on macOS 15.2

export PLUGIN_CLIENT_CERT="$(cat ./certs/${ALGO}mtls-client.crt)"
export PLUGIN_CLIENT_KEY="$(cat ./certs/${ALGO}mtls-client.key)"

export PLUGIN_SERVER_CERT="$(cat ./certs/${ALGO}mtls-server.crt)"
export PLUGIN_SERVER_KEY="$(cat ./certs/${ALGO}mtls-server.key)"

# socat TCP-LISTEN:12345 UNIX-CONNECT:<path to server unix socket>

# openssl s_client -connect localhost:12345 \
#   -cert <(echo "$PLUGIN_CLIENT_CERT") \
#   -key <(echo "$PLUGIN_CLIENT_KEY") \
#   -CAfile <(echo "$PLUGIN_SERVER_CERT") \
#   -servername localhost
