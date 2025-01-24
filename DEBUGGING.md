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
