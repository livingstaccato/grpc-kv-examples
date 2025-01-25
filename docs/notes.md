
/Users/tim.perkins/code/opensource/grpc/test/core/network_benchmarks/low_level_ping_pong.cc

static const char* socket_type_usage =
    "Type of socket used, one of:\n"
    "  tcp: fds are endpoints of a TCP connection\n"
    "  socketpair: fds come from socketpair()\n"
    "  pipe: fds come from pipe()\n";


## Compatibility Matrix

### macOS 15.2

| ------ | --------- | ------ | --------- | --- | 
| Server | Svr Algo  | Client | Cl Algo   | Fun | 
| ------ | --------- | ------ | --------- | --- | 
| Go     | secp521r1 | Go     | secp521r1 | Yes |
| Go     | secp521r1 | Python | secp521r1 | No  |
| Go     | secp521r1 | Ruby   | secp521r1 | No  |
| Go     | secp521r1 | C#     | secp521r1 | No  |
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
| Python | secp384r1 | Go     | secp256r1 | Yes |
| Python | secp384r1 | Python | secp256r1 | Yes |
| Python | secp384r1 | PRuby  | secp256r1 | Yes |
| Python | secp384r1 | C#     | secp256r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Go     | secp521r1 | Go     | secp384r1 | Yes |
| Go     | secp521r1 | Python | secp384r1 | No  |
| Go     | secp521r1 | Ruby   | secp384r1 | No  |
| Go     | secp521r1 | C#     | secp384r1 | Yes |
| ------ | --------- | ------ | --------- | --- | 
| Go     | secp521r1 | Go     | secp256r1 | Yes |
| Go     | secp521r1 | Python | secp256r1 | No  |
| Go     | secp521r1 | Ruby   | secp256r1 | No  |
| Go     | secp521r1 | C#     | secp256r1 | Yes |
