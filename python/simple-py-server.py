#!/usr/bin/env python3

import grpc
import logging
from concurrent import futures
from proto import kv_pb2, kv_pb2_grpc
import time
import os
import asyncio
from certificate_helper import log_cert_info, load_certificates_from_env, load_pem_certificate

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
        await self._log_request_details(context)
        return kv_pb2.Empty()

    async def Get(self, request, context):
        logger.info(f"🔍 📥 Get request - Key: {request.key}")
        await self._log_request_details(context)
        return kv_pb2.GetResponse(value=b"OK")

    async def _log_request_details(self, context):
        try:
            logger.debug(f"  🔎 🌐 Peer: {context.peer()}")

            # Try to get peer certificate details
            peer_cert = context.peer_certificate()
            if peer_cert:
                logger.debug("  🔐 Peer Certificate (PEM):\n%s", peer_cert.decode())
                x509_cert = load_pem_certificate(peer_cert)
                logger.debug("  🔍 Peer Certificate Details:")
                log_cert_info(x509_cert, "Peer")
            else:
                logger.warning("  ⚠️ No peer certificate found.")

            logger.debug("  🔒 Metadata:")
            for k, v in context.invocation_metadata():
                logger.debug(f"      {k}: {v}")

        except Exception as e:
            logger.error(f"  ❌ Logging error: {e}")

async def serve():
    logger.info("🚀 🔄 Server starting")

    certs = load_certificates_from_env()
    server_cert = certs["PLUGIN_SERVER_CERT"]
    server_key = certs["PLUGIN_SERVER_KEY"]
    client_cert = certs.get("PLUGIN_CLIENT_CERT") # Optional

    logger.debug(f"🔐 📊 Cert lengths - Server: {len(server_cert)}, Key: {len(server_key)}, Client: {len(client_cert) if client_cert else 0}")

    # Create server credentials
    try:
        server_credentials = grpc.ssl_server_credentials(
            [(server_key.encode(), server_cert.encode())],
            root_certificates=client_cert.encode() if client_cert else None,
            require_client_auth=True if client_cert else False
        )
        logger.info("🔒 ✅ Credentials created")
    except Exception as e:
        logger.error(f"🔒 ❌ Credentials setup failed: {e}")
        raise

    server = grpc.aio.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ('grpc.ssl_target_name_override', 'localhost'),
            ('grpc.default_authority', 'localhost'),
        ]
    )

    kv_pb2_grpc.add_KVServicer_to_server(KVServicer(), server)

    try:
        server.add_secure_port('[::]:50051', server_credentials)
        logger.info("🌐 ✅ Port bound")
    except Exception as e:
        logger.error(f"🌐 ❌ Port binding failed: {e}")
        raise

    await server.start()
    logger.info("🚀 ✅ Server started")
    try:
        await server.wait_for_termination()
    except KeyboardInterrupt:
        await server.stop(0)

if __name__ == '__main__':
    asyncio.run(serve())
