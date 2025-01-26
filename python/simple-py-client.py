#!/usr/bin/env python3

import os
import grpc
import logging
import ssl
import time
from datetime import datetime, timezone
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from proto import kv_pb2, kv_pb2_grpc
from utils.certificate_helper import log_cert_info, load_certificates_from_env

# Configure logging with microsecond precision
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(levelname)s %(name)s: %(message)s',
    datefmt='%Y/%m/%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def create_channel_credentials(certs: dict):
    """Create gRPC channel credentials with detailed logging"""
    logger.info("🔒 Creating channel credentials...")

    # Load and validate certificates
    server_cert = x509.load_pem_x509_certificate(certs["PLUGIN_SERVER_CERT"].encode())
    client_cert = x509.load_pem_x509_certificate(certs["PLUGIN_CLIENT_CERT"].encode())

    log_cert_info(server_cert, "Server")
    log_cert_info(client_cert, "Client")

    # Create gRPC credentials
    credentials = grpc.ssl_channel_credentials(
        root_certificates=certs["PLUGIN_SERVER_CERT"].encode(),
        private_key=certs["PLUGIN_CLIENT_KEY"].encode(),
        certificate_chain=certs["PLUGIN_CLIENT_CERT"].encode()
    )

    return credentials

def main():
    try:
        logger.info("🚀 Starting gRPC client... 🌟")

        # Load certificates
        certs = load_certificates_from_env()

        # Create credentials
        credentials = create_channel_credentials(certs)

        # Channel options matching Go client
        options = [
            ('grpc.ssl_target_name_override', 'localhost'),
            ('grpc.default_authority', 'localhost'),
            #('grpc.use_local_subchannel_pool', 1),
        ]

        # Server endpoint
        server_endpoint = os.getenv('PLUGIN_PYTHON_SERVER_ENDPOINT', 'localhost:50051')
        logger.info(f"🌐 Connecting to server: {server_endpoint}")

        # Create channel with timeout
        logger.info("🔌 Creating gRPC connection...")
        with grpc.secure_channel(server_endpoint, credentials, options=options) as channel:
            # Wait for channel ready with timeout
            try:
                logger.debug("⏳ Waiting for channel ready...")
                grpc.channel_ready_future(channel).result(timeout=5)
                logger.info("✅ Channel ready!")
            except grpc.FutureTimeoutError as e:
                logger.error(f"❌ Channel connection timeout: {e}")
                raise

            # Create client stub
            client = kv_pb2_grpc.KVStub(channel)
            logger.info("👥 Created gRPC client")

            # Send test request
            logger.info("📡 Sending Get request...")
            try:
                response = client.Get(kv_pb2.GetRequest(key="test"))
                print(f"✨ Response: {response.value.decode()} 📄")
                logger.info("✅ Request completed successfully 🎉")
            except grpc.RpcError as e:
                logger.error(f"❌ RPC failed: {e.code()}: {e.details()}")
                raise

    except Exception as e:
        logger.error(f"❌ Error: {str(e)}")
        raise

if __name__ == "__main__":
    main()
