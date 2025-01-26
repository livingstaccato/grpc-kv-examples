#!/bin/bash

# Display the Issuer and Public-Key of all the certificates in the
# `./certs` directory.

echo "Issuers for all certs:"
for i in ./certs/*.crt; do
    openssl x509 -noout -text -in $i | grep -E '(Issuer|Public-Key)'
    echo
done
