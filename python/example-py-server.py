#!/usr/bin/env python3

import grpc
import logging
from concurrent import futures
from proto import kv_pb2, kv_pb2_grpc
import time
import os
import asyncio
from pyvider.rpcplugin.utils.certificate_helper import log_cert_info, load_certificates_from_env, load_pem_certificate
from pyvider.rpcplugin.exceptions import RPCPluginError, CertificateError, TransportError, SecurityError

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(levelname)s %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class KVServicer(kv_pb2_grpc.KVServicer):
    """
    Implements the gRPC KVServicer interface.
    Handles Get and Put requests and logs request details, including mTLS information.
    """
    def __init__(self):
        logger.info("🔧 🚀 Initializing KVServicer Service")

    async def Put(self, request, context):
        logger.info(f"📝 📥 Put request received - Key: {request.key}")
        await self._log_request_details(context, "Put") # Include method name in logging
        return kv_pb2.Empty()

    async def Get(self, request, context):
        logger.info(f"🔍 📥 Get request received - Key: {request.key}")
        await self._log_request_details(context, "Get") # Include method name in logging
        return kv_pb2.GetResponse(value=b"OK")

    async def _log_request_details(self, context, method_name):
        """
        Logs detailed request information, including peer details and mTLS auth context.
        Enhanced to provide better formatting and error handling for certificate details.
        """
        logger.debug(f"📡 gRPC Method: {method_name}") # Log the method being called
        try:
            logger.debug(f"🌐 🔗 Peer Info: {context.peer()}") # Log client's peer address

            auth_context = context.auth_context()
            logger.debug(f"🔒 Raw Authentication Context: {auth_context}") # Log raw auth context for deep inspection

            for key, value in auth_context.items():
                logger.debug(f"🔒 Auth Context Item - {key}: {value}")

            if b"x509_certificate" in auth_context:
                logger.info("🔑 🔒 mTLS Client Certificate Found in Auth Context. Processing...")
                cert_bytes = auth_context[b"x509_certificate"][0]
                try:
                    client_cert = load_pem_certificate(cert_bytes)
                    log_cert_info(client_cert, "Client mTLS") # Use helper to log detailed client cert info
                    common_name = client_cert.subject.common_name
                    logger.info(f"🔑 ✅ Client mTLS Common Name: {common_name} - Successfully Authenticated via mTLS")
                except CertificateError as cert_err:
                    logger.error(f"❌ 🔑 Client Certificate Processing Error: {cert_err}")
                    logger.debug("Raw Client Certificate Bytes (for deeper debug if needed - handle with caution in production):")
                    logger.debug(cert_bytes) # Only log raw bytes at debug level and in dev env
                except Exception as e:
                    logger.error(f"❌ 🔑 Unexpected error processing client certificate: {e}")
            else:
                logger.warning("⚠️  Client did NOT provide mTLS certificate. Connection is not mutually authenticated.")

            # Log TLS version and cipher suite if available (useful for security context)
            tls_version = context.auth_context().get(b'tls_version', [b'N/A'])[0].decode()
            cipher_suite = context.auth_context().get(b'cipher_suite', [b'N/A'])[0].decode()
            logger.debug(f"TLS Version: {tls_version}, Cipher Suite: {cipher_suite}")


        except Exception as e:
            logger.error(f"❌ 🔎 Error logging request details for {method_name} method: {e}")


async def serve():
    """
    Starts the gRPC server with mTLS.
    Enhanced logging and error handling for certificate loading and server setup.
    """
    logger.info("🚀 🔄 Starting gRPC KV Server...")

    logger.info("🔐 📦 Loading server certificates and keys from environment variables...")
    required_env_vars = {
        "PLUGIN_SERVER_CERT": "Server certificate",
        "PLUGIN_SERVER_KEY": "Server key",
        "PLUGIN_CLIENT_CERT": "Client CA certificate (optional for mTLS)" # Clarify optional client CA cert
    }
    certs = {}
    try:
        logger.debug("🔍 Checking for required environment variables: %s", list(required_env_vars.keys()))
        for var, description in required_env_vars.items():
            value = os.getenv(var)
            if not value:
                raise ValueError(f"Missing environment variable: {var} ({description})")
            certs[var] = value
            logger.debug(f"✅ Environment variable '{var}' found.")

        server_cert = certs["PLUGIN_SERVER_CERT"]
        server_key = certs["PLUGIN_SERVER_KEY"]
        client_cert = certs.get("PLUGIN_CLIENT_CERT") # Client CA cert is optional

        logger.debug(f"🔐 📊 Certificate data lengths - Server Cert: {len(server_cert)} bytes, Server Key: {len(server_key)} bytes, Client CA Cert: {len(client_cert) if client_cert else 0} bytes")
        logger.info("🔐 ✅ Certificates loaded successfully from environment variables.")

    except ValueError as ve:
        logger.error(f"❌ 🔐 Configuration Error: {ve}") # More specific error message
        raise CertificateError(f"Failed to load certificates from environment: {ve}") from ve # Use custom CertificateError
    except Exception as e:
        logger.error(f"❌ 🔐 Unexpected error during certificate loading: {e}")
        raise SecurityError(f"Unexpected certificate loading error: {e}") from e # Use custom SecurityError

    # Setup server credentials with mTLS
    try:
        logger.info("🔒 ⚙️ Configuring gRPC server credentials for mTLS...")
        server_credentials = grpc.ssl_server_credentials(
            [(server_key.encode(), server_cert.encode())], # Server certificate and key
            root_certificates=client_cert.encode() if client_cert else None, # Client CA certificate for mTLS (optional)
            require_client_auth=True # Uncomment to enforce mutual TLS client authentication is required
            # require_client_auth=True if client_cert else False # Conditionally require client auth based on CA cert presence
        )
        logger.info("🔒 ✅ gRPC server credentials configured successfully for secure transport.")
    except grpc.RpcError as grpc_e:
        logger.error(f"❌ 🔒 gRPC Credential Setup Error (gRPC level): {grpc_e.code()}, details: {grpc_e.details()}")
        raise TransportError(f"gRPC credential setup failed: {grpc_e}") from grpc_e # Use custom TransportError for gRPC related issues
    except Exception as e:
        logger.error(f"❌ 🔒 gRPC Credential Setup Error: {e}")
        raise SecurityError(f"Unexpected error during gRPC credential setup: {e}") from e # Use custom SecurityError for general security setup issues


    server = grpc.aio.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ('grpc.ssl_target_name_override', 'localhost'), # For testing, allows overriding target name in SSL handshake
            ('grpc.default_authority', 'localhost'),      # Sets the default authority for requests
        ]
    )

    kv_pb2_grpc.add_KVServicer_to_server(KVServicer(), server) # Register KV service implementation

    # Add secure port to server
    try:
        logger.info("🌐 👂 Adding secure port [::]:50051 to gRPC server...")
        server.add_secure_port('[::]:50051', server_credentials)
        logger.info("🌐 ✅ Secure port [::]:50051 added successfully.")
    except Exception as e:
        logger.error(f"🌐 ❌ Failed to bind secure port [::]:50051: {e}")
        raise TransportError(f"Port binding failed: {e}") from e # Use custom TransportError for network binding issues

    await server.start()
    logger.info("🚀 ✅ gRPC KV Server started and listening securely on [::]:50051")
    try:
        await server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info("🛑 Server shutdown initiated via KeyboardInterrupt.")
        await server.stop(0) # Graceful server shutdown

if __name__ == '__main__':
    asyncio.run(serve())
