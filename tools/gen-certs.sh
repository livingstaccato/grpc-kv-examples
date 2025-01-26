#!/bin/bash

# Variables
CERT_DIR="./certs"

DAYS=365

# RSA_BITS=2048
# ECDSA_CURVE="secp521r1"
ECDSA_CURVE="secp384r1"
# ECDSA_CURVE="secp256r1"

# Create certificate directory
mkdir -p "$CERT_DIR"

# Function to generate certificate
generate_certificate() {
    local name=$1
    local org=$2
    local cn=$3
    local san=$4
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
    echo "====================================================================="
    echo "*** Client RSA Cert ***"
    echo "====================================================================="
    _cert_name="rsa-${RSA_BITS}-mtls"

    generate_certificate "${_cert_name}-client" \
        "${_cert_name}-client" \
        "localhost" \
        "localhost,127.0.0.1" \
        "rsa"

    echo
    echo "====================================================================="
    echo "*** Server RSA Cert ***"
    echo "====================================================================="
    generate_certificate "${_cert_name}-server" \
        "${_cert_name}-server" \
        "localhost" \
        "localhost,127.0.0.1" \
        "rsa"
    echo
    echo "====================================================================="
fi

if [ -n "${ECDSA_CURVE}" ]; then
    _cert_name="ec-${ECDSA_CURVE}-mtls"

    echo
    echo "====================================================================="
    echo "*** Client Cert ***"
    echo "====================================================================="
    generate_certificate "${_cert_name}-client" \
        "${_cert_name}-client" \
        "localhost" \
        "localhost,127.0.0.1" \
        "ecdsa"

    echo
    echo "====================================================================="
    echo "*** Server RSA Cert ***"
    echo "====================================================================="
    generate_certificate "${_cert_name}-server" \
        "${_cert_name}-server" \
        "localhost" \
        "localhost,127.0.0.1" \
        "ecdsa"
    echo
    echo
fi

echo "All certificates generated in ${CERT_DIR}."

echo "Issuers for all certs:"
for i in certs/*.crt; do
    openssl x509 -noout -text -in $i | grep -e '(Issuer|Public-Key)'
    echo
done
