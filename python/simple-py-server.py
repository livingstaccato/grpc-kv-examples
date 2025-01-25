#!/usr/bin/env python3

import grpc
import logging
from concurrent import futures
from proto import kv_pb2, kv_pb2_grpc
import time
import os
import ssl

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

    def Put(self, request, context):
        logger.info(f"📝 📥 Put request - Key: {request.key}")
        self._log_request_details(context)
        return kv_pb2.Empty()

    def Get(self, request, context):
        logger.info(f"🔍 📥 Get request - Key: {request.key}")
        self._log_request_details(context)
        return kv_pb2.GetResponse(value=b"OK")

    def _log_request_details(self, context):
        try:
            logger.debug(f"  🔎 🌐 Peer: {context.peer()}")

            # Get the SSL object and log details if available
            ssl_obj = context._sslobject  # Access the internal _sslobject
            if ssl_obj:
                logger.debug("  🔐 SSL details:")
                logger.debug(f"    Version: {ssl_obj.version()}")
                cipher = ssl_obj.cipher()
                logger.debug(f"    Cipher: {cipher[0]} (protocol: {cipher[1]}, bits: {cipher[2]})")
            else:
                logger.warning("  ⚠️ No SSL object found in the context.")
            
            logger.debug("  🔒 Metadata:")
            for k, v in context.invocation_metadata():
                logger.debug(f"      {k}: {v}")

        except Exception as e:
            logger.error(f"  ❌ Logging error: {e}")

def serve():
    logger.info("🚀 🔄 Server starting")

    try:
        server_cert = os.getenv('PLUGIN_SERVER_CERT')
        server_key = os.getenv('PLUGIN_SERVER_KEY')
        client_cert = os.getenv('PLUGIN_CLIENT_CERT')

        if not all([server_cert, server_key]):
            raise ValueError("🔐 ❌ Missing certificates")

        logger.debug(f"🔐 📊 Cert lengths - Server: {len(server_cert)}, Key: {len(server_key)}, Client: {len(client_cert) if client_cert else 0}")

        # Create SSL context
        server_credentials = grpc.ssl_server_credentials(
            [(server_key.encode(), server_cert.encode())],
            root_certificates=client_cert.encode() if client_cert else None,
            require_client_auth=True if client_cert else False
        )

        logger.info("🔒 ✅ Credentials created")

    except Exception as e:
        logger.error(f"🔒 ❌ Credentials setup failed: {str(e)}")
        raise

    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ('grpc.ssl_target_name_override', 'localhost'),
            ('grpc.default_authority', 'localhost'),
            #('grpc.use_local_subchannel_pool', 1),
        ]
    )

    kv_pb2_grpc.add_KVServicer_to_server(KVServicer(), server)

    try:
        server.add_secure_port('[::]:50051', server_credentials)
        logger.info("🌐 ✅ Port bound")
    except Exception as e:
        logger.error(f"🌐 ❌ Port binding failed: {str(e)}")
        raise

    try:
        server.start()
        logger.info("🚀 ✅ Server started")
        while True:
            time.sleep(86400)
    except KeyboardInterrupt:
        server.stop(0)
    except Exception as e:
        logger.error(f"⚡ ❌ Error: {str(e)}")
        server.stop(0)
        raise

if __name__ == '__main__':
    serve()
