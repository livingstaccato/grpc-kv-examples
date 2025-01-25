
/Users/tim.perkins/code/opensource/grpc/test/core/network_benchmarks/low_level_ping_pong.cc

static const char* socket_type_usage =
    "Type of socket used, one of:\n"
    "  tcp: fds are endpoints of a TCP connection\n"
    "  socketpair: fds come from socketpair()\n"
    "  pipe: fds come from pipe()\n";

### Go Server - secp521r1

#### Client: secp384r1
| Server | Svr Algo  | Client | Cl Algo   | Fun | 
| ------ | --------- | ------ | --------- | --- | 
| Go     | secp521r1 | Go     | secp384r1 | Yes |
| Go     | secp521r1 | Python | secp384r1 | No  |
| Go     | secp521r1 | Ruby   | secp384r1 | No  |
| Go     | secp521r1 | C#     | secp384r1 | Yes |

| Python | No  |
| Ruby   | No  |
| C#     | Yes |

C#

Works:
Client: secp384r1
Server: secp521r1