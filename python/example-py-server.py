#!/usr/bin/env python3

import grpc
import logging
from concurrent import futures
from proto import kv_pb2, kv_pb2_grpc
import time
import os
import asyncio
from utils.certificate_helper import log_cert_info, load_certificates_from_env, load_pem_certificate

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(levelname)s %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class KVServicer(kv_pb2_grpc.KVServicer):
    def __init__(self):
        logger.info("🔧 🚀 Initializing KVServicer")

    async def Put(self, request, context):
        logger.info(f"📝 📥 Put request - Key: {request.key}")
        await self._log_request_details(context) # Log request details including auth context
        return kv_pb2.Empty()

    async def Get(self, request, context):
        logger.info(f"🔍 📥 Get request - Key: {request.key}")
        await self._log_request_details(context) # Log request details including auth context
        return kv_pb2.GetResponse(value=b"OK")

    async def _log_request_details(self, context):
        """
        Logs details of the request, including peer information and authentication context.
        This is crucial for debugging and security monitoring, especially for mTLS connections.
        """
        try:
            logger.debug(f"🔎 🌐 Peer: {context.peer()}") # Log peer address

            auth_context = context.auth_context()
            logger.debug(f"🔎 🔒 Raw Auth Context: {auth_context}") # Log the entire auth context for debugging

            for k, v in auth_context.items():
                logger.debug(f"🔎 🔒 Auth Context Item {k}: {v}")

            # Check if mutual TLS was established and log client certificate details
            if b"x509_certificate" in auth_context:
                cert_bytes = auth_context[b"x509_certificate"][0]
                try:
                    client_cert = load_pem_certificate(cert_bytes) # Load certificate object from bytes
                    log_cert_info(client_cert, "Client") # Use helper function to log detailed cert info
                    common_name = client_cert.subject.common_name
                    logger.info(f"🔑 ✅ Client mTLS Common Name: {common_name}") # Log Common Name
                except Exception as cert_err:
                    logger.error(f"❌ Client Certificate Processing Error: {cert_err}")
            else:
                logger.warning("⚠️  Client did NOT provide mTLS certificate.") # Warning if no client cert in context

        except Exception as e:
            logger.error(f"🔎 ❌ Error logging request details: {e}")


async def serve():
    """
    Starts the gRPC server with mTLS enabled.
    Loads certificates from environment variables, sets up server credentials,
    and binds the KVServicer to the server.
    """
    logger.info("🚀 🔄 Server starting")

    logger.info("🔐 📦 Loading certificates from environment variables...")
    try:
        certs = load_certificates_from_env() # Load server and client certificates/keys from environment
        server_cert = certs["PLUGIN_SERVER_CERT"]
        server_key = certs["PLUGIN_SERVER_KEY"]
        client_cert = certs.get("PLUGIN_CLIENT_CERT") # Optional client CA cert for mTLS

        logger.debug(f"🔐 📊 Cert lengths - Server Cert: {len(server_cert)}, Server Key: {len(server_key)}, Client CA Cert: {len(client_cert) if client_cert else 0}")
        logger.info("🔐 ✅ Certificates loaded successfully from environment.")

    except ValueError as e:
        logger.error(f"❌ 🔐 Certificate loading failed due to missing environment variables: {e}")
        raise # Propagate exception to prevent server from starting without certs
    except Exception as e:
        logger.error(f"❌ 🔐 Unexpected error during certificate loading: {e}")
        raise # Propagate exception - critical error

    # Create server credentials for secure connection
    try:
        logger.info("🔒 ⚙️ Setting up server credentials...")
        server_credentials = grpc.ssl_server_credentials(
            [(server_key.encode(), server_cert.encode())], # Server cert and key pair
            root_certificates=client_cert.encode() if client_cert else None, # Client CA cert for mTLS, None if no client auth required
            require_client_auth=True # Uncomment to enforce client certificate authentication
            # require_client_auth=True if client_cert else False # Conditionally require client auth
        )
        logger.info("🔒 ✅ Server credentials created successfully.")
    except Exception as e:
        logger.error(f"🔒 ❌ Server credentials setup failed: {e}")
        raise # Propagate exception if credentials setup fails

    server = grpc.aio.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ('grpc.ssl_target_name_override', 'localhost'), # Option for SSL target name override (e.g., for testing)
            ('grpc.default_authority', 'localhost'),      # Option to set default authority
        ]
    )

    kv_pb2_grpc.add_KVServicer_to_server(KVServicer(), server) # Add KV service to the server

    try:
        logger.info("🌐 👂 Binding server port [::]:50051 with secure credentials...")
        server.add_secure_port('[::]:50051', server_credentials) # Add secure port to the server
        logger.info("🌐 ✅ Server port bound successfully.")
    except Exception as e:
        logger.error(f"🌐 ❌ Failed to bind server port: {e}")
        raise # Propagate exception if port binding fails

    await server.start()
    logger.info("🚀 ✅ Server started and listening on [::]:50051")
    try:
        await server.wait_for_termination() # Keep server running until termination
    except KeyboardInterrupt:
        logger.info("🛑 Server termination initiated by keyboard interrupt.")
        await server.stop(0) # Graceful shutdown

if __name__ == '__main__':
    asyncio.run(serve())
