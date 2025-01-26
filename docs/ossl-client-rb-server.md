# Ruby Server - OpenSSL Connect Output

CONNECTED(00000027)
depth=0 O = ec-secp521r1-mtls-server, CN = localhost
verify error:num=20:unable to get local issuer certificate
verify return:1
depth=0 O = ec-secp521r1-mtls-server, CN = localhost
verify error:num=21:unable to verify the first certificate
verify return:1
8674476608:error:1404B0FB:SSL routines:ST_CONNECT:unknown pkey type:/AppleInternal/Library/BuildRoots/b11baf73-9ee0-11ef-b7b4-7aebe1f78c73/Library/Caches/com.apple.xbs/Sources/libressl/libressl-3.3/ssl/ssl_sigalgs.c:335:
---
Certificate chain
 0 s:/O=ec-secp521r1-mtls-server/CN=localhost
   i:/O=ec-secp521r1-mtls-server/CN=localhost
---
Server certificate
-----BEGIN CERTIFICATE-----
MIICajCCAcugAwIBAgIJAJivlf4gQAAtMAoGCCqGSM49BAMEMDcxITAfBgNVBAoM
GGVjLXNlY3A1MjFyMS1tdGxzLXNlcnZlcjESMBAGA1UEAwwJbG9jYWxob3N0MB4X
DTI1MDEyNjE4MTYwNFoXDTI2MDEyNjE4MTYwNFowNzEhMB8GA1UECgwYZWMtc2Vj
cDUyMXIxLW10bHMtc2VydmVyMRIwEAYDVQQDDAlsb2NhbGhvc3QwgZswEAYHKoZI
zj0CAQYFK4EEACMDgYYABAEmTV80gMDs2tVCKArL0Lh1xez8IgYIle8FiJ6eicYf
YProTgzHb7xiSZ+z8c0TflQJJrVPCbuOwvoZUZdgT3TdLgEKQU3wTrcBjJ0+e07r
oKQLK7HjVtZaT0JAtISCjhBc+S6p5UXOmgiHY2LeeYoihqUMSe4RYINJJWXYzdC9
VX98G6N9MHswDwYDVR0TAQH/BAUwAwEB/zAaBgNVHREEEzARgglsb2NhbGhvc3SH
BH8AAAEwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMBMA4GA1UdDwEB/wQE
AwIDqDAdBgNVHQ4EFgQU7CL7o634kMo2l37s1TmcxWr5aq8wCgYIKoZIzj0EAwQD
gYwAMIGIAkIBzAThYXn846yQaco7R53viUWIxAxdjI6YLdmuAyXoMEgW4tEig4o3
u7kIfs9N+5YSIbiL0o4a+JnpowomZJgBlscCQgHOnn8UOcCrx4Ac4Sbe3xPihAgM
tO6Lww8hSRnlPUI/fcb7zDOuVYg6ePWvIyxyaqNf5TPDGQjNNOpd6uLOpYgvVg==
-----END CERTIFICATE-----
subject=/O=ec-secp521r1-mtls-server/CN=localhost
issuer=/O=ec-secp521r1-mtls-server/CN=localhost
---
No client certificate CA names sent
Server Temp Key: ECDH, P-256, 256 bits
---
SSL handshake has read 1205 bytes and written 737 bytes
---
New, TLSv1/SSLv3, Cipher is AEAD-CHACHA20-POLY1305-SHA256
Server public key is 521 bit
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
SSL-Session:
    Protocol  : TLSv1.3
    Cipher    : AEAD-CHACHA20-POLY1305-SHA256
    Session-ID: 
    Session-ID-ctx: 
    Master-Key: 
    Start Time: 1737919133
    Timeout   : 7200 (sec)
    Verify return code: 21 (unable to verify the first certificate)
---
