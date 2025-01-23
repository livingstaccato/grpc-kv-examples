#!/bin/bash

# Variables
CERT_DIR="./certs"
DAYS=365
RSA_BITS=2048

# Create certificate directory
mkdir -p "$CERT_DIR"

# Function to generate certificate
generate_certificate() {
    local name=$1
    local cn=$2
    local san=$3
    local org=$4

    echo "Generating certificate for $name"

    # Create OpenSSL configuration for SAN
    cat >"$CERT_DIR/$name.cnf" <<EOF
[req]
default_bits        = $RSA_BITS
distinguished_name  = req_distinguished_name
req_extensions      = req_ext
x509_extensions     = v3_ca
prompt              = no

[req_distinguished_name]
O  = $org
CN = $cn

[req_ext]
subjectAltName = @alt_names

[v3_ca]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $cn
IP.1  = 127.0.0.1
EOF

    # Generate private key
    openssl genrsa -out "$CERT_DIR/$name.key" $RSA_BITS

    # Generate certificate signing request (CSR) and self-signed certificate
    openssl req -x509 -new -nodes \
        -key "$CERT_DIR/$name.key" \
        -sha256 \
        -days $DAYS \
        -config "$CERT_DIR/$name.cnf" \
        -out "$CERT_DIR/$name.crt"

    echo "Certificate for $name generated at $CERT_DIR/$name.crt"
}

# Generate certificates
generate_certificate "rsa-mtls-client" "localhost" "localhost,127.0.0.1" "rsa-mtls-client"
generate_certificate "rsa-mtls-server" "localhost" "localhost,127.0.0.1" "rsa-mtls-server"

echo "All certificates generated successfully in $CERT_DIR."
