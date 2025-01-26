#
# logging_helper.py
#

import logging
from datetime import datetime
from typing import Any, Dict

# Configure root logger
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(levelname)s %(name)s: %(message)s',
    datefmt='%Y/%m/%d %H:%M:%S',
)
logger = logging.getLogger(__name__)

def log_transaction(
    transaction_id: str,
    client_id: str,
    request_type: str,
    status: str,
    timestamp: datetime,
    message: str = "",
):
    """
    Log a high-level transaction with metadata.
    Args:
        transaction_id (str): Unique transaction identifier.
        client_id (str): Identifier for the client initiating the transaction.
        request_type (str): Type of request (e.g., SQL query, update).
        status (str): Status of the transaction (e.g., pending, success, failed).
        timestamp (datetime): Timestamp of the transaction.
        message (str, optional): Additional context for the transaction.
    """
    logger.info(
        f"📝 Transaction Log | ID: {transaction_id}, Client: {client_id}, "
        f"Type: {request_type}, Status: {status}, Timestamp: {timestamp}, "
        f"Message: {message}"
    )

def log_metadata(metadata: Dict[str, Any], prefix: str = "Metadata"):
    """
    Log structured metadata for debugging or analysis.
    Args:
        metadata (Dict[str, Any]): Key-value pairs of metadata.
        prefix (str, optional): Log prefix for categorization.
    """
    logger.info(f"🔍 {prefix}:")
    for key, value in metadata.items():
        logger.info(f"    - {key}: {value}")

def log_certificate_details(cert, prefix: str = "Certificate"):
    """
    Log detailed certificate information.
    Args:
        cert (x509.Certificate): Certificate object to log.
        prefix (str, optional): Prefix for the log entry.
    """
    try:
        logger.info(f"🔒 {prefix} Details:")
        logger.info(f"    Subject: {cert.subject}")
        logger.info(f"    Issuer: {cert.issuer}")
        logger.info(f"    Valid From: {cert.not_valid_before}")
        logger.info(f"    Valid Until: {cert.not_valid_after}")
        logger.info(f"    Serial Number: {cert.serial_number}")
        logger.info(f"    Signature Algorithm: {cert.signature_algorithm_oid.dotted_string}")
        logger.info(f"    Public Key Algorithm: {cert.public_key().public_bytes()[:20]}... (truncated)")

        # Log extensions if present
        for extension in cert.extensions:
            logger.info(f"    Extension: {extension.oid.dotted_string} - {extension.value}")
    except Exception as e:
        logger.error(f"❌ Error logging certificate: {e}")

def log_error(transaction_id: str, error_message: str, stack_trace: str = None):
    """
    Log an error message with optional stack trace.
    Args:
        transaction_id (str): Related transaction identifier.
        error_message (str): Error message to log.
        stack_trace (str, optional): Stack trace for debugging.
    """
    logger.error(
        f"❌ Error Log | Transaction: {transaction_id}, Message: {error_message}"
    )
    if stack_trace:
        logger.error(f"🔎 Stack Trace:\n{stack_trace}")

def log_request_details(request_id: str, details: Dict[str, Any]):
    """
    Log request details from the client or server.
    Args:
        request_id (str): Unique identifier for the request.
        details (Dict[str, Any]): Metadata and parameters for the request.
    """
    logger.debug(f"📡 Request ID: {request_id} Details:")
    for key, value in details.items():
        logger.debug(f"    - {key}: {value}")

def log_response_details(response_id: str, details: Dict[str, Any]):
    """
    Log response details from the client or server.
    Args:
        response_id (str): Unique identifier for the response.
        details (Dict[str, Any]): Metadata and parameters for the response.
    """
    logger.debug(f"📤 Response ID: {response_id} Details:")
    for key, value in details.items():
        logger.debug(f"    - {key}: {value}")
