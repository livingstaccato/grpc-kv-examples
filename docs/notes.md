
## Compatibility Matrix

### macOS 15.2

| ------ | --------- | ------ | --------- | --- | 
| Server | Svr Algo  | Client | Cl Algo   | Fun | 
| ------ | --------- | ------ | --------- | --- | 
| Go     | secp521r1 | Go     | secp521r1 | Yes |
| Go     | secp521r1 | Python | secp521r1 | No  |
| Go     | secp521r1 | Ruby   | secp521r1 | No  |
| Go     | secp521r1 | C#     | secp521r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Go     | secp521r1 | Go     | secp384r1 | Yes |
| Go     | secp521r1 | Python | secp384r1 | No  |
| Go     | secp521r1 | Ruby   | secp384r1 | No  |
| Go     | secp521r1 | C#     | secp384r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Python | secp521r1 | Go     | secp521r1 | No  |
| Python | secp521r1 | Python | secp521r1 | No  |
| Python | secp521r1 | Ruby   | secp521r1 | No  |
| Python | secp521r1 | C#     | secp521r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Python | secp521r1 | Go     | rsa-2048  | Yes |
| Python | secp521r1 | Python | rsa-2048  | No  |
| Python | secp521r1 | Ruby   | rsa-2048  | No  |
| Python | secp521r1 | C#     | rsa-2048  | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Python | secp521r1 | Go     | secp256r1 | Yes |
| Python | secp521r1 | Python | secp256r1 | No  |
| Python | secp521r1 | Ruby   | secp256r1 | No  |
| Python | secp521r1 | C#     | secp256r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Ruby   | secp521r1 | Go     | secp521r1 | No  |
| Ruby   | secp521r1 | Python | secp521r1 | No  |
| Ruby   | secp521r1 | Ruby   | secp521r1 | No  |
| Ruby   | secp521r1 | C#     | secp521r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Ruby   | secp521r1 | Go     | rsa-2048  | Yes |
| Ruby   | secp521r1 | Python | rsa-2048  | No  |
| Ruby   | secp521r1 | Ruby   | rsa-2048  | No  |
| Ruby   | secp521r1 | C#     | rsa-2048  | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Ruby   | secp521r1 | Go     | secp384r1 | Yes |
| Ruby   | secp521r1 | Python | secp384r1 | No  |
| Ruby   | secp521r1 | Ruby   | secp384r1 | No  |
| Ruby   | secp521r1 | C#     | secp384r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Ruby   | secp384r1 | Go     | secp384r1 | Yes |
| Ruby   | secp384r1 | Python | secp384r1 | Yes |
| Ruby   | secp384r1 | Ruby   | secp384r1 | Yes |
| Ruby   | secp384r1 | C#     | secp384r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Ruby   | secp384r1 | Go     | secp521r1 | Yes |
| Ruby   | secp384r1 | Python | secp521r1 | No  |
| Ruby   | secp384r1 | Ruby   | secp521r1 | No  |
| Ruby   | secp384r1 | C#     | secp521r1 | Yes |
|-----------------------------------------------|

--------------------------------------------------------------------------------

## TLS Check

| ------ | --------- | --- | ---------------------------- | --- | 
| Server | Svr Algo  | TLS | Cipher                       | Bit | 
| ------ | --------- | --- | ---------------------------- | --- | 
| Go     | secp521r1 | 1.3 | TLS_AES_128_GCM_SHA256       | 128 |
| Python | secp521r1 | 1.3 | TLS_AES_256_GCM_SHA384       | 256 |
| Ruby   | secp521r1 | 1.3 | TLS_CHACHA20_POLY1305_SHA256 | 256 |
|---------------------------------------------------------------|

ossl-client
go cipher: AEAD-CHACHA20-POLY1305-SHA256
python:    AEAD-CHACHA20-POLY1305-SHA256


# Go gRPC Algos

If I change the order of the algorithms it can/will break things. For instance:

The Go client works. All others break.

CipherSuites: []uint16{
    tls.TLS_CHACHA20_POLY1305_SHA256,
    tls.TLS_AES_256_GCM_SHA384,
    tls.TLS_AES_128_GCM_SHA256,
},



# C#
```
the client has:
    log.Println("⚙️ Configuring TLS... 🔄")
    tlsConfig := &tls.Config{
        Certificates:       []tls.Certificate{clientCert},
        RootCAs:           certPool,
        ServerName:        "localhost",
        MinVersion:        tls.VersionTLS13,
        CurvePreferences: []tls.CurveID{tls.CurveP521, tls.CurveP384, tls.CurveP256},
    }
```

The MinVersion ust be TLS12 for the C# client to work.

If the MinVersion is set to TLS13 it will break the C# client.




