# gRPC Client/Server Debugging

Right now I am focusing on getting Python working properly with mTLS with certificates of varying type.

All of the certificates being tested are well-formed and have been verified with other code to properly work with other mTLS implementations.

Using the `secp384r1` algorithm works across all clients/all languages. Using `secp521r` causes anomolous behavior between languages.


521 srv/cli
root_certificates: set to client cert
require_client_auth: true

Nope.


| SrvLang | SrvAlgo | CliLang | CliAlgo | Root | Auth | Works |
| ------- | ------- | ------- | ------- | ---- | ---- | ----- |
| Python  | ec521r1 | Python  | ec521r1 | Yes  | Yes  | No    |
| Python  | ec521r1 | Python  | ec521r1 | Yes  | No   | No    |
| Python  | ec521r1 | Python  | ec521r1 | No   | No   | No    |

| Python  | ec384r1 | Python  | ec521r1 | Yes  | Yes  | No    |
| Python  | ec384r1 | Python  | ec521r1 | Yes  | No   | Yes   |
| Python  | ec384r1 | Python  | ec521r1 | No   | No   | Yes   |

| Python  | ec521r1 | Go      | ec521r1 | Yes  | Yes  | No    |
| Python  | ec521r1 | Go      | ec521r1 | Yes  | No   | Yes   |
| Python  | ec521r1 | Go      | ec521r1 | No   | No   | Yes   |

| Python  | ec521r1 | C#      | ec521r1 | Yes  | Yes  | Yes   |
| Python  | ec521r1 | C#      | ec521r1 | Yes  | No   | Yes   |
| Python  | ec521r1 | C#      | ec521r1 | No   | No   | Yes   |
