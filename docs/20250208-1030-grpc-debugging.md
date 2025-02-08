---
timestamp: 2025-02-08 10:31
iteration: 01
topic: gRPC Client/Server Debugging
---

Right now I am focusing on getting Python working properly with mTLS with certificates of varying types.

All of the certificates being tested are well-formed and have been verified with other code to properly work with other mTLS implementations.

Using the `secp384r1` algorithm works across all clients/all languages. Using `secp521r` causes anomolous behavior between languages. All certificates being used across languages are static in order to ease debugging.

Using only the Python Server, I have tested various configurations:


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


This is the log output of C# with root_cert and client_auth on.

```
2025-02-08 10:06:24.396 DEBUG __main__: 📡 gRPC Method: Get
2025-02-08 10:06:24.396 DEBUG __main__: 🌐 🔗 Peer Info: ipv6:%5B::1%5D:56832
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Raw Authentication Context: {'transport_security_type': [b'ssl'], 'x509_subject': [b'CN=localhost,O=HashiCorp'], 'x509_common_name': [b'localhost'], 'x509_pem_cert': [b'-----BEGIN CERTIFICATE-----\nMIICRjCCAaegAwIBAgIJAJiqCNTe+dNQMAoGCCqGSM49BAMEMCgxEjAQBgNVBAoM\nCUhhc2hpQ29ycDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI1MDIwNTIzMTkxNVoX\nDTI2MDIwNTIzMTkxNVowKDESMBAGA1UECgwJSGFzaGlDb3JwMRIwEAYDVQQDDAls\nb2NhbGhvc3QwgZswEAYHKoZIzj0CAQYFK4EEACMDgYYABACWbtKEnhdopfpfPN7i\nKKEQwVFSv+N7NTMYYBQzLiV3uYHxzUobqFLRVC7xbBlzm9cFfsKdC1vKXd3ZEUmA\nhsSc9AHtOxoBP32L4eBZRhVc3YkwX1KfsZoFCV2QKCBO8FrK/NILSnx+62Zm1ObA\nq2lLK0fQxUzz5IlSmepeSYhdDHpTyaN3MHUwDwYDVR0TAQH/BAUwAwEB/zAUBgNV\nHREEDTALgglsb2NhbGhvc3QwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMB\nMA4GA1UdDwEB/wQEAwIDqDAdBgNVHQ4EFgQU4QE9s5kFeuuBKy+g8oqvF6ebmBIw\nCgYIKoZIzj0EAwQDgYwAMIGIAkIA0ZrOXbqNdfx3RU70RwSpI2Z8N3JnmUzS/x5P\nDYcHqPBgx4m+9cnoL+aonYC7lToZSwQbrlz0uZr0C0GdzKwtPdQCQgCKsFlr3g/K\nwQz/lLp5agZFhQwhvScdNBmdNkyhBVYp8/AaYZQauqehqD4FojtRG2ZEEFhGVSge\nUsJiy7R2tIQzzw==\n-----END CERTIFICATE-----\n'], 'x509_subject_alternative_name': [b'localhost'], 'peer_dns': [b'localhost'], 'security_level': [b'TSI_PRIVACY_AND_INTEGRITY'], 'ssl_session_reused': [b'false']}
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - transport_security_type: [b'ssl']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - x509_subject: [b'CN=localhost,O=HashiCorp']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - x509_common_name: [b'localhost']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - x509_pem_cert: [b'-----BEGIN CERTIFICATE-----\nMIICRjCCAaegAwIBAgIJAJiqCNTe+dNQMAoGCCqGSM49BAMEMCgxEjAQBgNVBAoM\nCUhhc2hpQ29ycDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI1MDIwNTIzMTkxNVoX\nDTI2MDIwNTIzMTkxNVowKDESMBAGA1UECgwJSGFzaGlDb3JwMRIwEAYDVQQDDAls\nb2NhbGhvc3QwgZswEAYHKoZIzj0CAQYFK4EEACMDgYYABACWbtKEnhdopfpfPN7i\nKKEQwVFSv+N7NTMYYBQzLiV3uYHxzUobqFLRVC7xbBlzm9cFfsKdC1vKXd3ZEUmA\nhsSc9AHtOxoBP32L4eBZRhVc3YkwX1KfsZoFCV2QKCBO8FrK/NILSnx+62Zm1ObA\nq2lLK0fQxUzz5IlSmepeSYhdDHpTyaN3MHUwDwYDVR0TAQH/BAUwAwEB/zAUBgNV\nHREEDTALgglsb2NhbGhvc3QwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMB\nMA4GA1UdDwEB/wQEAwIDqDAdBgNVHQ4EFgQU4QE9s5kFeuuBKy+g8oqvF6ebmBIw\nCgYIKoZIzj0EAwQDgYwAMIGIAkIA0ZrOXbqNdfx3RU70RwSpI2Z8N3JnmUzS/x5P\nDYcHqPBgx4m+9cnoL+aonYC7lToZSwQbrlz0uZr0C0GdzKwtPdQCQgCKsFlr3g/K\nwQz/lLp5agZFhQwhvScdNBmdNkyhBVYp8/AaYZQauqehqD4FojtRG2ZEEFhGVSge\nUsJiy7R2tIQzzw==\n-----END CERTIFICATE-----\n']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - x509_subject_alternative_name: [b'localhost']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - peer_dns: [b'localhost']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - security_level: [b'TSI_PRIVACY_AND_INTEGRITY']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - ssl_session_reused: [b'false']
2025-02-08 10:06:24.396 WARNING __main__: ⚠️  Client did NOT provide mTLS certificate. Connection is not mutually authenticated.
2025-02-08 10:06:24.396 DEBUG __main__: TLS Version: N/A, Cipher Suite: N/A
```

This is the log from using the Go client with secp521r1:

```
2025-02-08 10:06:24.396 INFO __main__: 🔍 📥 Get request received - Key: test
2025-02-08 10:06:24.396 DEBUG __main__: 📡 gRPC Method: Get
2025-02-08 10:06:24.396 DEBUG __main__: 🌐 🔗 Peer Info: ipv6:%5B::1%5D:56832
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Raw Authentication Context: {'transport_security_type': [b'ssl'], 'x509_subject': [b'CN=localhost,O=HashiCorp'], 'x509_common_name': [b'localhost'], 'x509_pem_cert': [b'-----BEGIN CERTIFICATE-----\nMIICRjCCAaegAwIBAgIJAJiqCNTe+dNQMAoGCCqGSM49BAMEMCgxEjAQBgNVBAoM\nCUhhc2hpQ29ycDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI1MDIwNTIzMTkxNVoX\nDTI2MDIwNTIzMTkxNVowKDESMBAGA1UECgwJSGFzaGlDb3JwMRIwEAYDVQQDDAls\nb2NhbGhvc3QwgZswEAYHKoZIzj0CAQYFK4EEACMDgYYABACWbtKEnhdopfpfPN7i\nKKEQwVFSv+N7NTMYYBQzLiV3uYHxzUobqFLRVC7xbBlzm9cFfsKdC1vKXd3ZEUmA\nhsSc9AHtOxoBP32L4eBZRhVc3YkwX1KfsZoFCV2QKCBO8FrK/NILSnx+62Zm1ObA\nq2lLK0fQxUzz5IlSmepeSYhdDHpTyaN3MHUwDwYDVR0TAQH/BAUwAwEB/zAUBgNV\nHREEDTALgglsb2NhbGhvc3QwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMB\nMA4GA1UdDwEB/wQEAwIDqDAdBgNVHQ4EFgQU4QE9s5kFeuuBKy+g8oqvF6ebmBIw\nCgYIKoZIzj0EAwQDgYwAMIGIAkIA0ZrOXbqNdfx3RU70RwSpI2Z8N3JnmUzS/x5P\nDYcHqPBgx4m+9cnoL+aonYC7lToZSwQbrlz0uZr0C0GdzKwtPdQCQgCKsFlr3g/K\nwQz/lLp5agZFhQwhvScdNBmdNkyhBVYp8/AaYZQauqehqD4FojtRG2ZEEFhGVSge\nUsJiy7R2tIQzzw==\n-----END CERTIFICATE-----\n'], 'x509_subject_alternative_name': [b'localhost'], 'peer_dns': [b'localhost'], 'security_level': [b'TSI_PRIVACY_AND_INTEGRITY'], 'ssl_session_reused': [b'false']}
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - transport_security_type: [b'ssl']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - x509_subject: [b'CN=localhost,O=HashiCorp']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - x509_common_name: [b'localhost']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - x509_pem_cert: [b'-----BEGIN CERTIFICATE-----\nMIICRjCCAaegAwIBAgIJAJiqCNTe+dNQMAoGCCqGSM49BAMEMCgxEjAQBgNVBAoM\nCUhhc2hpQ29ycDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI1MDIwNTIzMTkxNVoX\nDTI2MDIwNTIzMTkxNVowKDESMBAGA1UECgwJSGFzaGlDb3JwMRIwEAYDVQQDDAls\nb2NhbGhvc3QwgZswEAYHKoZIzj0CAQYFK4EEACMDgYYABACWbtKEnhdopfpfPN7i\nKKEQwVFSv+N7NTMYYBQzLiV3uYHxzUobqFLRVC7xbBlzm9cFfsKdC1vKXd3ZEUmA\nhsSc9AHtOxoBP32L4eBZRhVc3YkwX1KfsZoFCV2QKCBO8FrK/NILSnx+62Zm1ObA\nq2lLK0fQxUzz5IlSmepeSYhdDHpTyaN3MHUwDwYDVR0TAQH/BAUwAwEB/zAUBgNV\nHREEDTALgglsb2NhbGhvc3QwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMB\nMA4GA1UdDwEB/wQEAwIDqDAdBgNVHQ4EFgQU4QE9s5kFeuuBKy+g8oqvF6ebmBIw\nCgYIKoZIzj0EAwQDgYwAMIGIAkIA0ZrOXbqNdfx3RU70RwSpI2Z8N3JnmUzS/x5P\nDYcHqPBgx4m+9cnoL+aonYC7lToZSwQbrlz0uZr0C0GdzKwtPdQCQgCKsFlr3g/K\nwQz/lLp5agZFhQwhvScdNBmdNkyhBVYp8/AaYZQauqehqD4FojtRG2ZEEFhGVSge\nUsJiy7R2tIQzzw==\n-----END CERTIFICATE-----\n']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - x509_subject_alternative_name: [b'localhost']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - peer_dns: [b'localhost']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - security_level: [b'TSI_PRIVACY_AND_INTEGRITY']
2025-02-08 10:06:24.396 DEBUG __main__: 🔒 Auth Context Item - ssl_session_reused: [b'false']
2025-02-08 10:06:24.396 WARNING __main__: ⚠️  Client did NOT provide mTLS certificate. Connection is not mutually authenticated.
2025-02-08 10:06:24.396 DEBUG __main__: TLS Version: N/A, Cipher Suite: N/A
WARNING: All log messages before absl::InitializeLog() is called are written to STDERR
I0000 00:00:1739038039.200644 9008470 ssl_transport_security.cc:1665] Handshake failed with error SSL_ERROR_SSL: error:100000c0:SSL routines:OPENSSL_internal:PEER_DID_NOT_RETURN_A_CERTIFICATE: Invalid certificate verification context
I0000 00:00:1739038040.211058 9008469 ssl_transport_security.cc:1665] Handshake failed with error SSL_ERROR_SSL: error:100000c0:SSL routines:OPENSSL_internal:PEER_DID_NOT_RETURN_A_CERTIFICATE: Invalid certificate verification context
```

# Latest Python gRPC Function Signatures

```
grpc.insecure_channel(target, options=None, compression=None)

grpc.secure_channel(target, credentials, options=None, compression=None)

grpc.intercept_channel(channel, *interceptors)

grpc.ssl_channel_credentials(root_certificates=None, private_key=None, certificate_chain=None)

grpc.ssl_server_certificate_configuration(private_key_certificate_chain_pairs, root_certificates=None)

grpc.server(thread_pool, handlers=None, interceptors=None, options=None, maximum_concurrent_rpcs=None, compression=None, xds=False)
```

# Latest Channel Arguments


# gRPC Channel Arguments

Last Update: 2024-11-04

grpc.census
grpc.loadreporting
grpc.server_call_metric_recording
grpc.minimal_stack
grpc.max_concurrent_streams
grpc.max_receive_message_length
grpc.max_send_message_length
grpc.max_connection_idle_ms
grpc.max_connection_age_ms
grpc.max_connection_age_grace_ms
grpc.client_idle_timeout_ms
grpc.per_message_compression
grpc.per_message_decompression
grpc.http2.initial_sequence_number
grpc.http2.lookahead_bytes
grpc.http2.hpack_table_size.decoder
grpc.http2.hpack_table_size.encoder
grpc.http2.max_frame_size
grpc.http2.bdp_probe
grpc.http2.min_time_between_pings_ms
grpc.http2.min_ping_interval_without_data_ms
grpc.server_max_unrequested_time_in_server
grpc.http2_scheme
grpc.http2.max_pings_without_data
grpc.http2.max_ping_strikes
grpc.http2.write_buffer_size
grpc.http2.true_binary
grpc.experimental.http2.enable_preferred_frame_size
grpc.keepalive_time_ms
grpc.keepalive_timeout_ms
grpc.keepalive_permit_without_calls
grpc.default_authority
grpc.primary_user_agent
grpc.secondary_user_agent
grpc.min_reconnect_backoff_ms
grpc.max_reconnect_backoff_ms
grpc.initial_reconnect_backoff_ms
grpc.dns_min_time_between_resolutions_ms
grpc.server_handshake_timeout_ms
grpc.ssl_target_name_override
grpc.ssl_session_cache
grpc.tsi.max_frame_size
grpc.max_metadata_size
grpc.absolute_max_metadata_size
grpc.so_reuseport
grpc.resource_quota
grpc.expand_wildcard_addrs
grpc.service_config
grpc.service_config_disable_resolution
grpc.lb_policy_name
grpc.lb.ring_hash.ring_size_cap
grpc.socket_mutator
grpc.socket_factory
grpc.max_channel_trace_event_memory_per_node
grpc.enable_channelz
grpc.use_cronet_packet_coalescing
grpc.experimental.tcp_read_chunk_size
grpc.experimental.tcp_min_read_chunk_size
grpc.experimental.tcp_max_read_chunk_size
grpc.experimental.tcp_tx_zerocopy_enabled
grpc.experimental.tcp_tx_zerocopy_send_bytes_threshold
grpc.experimental.tcp_tx_zerocopy_max_simultaneous_sends
grpc.tcp_receive_buffer_size
grpc.grpclb_call_timeout_ms
grpc.grpclb_fallback_timeout_ms
grpc.experimental.grpclb_channel_args
grpc.priority_failover_timeout_ms
grpc.workaround.cronet_compression
grpc.optimization_target
grpc.enable_retries
grpc.experimental.enable_hedging
grpc.per_rpc_retry_buffer_size
grpc.mobile_log_context
grpc.disable_client_authority_filter
grpc.enable_http_proxy
grpc.http_proxy
grpc.address_http_proxy
grpc.address_http_proxy_enabled_addresses
grpc.surface_user_agent
grpc.inhibit_health_checking
grpc.dns_enable_srv_queries
grpc.dns_ares_query_timeout
grpc.use_local_subchannel_pool
grpc.channel_pooling_domain
grpc.channel_id
grpc.authorization_policy_provider
grpc.experimental.server_config_change_drain_grace_time_ms
grpc.dscp
grpc.happy_eyeballs_connection_attempt_delay_ms
grpc.event_engine_use_memory_allocator_factory
grpc.max_allowed_incoming_connections
grpc.experimental.stats_plugins
grpc.security_frame_allowed

