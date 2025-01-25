import logging
import ssl
from datetime import datetime
from cryptography import x509
from cryptography.hazmat.primitives import serialization

logger = logging.getLogger(__name__)

def log_cert_info(cert: x509.Certificate, prefix: str):
    """Log detailed certificate information with emojis."""
    logger.info(f"🔍 {prefix} Certificate Details: 📋")
    logger.info(f"🔍   Subject: {cert.subject} 📝")
    logger.info(f"🔍   Issuer: {cert.issuer} 📝")
    logger.info(f"🔍   Valid From: {cert.not_valid_before_utc} ⏰")
    logger.info(f"🔍   Valid Until: {cert.not_valid_after_utc} ⏰")
    logger.info(f"🔍   Serial Number: {cert.serial_number} 🔢")
    logger.info(f"🔍   Version: {cert.version} 📊")
    logger.info(f"🔍   Signature Algorithm: {cert.signature_algorithm_oid.dotted_string} ✍️")

    try:
        key_usage = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.KEY_USAGE)
        logger.info(f"🔍   Key Usage: {key_usage.value} 🔑")
    except x509.ExtensionNotFound:
        logger.warning("⚠️   No Key Usage extension found")

    try:
        ext_key_usage = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.EXTENDED_KEY_USAGE)
        logger.info(f"🔍   Extended Key Usage: {ext_key_usage.value} 🔐")
    except x509.ExtensionNotFound:
        logger.warning("⚠️   No Extended Key Usage extension found")

    try:
        san = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
        logger.info(f"🔍   DNS Names: {san.value.get_values_for_type(x509.DNSName)} 🌐")
    except x509.ExtensionNotFound:
        logger.warning("  ⚠️ Subject Alternative Name extension not found.")

    try:
        basic_constraints = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.BASIC_CONSTRAINTS)
        logger.info(f"🔍   Basic Constraints: CA={basic_constraints.value.ca}, Path Length={basic_constraints.value.path_length} 📏")
    except x509.ExtensionNotFound:
        logger.warning("  ⚠️ Basic Constraints extension not found.")

def load_pem_certificate(pem_data: bytes) -> x509.Certificate:
    """Load a certificate from PEM-formatted bytes."""
    try:
        logger.debug("🔧 Loading certificate from PEM data...")
        cert = x509.load_pem_x509_certificate(pem_data)
        return cert
    except Exception as e:
        logger.error(f"❌ Error loading certificate from PEM: {e}")
        raise

def clean_pem(pem_str: str) -> str:
    """Clean and validate PEM-formatted string"""
    if not pem_str:
        raise ValueError("❌ Empty PEM string provided")
    return '\n'.join(line.strip() for line in pem_str.strip().splitlines())

def load_certificates_from_env() -> dict:
    """Load and validate certificates from environment variables."""
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
