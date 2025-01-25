#!/usr/bin/env python3

import ssl
import socket

hostname = "localhost"
port = 50051

context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)


context.load_verify_locations(cafile="certs/ec-secp521r1-mtls-server.crt")

# Restrict ciphers to ECDSA to confirm whether it’s recognized:
# e.g., "ECDHE-ECDSA-AES256-GCM-SHA384" or broader "ECDHE-ECDSA-AES256-SHA384"
# context.set_ciphers("ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256")

with socket.create_connection((hostname, port)) as sock:
    with context.wrap_socket(sock, server_hostname=hostname) as ssock:
        print(ssock.version())
        print("Negotiated cipher:", ssock.cipher())
