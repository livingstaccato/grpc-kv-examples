# gRPC Client / Server Certificates

## Config

```
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
```

## Client

[I]➜ openssl x509 -in ../certs/ec-secp521r1-mtls-client.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            98:aa:08:d4:de:f9:d3:50
    Signature Algorithm: ecdsa-with-SHA512
        Issuer: O=HashiCorp, CN=localhost
        Validity
            Not Before: Feb  5 23:19:15 2025 GMT
            Not After : Feb  5 23:19:15 2026 GMT
        Subject: O=HashiCorp, CN=localhost
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (521 bit)
                pub:
                    04:00:96:6e:d2:84:9e:17:68:a5:fa:5f:3c:de:e2:
                    28:a1:10:c1:51:52:bf:e3:7b:35:33:18:60:14:33:
                    2e:25:77:b9:81:f1:cd:4a:1b:a8:52:d1:54:2e:f1:
                    6c:19:73:9b:d7:05:7e:c2:9d:0b:5b:ca:5d:dd:d9:
                    11:49:80:86:c4:9c:f4:01:ed:3b:1a:01:3f:7d:8b:
                    e1:e0:59:46:15:5c:dd:89:30:5f:52:9f:b1:9a:05:
                    09:5d:90:28:20:4e:f0:5a:ca:fc:d2:0b:4a:7c:7e:
                    eb:66:66:d4:e6:c0:ab:69:4b:2b:47:d0:c5:4c:f3:
                    e4:89:52:99:ea:5e:49:88:5d:0c:7a:53:c9
                ASN1 OID: secp521r1
                NIST CURVE: P-521
        X509v3 extensions:
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Alternative Name:
                DNS:localhost
            X509v3 Extended Key Usage:
                TLS Web Client Authentication, TLS Web Server Authentication
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Subject Key Identifier:
                E1:01:3D:B3:99:05:7A:EB:81:2B:2F:A0:F2:8A:AF:17:A7:9B:98:12
    Signature Algorithm: ecdsa-with-SHA512
         30:81:88:02:42:00:d1:9a:ce:5d:ba:8d:75:fc:77:45:4e:f4:
         47:04:a9:23:66:7c:37:72:67:99:4c:d2:ff:1e:4f:0d:87:07:
         a8:f0:60:c7:89:be:f5:c9:e8:2f:e6:a8:9d:80:bb:95:3a:19:
         4b:04:1b:ae:5c:f4:b9:9a:f4:0b:41:9d:cc:ac:2d:3d:d4:02:
         42:00:8a:b0:59:6b:de:0f:ca:c1:0c:ff:94:ba:79:6a:06:45:
         85:0c:21:bd:27:1d:34:19:9d:36:4c:a1:05:56:29:f3:f0:1a:
         61:94:1a:ba:a7:a1:a8:3e:05:a2:3b:51:1b:66:44:10:58:46:
         55:28:1e:52:c2:62:cb:b4:76:b4:84:33:cf

## Server

[I]➜ openssl x509 -in ../certs/ec-secp521r1-mtls-server.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            a8:10:af:38:f4:3d:22:1d
    Signature Algorithm: ecdsa-with-SHA512
        Issuer: O=HashiCorp, CN=localhost
        Validity
            Not Before: Feb  5 23:19:15 2025 GMT
            Not After : Feb  5 23:19:15 2026 GMT
        Subject: O=HashiCorp, CN=localhost
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (521 bit)
                pub:
                    04:01:8b:d1:0d:39:a5:41:d4:67:96:c6:48:f9:23:
                    9a:24:af:b8:fe:49:7a:ee:cc:fd:05:5d:5f:ac:c0:
                    7d:d9:5e:03:ac:f6:17:45:bd:5f:87:26:f1:89:0a:
                    27:f9:25:e2:a2:11:ba:14:45:1b:47:12:b6:d4:80:
                    00:00:be:46:6f:f5:d1:00:6e:3c:1f:78:bb:4d:6a:
                    d6:9f:30:3c:35:fa:01:95:36:12:cf:fc:83:e0:a9:
                    3d:52:5d:0c:3d:2a:91:02:6f:cf:38:ce:0c:a1:39:
                    d6:88:f8:9f:8e:f7:43:49:f5:f6:5f:25:48:0f:4d:
                    1c:97:f7:07:62:a1:34:53:2f:93:9b:57:90
                ASN1 OID: secp521r1
                NIST CURVE: P-521
        X509v3 extensions:
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Alternative Name:
                DNS:localhost
            X509v3 Extended Key Usage:
                TLS Web Client Authentication, TLS Web Server Authentication
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Subject Key Identifier:
                B7:0B:26:0E:66:60:A6:2C:7F:65:AC:A4:EE:7E:0E:FB:93:28:F7:73
    Signature Algorithm: ecdsa-with-SHA512
         30:81:88:02:42:01:10:f4:bf:97:63:88:44:20:5c:a1:97:fe:
         f9:80:c4:86:ec:5f:d4:3a:73:99:16:9e:59:0e:8f:45:36:e0:
         de:c7:ba:88:bd:59:92:35:55:f7:d9:20:70:38:67:d0:68:cd:
         c3:50:ab:66:8b:b5:50:7e:dd:69:9c:2f:ca:b3:73:c2:9c:02:
         42:00:98:c7:a6:03:d9:6f:7d:b4:20:80:5c:72:ec:26:bd:a6:
         4b:04:33:8c:48:e0:a8:a7:b0:d4:67:4b:96:43:d0:78:32:c9:
         41:06:ff:08:4f:17:b8:32:f5:85:8d:d2:e8:b2:73:65:fa:f8:
         4b:56:4c:59:c0:e0:e1:ed:ab:96:5a:45:2b
