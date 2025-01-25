#!/usr/bin/env python3

import grpc
import logging
from concurrent import futures
from proto import kv_pb2, kv_pb2_grpc
import time
import os
import ssl
from  cryptography import x509
from cryptography.hazmat.primitives import serialization

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

            # Try to get peer certificate details
            peer_cert = context.peer_certificate()
            if peer_cert:
                logger.debug("  🔐 Peer Certificate (PEM):\n%s", peer_cert.decode())
                x509_cert = x509.load_pem_x509_certificate(peer_cert)
                logger.debug("  🔍 Peer Certificate Details:")
                self._log_cert_details(x509_cert)
            else:
                logger.warning("  ⚠️ No peer certificate found.")

            logger.debug("  🔒 Metadata:")
            for k, v in context.invocation_metadata():
                logger.debug(f"      {k}: {v}")

        except Exception as e:
            logger.error(f"  ❌ Logging error: {e}")

    def _log_cert_details(self, cert: x509.Certificate):
        logger.debug(f"    Subject: {cert.subject}")
        logger.debug(f"    Issuer: {cert.issuer}")
        logger.debug(f"    Valid From: {cert.not_valid_before_utc}")
        logger.debug(f"    Valid Until: {cert.not_valid_after_utc}")
        logger.debug(f"    Serial Number: {cert.serial_number}")
        logger.debug(f"    Version: {cert.version}")
        logger.debug(f"    Signature Algorithm: {cert.signature_algorithm_oid.dotted_string}")
        logger.debug(f"    Signature: {cert.signature.hex()}")
        logger.debug(f"    Public Key: {cert.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()}")

        # Log Key Usage extension
        try:
            key_usage = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.KEY_USAGE)
            logger.debug(f"    Key Usage: {key_usage.value}")
        except x509.ExtensionNotFound:
            logger.warning("    Key Usage extension not found.")

        # Log Extended Key Usage extension
        try:
            ext_key_usage = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.EXTENDED_KEY_USAGE)
            logger.debug(f"    Extended Key Usage: {ext_key_usage.value}")
        except x509.ExtensionNotFound:
            logger.warning("    Extended Key Usage extension not found.")

        # Log Subject Alternative Name extension
        try:
            san = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
            logger.debug(f"    Subject Alternative Name: {san.value.get_values_for_type(x509.DNSName)}")
        except x509.ExtensionNotFound:
            logger.debug("    Subject Alternative Name extension not found.")
        
        # Log Basic Constraints extension
        try:
            basic_constraints = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.BASIC_CONSTRAINTS)
            logger.debug(f"    Basic Constraints: CA={basic_constraints.value.ca}, Path Length={basic_constraints.value.path_length}")
        except x509.ExtensionNotFound:
            logger.debug("    Basic Constraints extension not found.")

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
