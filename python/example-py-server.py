#!/usr/bin/env python3

import grpc
import logging
from concurrent import futures
from proto import kv_pb2, kv_pb2_grpc
import os
import asyncio
from utils.certificate_helper import log_cert_info, load_pem_certificate

# Configure detailed logging with structured prefixes
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s %(levelname)s %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("pyvider")

# --- Structured Logging Helper ---
def slog(domain, action, status, msg):
    """
    Returns a log message prefixed with structured emoji tags.
    Format: [Domain] → [Action] → [Status] message
    """
    return f"|{domain}|{action}|{status}|{msg}|"

# Emoji mappings (as constants)
# Domain (D)
D_SERVER = "🛎️ "      # Server
D_CLIENT = "🙋"      # Client
D_PLUGIN = "🔌"      # Plugin
D_TCP    = "🌐"      # TCP
D_UNIX   = "📞"      # Unix
D_HAND   = "🤝"      # Handshake
D_SECURITY = "🔐"    # Security
D_CONFIG = "⚙️"     # Config
D_PROTOCOL = "📡"   # Protocol
D_UTILS   = "🧰"     # Utils
D_EXCEPTION = "❗"   # Exception
D_TELEMETRY = "🛰️"   # Telemetry
D_DI      = "💉"     # DI

# Action (A)
A_START   = "🚀"    # Start
A_HANDSHAKE = "🤝"  # Handshake
A_CONNECT = "🕵️"   # Connect
A_LISTEN  = "🕹 "    # Listen
A_READ    = "📖"    # Read
A_WRITE   = "📤"    # Write
A_RECEIVE = "📥"    # Receive
A_CLOSE   = "🔒"    # Close
A_PARSE   = "🔍"    # Parse
A_BUILD   = "📝"    # Build
A_RETRY   = "🔁"    # Retry
A_TEST    = "🧪"    # Test
A_CERT    = "📜"    # Cert
A_KEY     = "🔑"    # Key
A_ENCRYPT = "🛡️"    # Encrypt

# Status (S)
S_SUCCESS = "✅"    # Success
S_ERROR   = "❌"    # Error
S_FAIL    = "🚫"    # Fail
S_WARN    = "⚠️"    # Warn
S_STOP    = "🛑"    # Stop
S_AFFIRM  = "👍"    # Affirm
S_MONITOR = "👀"    # Monitor
S_CRASH   = "💥"    # Crash
S_NONE    = "⭕"    # None
S_SUSPEND = "⏸️"    # Suspend
S_RESUME  = "▶️"    # Resume
S_PENDING = "⏳"    # Pending
S_IDLE    = "💤"    # Idle
S_ONGOING = "🔄"    # Ongoing

# --- Service Implementation ---
class KVServicer(kv_pb2_grpc.KVServicer):
    """
    Implements the gRPC KVServicer interface with detailed structured logging.
    Handles Get and Put requests.
    """
    def __init__(self):
        logger.info(slog(D_SERVER, A_START, S_SUCCESS, "Initializing KVServicer Service"))
    
    async def Put(self, request, context):
        logger.info(slog(D_SERVER, A_RECEIVE, S_SUCCESS, f"Put request received - Key: {request.key}"))
        await self._log_request_details(context, "Put")
        return kv_pb2.Empty()
    
    async def Get(self, request, context):
        logger.info(slog(D_SERVER, A_RECEIVE, S_SUCCESS, f"Get request received - Key: {request.key}"))
        await self._log_request_details(context, "Get")
        return kv_pb2.GetResponse(value=b"OK")
    
    async def _log_request_details(self, context, method_name):
        """
        Logs detailed request information, including peer details and mTLS auth context.
        """
        logger.debug(slog(D_SERVER, A_HANDSHAKE, S_SUCCESS, f"Processing {method_name} request"))
        try:
            peer_info = context.peer()
            logger.debug(slog(D_SERVER, A_CONNECT, S_SUCCESS, f"Peer Info: {peer_info}"))
            auth_context = context.auth_context()
            logger.debug(slog(D_SERVER, A_READ, S_SUCCESS, f"Raw Authentication Context: {auth_context}"))
            # Attempt to find a client certificate under either key:
            cert_bytes = None
            if b"x509_certificate" in auth_context:
                cert_bytes = auth_context[b"x509_certificate"][0]
                logger.debug(slog(D_SERVER, A_PARSE, S_SUCCESS, "Found certificate under key 'x509_certificate'"))
            elif b"x509_pem_cert" in auth_context:
                cert_bytes = auth_context[b"x509_pem_cert"][0]
                logger.debug(slog(D_SERVER, A_PARSE, S_SUCCESS, "Found certificate under key 'x509_pem_cert'"))
            else:
                logger.warning(slog(D_SERVER, A_HANDSHAKE, S_WARN, "Client did NOT provide mTLS certificate."))
            
            if cert_bytes:
                try:
                    client_cert = load_pem_certificate(cert_bytes)
                    log_cert_info(client_cert, "Client mTLS")
                    common_name = client_cert.subject.rfc4514_string()
                    logger.info(slog(D_SERVER, A_PARSE, S_SUCCESS, f"Client mTLS Common Name: {common_name} - Authenticated"))
                except Exception as cert_err:
                    logger.error(slog(D_SERVER, A_PARSE, S_ERROR, f"Client Certificate Processing Error: {cert_err}"))
            # Log TLS version and cipher suite if available
            tls_version = auth_context.get(b'tls_version', [b'N/A'])[0].decode()
            cipher_suite = auth_context.get(b'cipher_suite', [b'N/A'])[0].decode()
            logger.debug(slog(D_SERVER, "🔐 Security", S_SUCCESS, f"TLS Version: {tls_version}, Cipher Suite: {cipher_suite}"))
        except Exception as e:
            logger.error(slog(D_SERVER, "❗ Exception", S_ERROR, f"Error logging request details for {method_name}: {e}"))

# --- Server Setup and Run ---
async def serve():
    """
    Starts the gRPC server with mTLS and detailed structured logging.
    """
    logger.info(slog(D_SERVER, A_START, S_SUCCESS, "Starting gRPC KV Server"))
    
    logger.info(slog(D_SERVER, A_READ, S_SUCCESS, "Loading server certificates and keys from environment"))
    required_env_vars = {
        "PLUGIN_SERVER_CERT": "Server certificate",
        "PLUGIN_SERVER_KEY": "Server key",
        "PLUGIN_CLIENT_CERT": "Client CA certificate (optional for mTLS)"
    }
    certs = {}
    try:
        for var, desc in required_env_vars.items():
            value = os.getenv(var)
            if not value:
                raise ValueError(f"Missing environment variable: {var} ({desc})")
            certs[var] = value
            logger.debug(slog(D_SERVER, A_READ, S_SUCCESS, f"Environment variable '{var}' found"))
        server_cert = certs["PLUGIN_SERVER_CERT"]
        server_key = certs["PLUGIN_SERVER_KEY"]
        client_cert = certs.get("PLUGIN_CLIENT_CERT")
        logger.debug(slog(D_SERVER, A_PARSE, S_SUCCESS, f"Certificate data lengths - Server Cert: {len(server_cert)} bytes, Server Key: {len(server_key)} bytes, Client CA Cert: {len(client_cert) if client_cert else 0} bytes"))
        logger.info(slog(D_SERVER, A_PARSE, S_SUCCESS, "Certificates loaded successfully from environment"))
    except ValueError as ve:
        logger.error(slog(D_SERVER, "❗ Exception", S_ERROR, f"Configuration Error: {ve}"))
        raise Exception(f"Failed to load certificates: {ve}") from ve
    except Exception as e:
        logger.error(slog(D_SERVER, "❗ Exception", S_ERROR, f"Unexpected error during certificate loading: {e}"))
        raise Exception(f"Unexpected certificate loading error: {e}") from e

    # Setup server credentials with mTLS
    try:
        logger.info(slog(D_SERVER, "🔐 Security", S_SUCCESS, "Configuring gRPC server credentials for mTLS"))
        # If client_cert is provided, it is used for verifying the client; otherwise, client auth is disabled.
        server_credentials = grpc.ssl_server_credentials(
            [(server_key.encode(), server_cert.encode())],
            root_certificates=client_cert.encode() if client_cert else None,
            require_client_auth=False # True if client_cert else False
        )
        logger.info(slog(D_SERVER, D_SECURITY, S_SUCCESS, "gRPC server credentials configured successfully"))
    except grpc.RpcError as grpc_e:
        logger.error(slog(D_SERVER, "🔐 Security", S_ERROR, f"gRPC Credential Setup Error: {grpc_e.code()}, details: {grpc_e.details()}"))
        raise Exception(f"gRPC credential setup failed: {grpc_e}") from grpc_e
    except Exception as e:
        logger.error(slog(D_SERVER, "🔐 Security", S_ERROR, f"gRPC Credential Setup Error: {e}"))
        raise Exception(f"Unexpected error during gRPC credential setup: {e}") from e

    server = grpc.aio.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ('grpc.ssl_target_name_override', 'localhost'),
            ('grpc.default_authority', 'localhost'),
        ]
    )
    kv_pb2_grpc.add_KVServicer_to_server(KVServicer(), server)

    # Add secure port to server
    try:
        port = '[::]:50051'
        logger.info(slog(D_SERVER, A_LISTEN, S_SUCCESS, f"Adding secure port {port} to gRPC server"))
        server.add_secure_port(port, server_credentials)
        logger.info(slog(D_SERVER, A_LISTEN, S_SUCCESS, f"Secure port {port} added successfully"))
    except Exception as e:
        logger.error(slog(D_SERVER, A_LISTEN, S_ERROR, f"Failed to bind secure port: {e}"))
        raise Exception(f"Port binding failed: {e}") from e

    await server.start()
    logger.info(slog(D_SERVER, A_START, S_SUCCESS, "gRPC KV Server started and listening securely on [::]:50051"))
    try:
        await server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info(slog(D_SERVER, A_CLOSE, S_SUCCESS, "Server shutdown initiated via KeyboardInterrupt"))
        await server.stop(0)

if __name__ == '__main__':
    asyncio.run(serve())
