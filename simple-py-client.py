#!/usr/bin/env python3

import os
import grpc
import logging
import time
from datetime import datetime, timezone
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from proto import kv_pb2, kv_pb2_grpc

# Configure logging with microsecond precision
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(filename)s:%(lineno)d: %(message)s',
    datefmt='%Y/%m/%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def log_cert_info(cert: x509.Certificate, prefix: str):
    """Log detailed certificate information with emojis"""
    logger.info(f"🔍 {prefix} Certificate Details: 📋")
    logger.info(f"🔍  Subject: {cert.subject} 📝")
    logger.info(f"🔍  Issuer: {cert.issuer} 📝")
    logger.info(f"🔍  Valid From: {cert.not_valid_before_utc} ⏰")
    logger.info(f"🔍  Valid Until: {cert.not_valid_after_utc} ⏰")
    logger.info(f"🔍  Serial Number: {cert.serial_number} 🔢")
    logger.info(f"🔍  Version: {cert.version} 📊")
    
    try:
        key_usage = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.KEY_USAGE)
        logger.info(f"🔍  Key Usage: {key_usage.value} 🔑")
    except x509.ExtensionNotFound:
        logger.warning("⚠️  No Key Usage extension found")

    try:
        ext_key_usage = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.EXTENDED_KEY_USAGE)
        logger.info(f"🔍  Extended Key Usage: {ext_key_usage.value} 🔐")
    except x509.ExtensionNotFound:
        logger.warning("⚠️  No Extended Key Usage extension found")

    try:
        san = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
        if san.value.get_values_for_type(x509.DNSName):
            logger.info(f"🔍  DNS Names: {san.value.get_values_for_type(x509.DNSName)} 🌐")
    except x509.ExtensionNotFound:
        pass

def clean_pem(pem_str: str) -> str:
    """Clean and validate PEM-formatted string"""
    if not pem_str:
        raise ValueError("❌ Empty PEM string provided")
    return '\n'.join(line.strip() for line in pem_str.strip().splitlines())

def load_certificates():
    """Load and validate certificates from environment"""
    logger.info("🔐 Loading certificates from environment...")
    
    required_vars = {
        "PLUGIN_SERVER_CERT": "Server certificate",
        "PLUGIN_CLIENT_CERT": "Client certificate",
        "PLUGIN_CLIENT_KEY": "Client private key"
    }

    certs = {}
    for var, desc in required_vars.items():
        value = os.getenv(var)
        if not value:
            raise ValueError(f"❌ Missing {desc} ({var})")
        certs[var] = clean_pem(value)
        logger.debug(f"📦 Loaded {desc}: {len(certs[var])} bytes")

    return certs

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
    
    # Channel options matching Go client
    options = [
        ('grpc.ssl_target_name_override', 'localhost'),
        ('grpc.default_authority', 'asdf'),
    ]

    return credentials, options

def main():
    try:
        logger.info("🚀 Starting gRPC client... 🌟")
        
        # Load certificates
        certs = load_certificates()
        
        # Create credentials and channel options
        credentials, options = create_channel_credentials(certs)
        
        # Server endpoint
        server_endpoint = os.getenv('PLUGIN_SERVER_ENDPOINT', 'localhost:50051')
        logger.info(f"🌐 Connecting to server: {server_endpoint}")

        # Create channel with timeout
        logger.info("🔌 Creating gRPC connection...")
        channel = grpc.secure_channel(server_endpoint, credentials, options=options)
        
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
    finally:
        try:
            channel.close()
        except:
            pass

if __name__ == "__main__":
    main()