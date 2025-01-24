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
