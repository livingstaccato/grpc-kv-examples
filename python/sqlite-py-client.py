#!/usr/bin/env python3

import os
import grpc
import logging
from datetime import datetime, timezone
from cryptography import x509
from proto import celersql_pb2, celersql_pb2_grpc
from certificate_helper import log_cert_info, load_certificates_from_env

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(levelname)s %(name)s: %(message)s',
    datefmt='%Y/%m/%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def create_channel_credentials(certs: dict):
    """Create gRPC channel credentials with detailed logging"""
    logger.info("🔒 Creating channel credentials...")

    server_cert = x509.load_pem_x509_certificate(certs["PLUGIN_SERVER_CERT"].encode())
    client_cert = x509.load_pem_x509_certificate(certs["PLUGIN_CLIENT_CERT"].encode())

    log_cert_info(server_cert, "Server")
    log_cert_info(client_cert, "Client")

    credentials = grpc.ssl_channel_credentials(
        root_certificates=certs["PLUGIN_SERVER_CERT"].encode(),
        private_key=certs["PLUGIN_CLIENT_KEY"].encode(),
        certificate_chain=certs["PLUGIN_CLIENT_CERT"].encode()
    )

    return credentials

class CelerSQLClient:
    def __init__(self, channel):
        self.stub = celersql_pb2_grpc.CelerSQLStoreStub(channel)
        logger.info("👥 Created SQL client stub")

    def execute_query(self, query: str, params=None):
        """Execute a SQL query with detailed logging"""
        logger.info(f"📝 Executing query: {query}")
        try:
            request = celersql_pb2.QueryRequest(query=query)
            if params:
                request.params.extend([self._python_to_param(p) for p in params])

            response = self.stub.ExecuteQuery(request)
            self._log_query_response(response)
            return self._parse_response(response)

        except grpc.RpcError as e:
            logger.error(f"❌ Query execution failed: {e.code()}: {e.details()}")
            raise

    def execute_update(self, query: str, params=None):
        """Execute a SQL update with detailed logging"""
        logger.info(f"📝 Executing update: {query}")
        try:
            # request = celersql_pb2.UpdateRequest(query=query)
            # if params:
            #     request.params.extend([self._python_to_param(p) for p in params])

            request = celersql_pb2.UpdateRequest(
                query="INSERT INTO users (name) VALUES (?)",
                params=[celersql_pb2.Parameter(string_value="Test User")]
            )

            response = self.stub.ExecuteUpdate(request)
            logger.info(f"✅ Update successful. Rows affected: {response.rows_affected}")
            return response.rows_affected

        except grpc.RpcError as e:
            logger.error(f"❌ Update execution failed: {e.code()}: {e.details()}")
            raise

    def _python_to_param(self, value):
        """Convert Python value to Parameter message"""
        param = celersql_pb2.Parameter()
        if isinstance(value, int):
            param.int_value = value
        elif isinstance(value, float):
            param.float_value = value
        elif isinstance(value, str):
            param.string_value = value
        elif isinstance(value, bytes):
            param.blob_value = value
        elif value is None:
            param.null_value = True
        return param

    def _log_query_response(self, response):
        """Log query response details"""
        logger.debug(f"📊 Column names: {response.column_names}")
        logger.debug(f"📊 Column types: {response.column_types}")
        logger.debug(f"📊 Rows affected: {response.rows_affected}")

    def _parse_response(self, response):
        """Parse query response into Python structure"""
        results = []
        for row in response.rows:
            row_data = []
            for value in row.values:
                if value.HasField('int_value'):
                    row_data.append(value.int_value)
                elif value.HasField('float_value'):
                    row_data.append(value.float_value)
                elif value.HasField('string_value'):
                    row_data.append(value.string_value)
                elif value.HasField('blob_value'):
                    row_data.append(value.blob_value)
                else:
                    row_data.append(None)
            results.append(row_data)
        return {
            'columns': list(response.column_names),
            'types': list(response.column_types),
            'rows': results
        }

def main():
    try:
        logger.info("🚀 Starting SQL client...")

        # Load certificates and create credentials
        certs = load_certificates_from_env()
        credentials = create_channel_credentials(certs)

        # Channel options
        options = [
            ('grpc.ssl_target_name_override', 'localhost'),
            ('grpc.default_authority', 'localhost'),
        ]

        # Server endpoint
        server_endpoint = os.getenv('PLUGIN_PYTHON_SERVER_ENDPOINT', 'localhost:50051')
        logger.info(f"🌐 Connecting to server: {server_endpoint}")

        # Create secure channel
        with grpc.secure_channel(server_endpoint, credentials, options=options) as channel:
            try:
                grpc.channel_ready_future(channel).result(timeout=5)
                logger.info("✅ Channel ready")
            except grpc.FutureTimeoutError as e:
                logger.error(f"❌ Channel connection timeout: {e}")
                raise

            # Create client and execute test queries
            client = CelerSQLClient(channel)

            # Example operations
            client.execute_update("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY,
                    name TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            client.execute_update(
                "INSERT INTO users (name) VALUES (?)",
                [celersql_pb2.Parameter(string_value="Test User")]
            )

            result = client.execute_query("SELECT * FROM users")
            logger.info(f"✨ Query result: {result}")

    except Exception as e:
        logger.error(f"❌ Error: {str(e)}")
        raise

if __name__ == "__main__":
    main()
