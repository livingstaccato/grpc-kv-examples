* Python required_


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



## Verifying OpenSSL Version

```
ruby -ropenssl -e 'puts OpenSSL::OPENSSL_LIBRARY_VERSION'
python -c "import ssl; print(ssl.OPENSSL_VERSION)"
```

>>> from cryptography.hazmat.primitives.asymmetric import ec
... 
... available_curves = ec._CURVE_TYPES
... print(available_curves)
... 
{'prime192v1': <cryptography.hazmat.primitives.asymmetric.ec.SECP192R1 object at 0x1035e34d0>, 'prime256v1': <cryptography.hazmat.primitives.asymmetric.ec.SECP256R1 object at 0x1035e3620>, 'secp192r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP192R1 object at 0x10362df90>, 'secp224r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP224R1 object at 0x1035e3770>, 'secp256r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP256R1 object at 0x10362d590>, 'secp384r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP384R1 object at 0x1035e38c0>, 'secp521r1': <cryptography.hazmat.primitives.asymmetric.ec.SECP521R1 object at 0x1035e3a10>, 'secp256k1': <cryptography.hazmat.primitives.asymmetric.ec.SECP256K1 object at 0x1035e3b60>, 'sect163k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT163K1 object at 0x1035e3cb0>, 'sect233k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT233K1 object at 0x1035e3e00>, 'sect283k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT283K1 object at 0x1036a0050>, 'sect409k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT409K1 object at 0x1036a01a0>, 'sect571k1': <cryptography.hazmat.primitives.asymmetric.ec.SECT571K1 object at 0x1036a02f0>, 'sect163r2': <cryptography.hazmat.primitives.asymmetric.ec.SECT163R2 object at 0x1036a0440>, 'sect233r1': <cryptography.hazmat.primitives.asymmetric.ec.SECT233R1 object at 0x1036a0590>, 'sect283r1': <cryptography.hazmat.primitives.asymmetric.ec.SECT283R1 object at 0x1036a06e0>, 'sect409r1': <cryptography.hazmat.primitives.asymmetric.ec.SECT409R1 object at 0x1036a0830>, 'sect571r1': <cryptography.hazmat.primitives.asymmetric.ec.SECT571R1 object at 0x1036a0980>, 'brainpoolP256r1': <cryptography.hazmat.primitives.asymmetric.ec.BrainpoolP256R1 object at 0x1036a0ad0>, 'brainpoolP384r1': <cryptography.hazmat.primitives.asymmetric.ec.BrainpoolP384R1 object at 0x1036a0c20>, 'brainpoolP512r1': <cryptography.hazmat.primitives.asymmetric.ec.BrainpoolP512R1 object at 0x1036a0d70>}
```

