#!/bin/bash

# Display the Issuer and Public-Key of all the certificates in the
# `./certs` directory.

echo "Issuers for all certs:"
for cert_file in certs/*.crt; do
    echo "  * ${cert_file}"
    openssl x509 -noout -text -in ${cert_file} | grep -E '(Issuer|Public-Key)'
    echo
done
