# Simple gRPC Key/Value Client/Server

# Goals

* Clients/Servers work with insecure channels.

* Clients/Servers work with SSL channels.

  * Support the ciphers and curves that are required to support the
    HashiCorp `go-plugin`. Currently, `go-plugin` forces P-521 key. All gRPC
    clients, and servers, must support P-521.

* All Clients, and Servers, except CSharp, across all languages in this repository, are able
  to make Put/Get requests between the different implementationss.

---

# Behavior

When all of the Clients and Servers are using the `secp384r1` curve then cross-
language functionality works.

When the curve is set to `secp521r1` then the only Client and Server that work
are Go-based. All the other languages break.

This is strange considering that the versions of OpenSSL, and the languages
library confirm that they should support `secp521r1`.

---

# System Configuration

* macOS 15.2
* Python 3.13
* Ruby 3.2
* Go 1.23
* .NET 9.0

---

# OpenSSL

## Summary

* The OpenSSL versions are modern, and support the `secp521r1` curve.

* Both Python and Ruby verify that they support the `secp521r1` curve.

## Verifying Certificates

```
openssl req -new \
    -key ec-secp521r1-mtls-client.key \
    -x509 \
    -nodes \
    -days 365 \
    -subj "/CN=test.com" \
\
| openssl x509 -noout -text

```

## Verifying OpenSSL Version

```
$ ruby -ropenssl -e 'puts OpenSSL::OPENSSL_LIBRARY_VERSION'
OpenSSL 3.4.0 22 Oct 2024

$ python -c "import ssl; print(ssl.OPENSSL_VERSION)"
OpenSSL 3.4.0 22 Oct 2024
```

## Fetch Python Curves

```
#!/usr/bin/env python3

import ssl
from cryptography.hazmat.primitives.asymmetric import ec

available_curves = ec._CURVE_TYPES
print(available_curves)

ssl_ctx = ssl.create_default_context()
print(ssl_ctx.get_ciphers())

... 
```

## Fetch Ruby Curves

```
#!/usr/bin/env ruby

require 'openssl'

# Fetch an array of curves. Each element is [name, comment].
curves = OpenSSL::PKey::EC.builtin_curves

# You can just inspect the array:
p curves

# Or print them in a more readable format:
puts "Available EC curves:\n"
curves.each do |(name, comment)|
  puts " - #{name}: #{comment}"
end
```

##

```
openssl crl2pkcs7 -nocrl -certfile <(echo "$PLUGIN_SERVER_CERT") | \
    openssl pkcs7 -print_certs -text -noout

```
---

## Notes


* `simple-go-client` and `simple-go-server` work fine with the mTLS certificates.

* `simple-py-client` and `simple-go-server` do not work.

* I'm testing mTLS.
* The Go Client and Go Server work together.

* All other client servers do not work together with an SSL channel.


* No fucking way. It is the cert compatibility. - this needs to be tested for. this has fucked me for a week. i was fucking intuiting that it might be a collision between the SSL libraries that things are built against.

Ugh. But why didn't it work on my Linux machine?

Hmm.

## `go-plugin`

`mtls.go`:22 is generating a P521 key. So… we can't use anything less. Wonderful.

```
WARNING: All log messages before absl::InitializeLog() is called are written to STDERR
I0000 00:00:1737756226.951856 24696965 ssl_transport_security.cc:1665] Handshake failed with error SSL_ERROR_SSL: error:10000070:SSL routines:OPENSSL_internal:BAD_PACKET_LENGTH: Invalid certificate verification context
I0000 00:00:1737756232.143497 24696963 ssl_transport_security.cc:1665] Handshake failed with error SSL_ERROR_SSL: error:100000c0:SSL routines:OPENSSL_internal:PEER_DID_NOT_RETURN_A_CERTIFICATE: Invalid certificate verification context
^CE0000 00:00:1737756242.547762 24696937 init.cc:232] grpc_wait_for_shutdown_with_timeout() timed out.
```

That might just be me terminating early… it might be a lead.



# each
```
openssl s_client -connect localhost:50051 \
  -cert <(echo "$PLUGIN_CLIENT_CERT") \
  -key <(echo "$PLUGIN_CLIENT_KEY") \
  -CAfile <(echo "$PLUGIN_SERVER_CERT") \
  -servername localhost
```

```
[I]➜ diff go-server.txt py-server.txt| grep -v Time 
13c13
< write W BLOCK
---
> 8674476608:error:1404B0FB:SSL routines:ST_CONNECT:unknown pkey type:/AppleInternal/Library/BuildRoots/b11baf73-9ee0-11ef-b7b4-7aebe1f78c73/Library/Caches/com.apple.xbs/Sources/libressl/libressl-3.3/ssl/ssl_sigalgs.c:335:
39c39
< Server Temp Key: ECDH, X25519, 253 bits
---
> Server Temp Key: ECDH, P-256, 256 bits
41c41
< SSL handshake has read 1143 bytes and written 1171 bytes
---
> SSL handshake has read 1170 bytes and written 737 bytes
55c55
---
```

```
[I]➜ diff py-server.txt rb-server.txt 
41c41
< SSL handshake has read 1170 bytes and written 737 bytes
---
> SSL handshake has read 1116 bytes and written 737 bytes
55c55
<     Start Time: 1737756825
---
>     Start Time: 1737756648
```

No. Fucking. Way. It's the CA FALSE?!@#$?!@#$?

# References

## Output

### Python Curves

```
{'prime192v1': <cryptography.hazmat.primitives.asymmetric.ec.SECP192R1 object at 0x105350050>, 'prime256v1': <cryptography.hazmat.primitives.asymmetric.ec.SECP256R1 object at 0x1053501a0>, 'secp192r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP192R1 object at 0x10527f4d0>, 'secp224r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP224R1 object at 0x1053502f0>, 'secp256r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP256R1 object at 0x10527ead0>, 'secp384r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP384R1 object at 0x105350440>, 'secp521r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP521R1 object at 0x105350590>, 'secp256k1': <cryptography.hazmat.primitives.asymmetric.ec.SECP256K1 object at 0x1053506e0>, 'sect163k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT163K1 object at 0x105350830>, 'sect233k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT233K1 object at 0x105350980>, 'sect283k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT283K1 object at 0x105350ad0>, 'sect409k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT409K1 object at 0x105350c20>, 'sect571k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT571K1 object at 0x105350d70>, 'sect163r2': <cryptography.hazmat.primitives.asymmetric.ec.SECT163R2 object at 0x105350ec0>, 'sect233r1': <cryptography.hazmat.primitives.asymmetric.ec.SECT233R1 object at 0x105351010>, 'sect283r1': <cryptography.hazmat.primitives.asymmetric.ec.SECT283R1 object at 0x105351160>, 'sect409r1': <cryptography.hazmat.primitives.asymmetric.ec.SECT409R1 object at 0x1053512b0>, 'sect571r1': <cryptography.hazmat.primitives.asymmetric.ec.SECT571R1 object at 0x105351400>, 'brainpoolP256r1': <cryptography.hazmat.primitives.asymmetric.ec.BrainpoolP256R1 object at 0x105351550>, 'brainpoolP384r1': <cryptography.hazmat.primitives.asymmetric.ec.BrainpoolP384R1 object at 0x1053516a0>, 'brainpoolP512r1': <cryptography.hazmat.primitives.asymmetric.ec.BrainpoolP512R1 object at 0x1053517f0>}

[{'id': 50336514, 'name': 'TLS_AES_256_GCM_SHA384', 'protocol': 'TLSv1.3', 'description': 'TLS_AES_256_GCM_SHA384         TLSv1.3 Kx=any      Au=any   Enc=AESGCM(256)            Mac=AEAD', 'strength_bits': 256, 'alg_bits': 256, 'aead': True, 'symmetric': 'aes-256-gcm', 'digest': None, 'kea': 'kx-any', 'auth': 'auth-any'}, {'id': 50336515, 'name': 'TLS_CHACHA20_POLY1305_SHA256', 'protocol': 'TLSv1.3', 'description': 'TLS_CHACHA20_POLY1305_SHA256   TLSv1.3 Kx=any      Au=any   Enc=CHACHA20/POLY1305(256) Mac=AEAD', 'strength_bits': 256, 'alg_bits': 256, 'aead': True, 'symmetric': 'chacha20-poly1305', 'digest': None, 'kea': 'kx-any', 'auth': 'auth-any'}, {'id': 50336513, 'name': 'TLS_AES_128_GCM_SHA256', 'protocol': 'TLSv1.3', 'description': 'TLS_AES_128_GCM_SHA256         TLSv1.3 Kx=any      Au=any   Enc=AESGCM(128)            Mac=AEAD', 'strength_bits': 128, 'alg_bits': 128, 'aead': True, 'symmetric': 'aes-128-gcm', 'digest': None, 'kea': 'kx-any', 'auth': 'auth-any'}, {'id': 50380844, 'name': 'ECDHE-ECDSA-AES256-GCM-SHA384', 'protocol': 'TLSv1.2', 'description': 'ECDHE-ECDSA-AES256-GCM-SHA384  TLSv1.2 Kx=ECDH     Au=ECDSA Enc=AESGCM(256)            Mac=AEAD', 'strength_bits': 256, 'alg_bits': 256, 'aead': True, 'symmetric': 'aes-256-gcm', 'digest': None, 'kea': 'kx-ecdhe', 'auth': 'auth-ecdsa'}, {'id': 50380848, 'name': 'ECDHE-RSA-AES256-GCM-SHA384', 'protocol': 'TLSv1.2', 'description': 'ECDHE-RSA-AES256-GCM-SHA384    TLSv1.2 Kx=ECDH     Au=RSA   Enc=AESGCM(256)            Mac=AEAD', 'strength_bits': 256, 'alg_bits': 256, 'aead': True, 'symmetric': 'aes-256-gcm', 'digest': None, 'kea': 'kx-ecdhe', 'auth': 'auth-rsa'}, {'id': 50380843, 'name': 'ECDHE-ECDSA-AES128-GCM-SHA256', 'protocol': 'TLSv1.2', 'description': 'ECDHE-ECDSA-AES128-GCM-SHA256  TLSv1.2 Kx=ECDH     Au=ECDSA Enc=AESGCM(128)            Mac=AEAD', 'strength_bits': 128, 'alg_bits': 128, 'aead': True, 'symmetric': 'aes-128-gcm', 'digest': None, 'kea': 'kx-ecdhe', 'auth': 'auth-ecdsa'}, {'id': 50380847, 'name': 'ECDHE-RSA-AES128-GCM-SHA256', 'protocol': 'TLSv1.2', 'description': 'ECDHE-RSA-AES128-GCM-SHA256    TLSv1.2 Kx=ECDH     Au=RSA   Enc=AESGCM(128)            Mac=AEAD', 'strength_bits': 128, 'alg_bits': 128, 'aead': True, 'symmetric': 'aes-128-gcm', 'digest': None, 'kea': 'kx-ecdhe', 'auth': 'auth-rsa'}, {'id': 50384041, 'name': 'ECDHE-ECDSA-CHACHA20-POLY1305', 'protocol': 'TLSv1.2', 'description': 'ECDHE-ECDSA-CHACHA20-POLY1305  TLSv1.2 Kx=ECDH     Au=ECDSA Enc=CHACHA20/POLY1305(256) Mac=AEAD', 'strength_bits': 256, 'alg_bits': 256, 'aead': True, 'symmetric': 'chacha20-poly1305', 'digest': None, 'kea': 'kx-ecdhe', 'auth': 'auth-ecdsa'}, {'id': 50384040, 'name': 'ECDHE-RSA-CHACHA20-POLY1305', 'protocol': 'TLSv1.2', 'description': 'ECDHE-RSA-CHACHA20-POLY1305    TLSv1.2 Kx=ECDH     Au=RSA   Enc=CHACHA20/POLY1305(256) Mac=AEAD', 'strength_bits': 256, 'alg_bits': 256, 'aead': True, 'symmetric': 'chacha20-poly1305', 'digest': None, 'kea': 'kx-ecdhe', 'auth': 'auth-rsa'}, {'id': 50380836, 'name': 'ECDHE-ECDSA-AES256-SHA384', 'protocol': 'TLSv1.2', 'description': 'ECDHE-ECDSA-AES256-SHA384      TLSv1.2 Kx=ECDH     Au=ECDSA Enc=AES(256)               Mac=SHA384', 'strength_bits': 256, 'alg_bits': 256, 'aead': False, 'symmetric': 'aes-256-cbc', 'digest': 'sha384', 'kea': 'kx-ecdhe', 'auth': 'auth-ecdsa'}, {'id': 50380840, 'name': 'ECDHE-RSA-AES256-SHA384', 'protocol': 'TLSv1.2', 'description': 'ECDHE-RSA-AES256-SHA384        TLSv1.2 Kx=ECDH     Au=RSA   Enc=AES(256)               Mac=SHA384', 'strength_bits': 256, 'alg_bits': 256, 'aead': False, 'symmetric': 'aes-256-cbc', 'digest': 'sha384', 'kea': 'kx-ecdhe', 'auth': 'auth-rsa'}, {'id': 50380835, 'name': 'ECDHE-ECDSA-AES128-SHA256', 'protocol': 'TLSv1.2', 'description': 'ECDHE-ECDSA-AES128-SHA256      TLSv1.2 Kx=ECDH     Au=ECDSA Enc=AES(128)               Mac=SHA256', 'strength_bits': 128, 'alg_bits': 128, 'aead': False, 'symmetric': 'aes-128-cbc', 'digest': 'sha256', 'kea': 'kx-ecdhe', 'auth': 'auth-ecdsa'}, {'id': 50380839, 'name': 'ECDHE-RSA-AES128-SHA256', 'protocol': 'TLSv1.2', 'description': 'ECDHE-RSA-AES128-SHA256        TLSv1.2 Kx=ECDH     Au=RSA   Enc=AES(128)               Mac=SHA256', 'strength_bits': 128, 'alg_bits': 128, 'aead': False, 'symmetric': 'aes-128-cbc', 'digest': 'sha256', 'kea': 'kx-ecdhe', 'auth': 'auth-rsa'}, {'id': 50331807, 'name': 'DHE-RSA-AES256-GCM-SHA384', 'protocol': 'TLSv1.2', 'description': 'DHE-RSA-AES256-GCM-SHA384      TLSv1.2 Kx=DH       Au=RSA   Enc=AESGCM(256)            Mac=AEAD', 'strength_bits': 256, 'alg_bits': 256, 'aead': True, 'symmetric': 'aes-256-gcm', 'digest': None, 'kea': 'kx-dhe', 'auth': 'auth-rsa'}, {'id': 50331806, 'name': 'DHE-RSA-AES128-GCM-SHA256', 'protocol': 'TLSv1.2', 'description': 'DHE-RSA-AES128-GCM-SHA256      TLSv1.2 Kx=DH       Au=RSA   Enc=AESGCM(128)            Mac=AEAD', 'strength_bits': 128, 'alg_bits': 128, 'aead': True, 'symmetric': 'aes-128-gcm', 'digest': None, 'kea': 'kx-dhe', 'auth': 'auth-rsa'}, {'id': 50331755, 'name': 'DHE-RSA-AES256-SHA256', 'protocol': 'TLSv1.2', 'description': 'DHE-RSA-AES256-SHA256          TLSv1.2 Kx=DH       Au=RSA   Enc=AES(256)               Mac=SHA256', 'strength_bits': 256, 'alg_bits': 256, 'aead': False, 'symmetric': 'aes-256-cbc', 'digest': 'sha256', 'kea': 'kx-dhe', 'auth': 'auth-rsa'}, {'id': 50331751, 'name': 'DHE-RSA-AES128-SHA256', 'protocol': 'TLSv1.2', 'description': 'DHE-RSA-AES128-SHA256          TLSv1.2 Kx=DH       Au=RSA   Enc=AES(128)               Mac=SHA256', 'strength_bits': 128, 'alg_bits': 128, 'aead': False, 'symmetric': 'aes-128-cbc', 'digest': 'sha256', 'kea': 'kx-dhe', 'auth': 'auth-rsa'}]
```

---

### Ruby Curves

```
[["secp112r1", "SECG/WTLS curve over a 112 bit prime field"], ["secp112r2", "SECG curve over a 112 bit prime field"], ["secp128r1", "SECG curve over a 128 bit prime field"], ["secp128r2", "SECG curve over a 128 bit prime field"], ["secp160k1", "SECG curve over a 160 bit prime field"], ["secp160r1", "SECG curve over a 160 bit prime field"], ["secp160r2", "SECG/WTLS curve over a 160 bit prime field"], ["secp192k1", "SECG curve over a 192 bit prime field"], ["secp224k1", "SECG curve over a 224 bit prime field"], ["secp224r1", "NIST/SECG curve over a 224 bit prime field"], ["secp256k1", "SECG curve over a 256 bit prime field"], ["secp384r1", "NIST/SECG curve over a 384 bit prime field"], ["secp521r1", "NIST/SECG curve over a 521 bit prime field"], ["prime192v1", "NIST/X9.62/SECG curve over a 192 bit prime field"], ["prime192v2", "X9.62 curve over a 192 bit prime field"], ["prime192v3", "X9.62 curve over a 192 bit prime field"], ["prime239v1", "X9.62 curve over a 239 bit prime field"], ["prime239v2", "X9.62 curve over a 239 bit prime field"], ["prime239v3", "X9.62 curve over a 239 bit prime field"], ["prime256v1", "X9.62/SECG curve over a 256 bit prime field"], ["sect113r1", "SECG curve over a 113 bit binary field"], ["sect113r2", "SECG curve over a 113 bit binary field"], ["sect131r1", "SECG/WTLS curve over a 131 bit binary field"], ["sect131r2", "SECG curve over a 131 bit binary field"], ["sect163k1", "NIST/SECG/WTLS curve over a 163 bit binary field"], ["sect163r1", "SECG curve over a 163 bit binary field"], ["sect163r2", "NIST/SECG curve over a 163 bit binary field"], ["sect193r1", "SECG curve over a 193 bit binary field"], ["sect193r2", "SECG curve over a 193 bit binary field"], ["sect233k1", "NIST/SECG/WTLS curve over a 233 bit binary field"], ["sect233r1", "NIST/SECG/WTLS curve over a 233 bit binary field"], ["sect239k1", "SECG curve over a 239 bit binary field"], ["sect283k1", "NIST/SECG curve over a 283 bit binary field"], ["sect283r1", "NIST/SECG curve over a 283 bit binary field"], ["sect409k1", "NIST/SECG curve over a 409 bit binary field"], ["sect409r1", "NIST/SECG curve over a 409 bit binary field"], ["sect571k1", "NIST/SECG curve over a 571 bit binary field"], ["sect571r1", "NIST/SECG curve over a 571 bit binary field"], ["c2pnb163v1", "X9.62 curve over a 163 bit binary field"], ["c2pnb163v2", "X9.62 curve over a 163 bit binary field"], ["c2pnb163v3", "X9.62 curve over a 163 bit binary field"], ["c2pnb176v1", "X9.62 curve over a 176 bit binary field"], ["c2tnb191v1", "X9.62 curve over a 191 bit binary field"], ["c2tnb191v2", "X9.62 curve over a 191 bit binary field"], ["c2tnb191v3", "X9.62 curve over a 191 bit binary field"], ["c2pnb208w1", "X9.62 curve over a 208 bit binary field"], ["c2tnb239v1", "X9.62 curve over a 239 bit binary field"], ["c2tnb239v2", "X9.62 curve over a 239 bit binary field"], ["c2tnb239v3", "X9.62 curve over a 239 bit binary field"], ["c2pnb272w1", "X9.62 curve over a 272 bit binary field"], ["c2pnb304w1", "X9.62 curve over a 304 bit binary field"], ["c2tnb359v1", "X9.62 curve over a 359 bit binary field"], ["c2pnb368w1", "X9.62 curve over a 368 bit binary field"], ["c2tnb431r1", "X9.62 curve over a 431 bit binary field"], ["wap-wsg-idm-ecid-wtls1", "WTLS curve over a 113 bit binary field"], ["wap-wsg-idm-ecid-wtls3", "NIST/SECG/WTLS curve over a 163 bit binary field"], ["wap-wsg-idm-ecid-wtls4", "SECG curve over a 113 bit binary field"], ["wap-wsg-idm-ecid-wtls5", "X9.62 curve over a 163 bit binary field"], ["wap-wsg-idm-ecid-wtls6", "SECG/WTLS curve over a 112 bit prime field"], ["wap-wsg-idm-ecid-wtls7", "SECG/WTLS curve over a 160 bit prime field"], ["wap-wsg-idm-ecid-wtls8", "WTLS curve over a 112 bit prime field"], ["wap-wsg-idm-ecid-wtls9", "WTLS curve over a 160 bit prime field"], ["wap-wsg-idm-ecid-wtls10", "NIST/SECG/WTLS curve over a 233 bit binary field"], ["wap-wsg-idm-ecid-wtls11", "NIST/SECG/WTLS curve over a 233 bit binary field"], ["wap-wsg-idm-ecid-wtls12", "WTLS curve over a 224 bit prime field"], ["Oakley-EC2N-3", "\n\tIPSec/IKE/Oakley curve #3 over a 155 bit binary field.\n\tNot suitable for ECDSA.\n\tQuestionable extension field!"], ["Oakley-EC2N-4", "\n\tIPSec/IKE/Oakley curve #4 over a 185 bit binary field.\n\tNot suitable for ECDSA.\n\tQuestionable extension field!"], ["brainpoolP160r1", "RFC 5639 curve over a 160 bit prime field"], ["brainpoolP160t1", "RFC 5639 curve over a 160 bit prime field"], ["brainpoolP192r1", "RFC 5639 curve over a 192 bit prime field"], ["brainpoolP192t1", "RFC 5639 curve over a 192 bit prime field"], ["brainpoolP224r1", "RFC 5639 curve over a 224 bit prime field"], ["brainpoolP224t1", "RFC 5639 curve over a 224 bit prime field"], ["brainpoolP256r1", "RFC 5639 curve over a 256 bit prime field"], ["brainpoolP256t1", "RFC 5639 curve over a 256 bit prime field"], ["brainpoolP320r1", "RFC 5639 curve over a 320 bit prime field"], ["brainpoolP320t1", "RFC 5639 curve over a 320 bit prime field"], ["brainpoolP384r1", "RFC 5639 curve over a 384 bit prime field"], ["brainpoolP384t1", "RFC 5639 curve over a 384 bit prime field"], ["brainpoolP512r1", "RFC 5639 curve over a 512 bit prime field"], ["brainpoolP512t1", "RFC 5639 curve over a 512 bit prime field"], ["SM2", "SM2 curve over a 256 bit prime field"]]
```

# Ideas

* Include a max retry/request before server exit? i.e. exit after one request.

# gRPC Implementation

[gRPC PHP README](https://github.com/grpc/grpc/blob/master/src/php/README.md)


# Security

https://security.stackexchange.com/questions/100991/why-is-secp521r1-no-longer-supported-in-chrome-others
