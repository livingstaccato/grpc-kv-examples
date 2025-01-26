#!/bin/bash

# Variables
CERT_DIR="./certs"

DAYS=365

# RSA_BITS=2048
ECDSA_CURVE="secp521r1"
ECDSA_CURVE="secp384r1"
ECDSA_CURVE="secp256r1"

# Create certificate directory
mkdir -p "$CERT_DIR"

# Function to generate certificate
generate_certificate() {
    local name=$1
    local cn=$2
    local san=$3
    local org=$4
    local algo=$5

    echo "Generating certificate for $name"

    # Create OpenSSL configuration for SAN
    cat >"$CERT_DIR/$name.cnf" <<EOF
[req]
default_bits        = $RSA_BITS
distinguished_name  = req_distinguished_name
req_extensions      = req_ext
x509_extensions     = v3_ext
prompt              = no

[req_distinguished_name]
O  = $org
CN = $cn

[req_ext]
subjectAltName = @alt_names

[v3_ext]
basicConstraints = critical, CA:TRUE
subjectAltName = @alt_names
extendedKeyUsage = TLS Web Client Authentication, TLS Web Server Authentication
keyUsage = critical, Digital Signature, Key Encipherment, Key Agreement
subjectKeyIdentifier = hash

[alt_names]
DNS.1 = $cn
IP.1  = 127.0.0.1
EOF

    key_file="$CERT_DIR/$name.key"

    if [[ $algo == "rsa" ]]; then
        openssl genrsa -out "$key_file" $RSA_BITS
    elif [[ $algo == "ecdsa" ]]; then
        openssl ecparam -name $ECDSA_CURVE -genkey -noout -out "$key_file"
    else
        echo "Unsupported algorithm: $algo"
        exit 1
    fi

    # Generate certificate signing request (CSR) and self-signed certificate
    openssl req -x509 -new -nodes \
        -key "$CERT_DIR/$name.key" \
        -sha512 \
        -days $DAYS \
        -config "$CERT_DIR/$name.cnf" \
        -out "$CERT_DIR/$name.crt"

    echo "Certificate for $name generated at $CERT_DIR/$name.crt"
}

# Generate certificates
if [ -n "${RSA_BITS}" ]; then
    _cert_name="rsa-${RSA_BITS}-mtls-client"
    echo "Creating "${_cert_name} certificates..."
    generate_certificate "rsa-${RSA_BITS}-mtls-client" "localhost" "localhost,127.0.0.1" "rsa-${RSA_BITS}-mtls-client" "rsa"
    generate_certificate "rsa-${RSA_BITS}-mtls-server" "localhost" "localhost,127.0.0.1" "rsa-${RSA_BITS}-mtls-server" "rsa"
    echo "Done creating certificates."
fi

if [ -n "${ECDSA_CURVE}" ]; then
generate_certificate "ec-${ECDSA_CURVE}-mtls-client" "localhost" "localhost,127.0.0.1" "ec-${ECDSA_CURVE}-mtls-client" "ecdsa"
generate_certificate "ec-${ECDSA_CURVE}-mtls-server" "localhost" "localhost,127.0.0.1" "ec-${ECDSA_CURVE}-mtls-server" "ecdsa"
fi

echo "All certificates generated successfully in $CERT_DIR."
