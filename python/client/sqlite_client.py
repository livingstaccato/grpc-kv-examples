#!/usr/bin/env python3
#
# client/sqlite_client.py
#

import grpc
import logging
from datetime import datetime, timezone
from proto import celersql_pb2, celersql_pb2_grpc
from utils.certificate_helper import load_certificates_from_env, log_cert_info
from utils.logging_helper import (
    log_transaction,
    log_request_details,
    log_response_details,
    log_error,
)

# Configure root logger
logger = logging.getLogger(__name__)

class CelerSQLClient:
    """
    Client for interacting with the CelerSQL gRPC Server.
    """

    def __init__(self, server_endpoint: str):
        """
        Initialize the client with a secure gRPC channel.

        Args:
            server_endpoint (str): The server address (e.g., 'localhost:50051').
        """
        self.server_endpoint = server_endpoint
        self.stub = None

        try:
            logger.info("🔧 Setting up CelerSQL client...")
            certs = load_certificates_from_env()
            credentials = grpc.ssl_channel_credentials(
                root_certificates=certs["PLUGIN_SERVER_CERT"].encode(),
                private_key=certs["PLUGIN_CLIENT_KEY"].encode(),
                certificate_chain=certs["PLUGIN_CLIENT_CERT"].encode(),
            )

            # Logging parsed certificates
            if "PLUGIN_SERVER_CERT_OBJ" in certs:
                log_cert_info(certs["PLUGIN_SERVER_CERT_OBJ"], "Server Certificate")
            if "PLUGIN_CLIENT_CERT_OBJ" in certs:
                log_cert_info(certs["PLUGIN_CLIENT_CERT_OBJ"], "Client Certificate")


            self.channel = grpc.secure_channel(
                server_endpoint,
                credentials,
                options=[
                    ("grpc.ssl_target_name_override", "localhost"),
                    ("grpc.default_authority", "localhost"),
                ],
            )
            grpc.channel_ready_future(self.channel).result(timeout=5)
            logger.info("✅ gRPC channel established successfully.")

            self.stub = celersql_pb2_grpc.CelerSQLStoreStub(self.channel)
            logger.info("✅ CelerSQL client stub created.")
        except Exception as e:
            logger.error(f"❌ Failed to initialize client: {e}")
            raise

    def execute_query(self, query: str, params: list = None) -> dict:
        """
        Execute a SQL query on the server and retrieve results.

        Args:
            query (str): SQL query string.
            params (list, optional): List of parameters for the query.

        Returns:
            dict: A dictionary containing column names, types, and rows.
        """
        transaction_id = str(datetime.now(timezone.utc).timestamp())
        log_transaction(
            transaction_id=transaction_id,
            client_id="sqlite_client",
            request_type="ExecuteQuery",
            status="pending",
            timestamp=datetime.now(timezone.utc),
        )

        log_request_details(
            request_id=transaction_id,
            details={"query": query, "params": params or []},
        )

        try:
            logger.info(f"📝 Sending query request: {query}")
            request = celersql_pb2.QueryRequest(query=query)
            if params:
                request.params.extend([self._python_to_param(p) for p in params])

            response = self.stub.ExecuteQuery(request)
            results = []
            metadata = None

            for batch in response:
                if not metadata:
                    metadata = {
                        "columns": list(batch.column_names),
                        "types": list(batch.column_types),
                    }
                    logger.debug(f"📊 Metadata: {metadata}")

                results.extend(self._parse_rows(batch.rows))

            log_response_details(
                response_id=transaction_id,
                details={"columns": metadata["columns"], "rows": len(results)},
            )

            log_transaction(
                transaction_id=transaction_id,
                client_id="sqlite_client",
                request_type="ExecuteQuery",
                status="success",
                timestamp=datetime.now(timezone.utc),
            )

            return {
                "columns": metadata["columns"],
                "types": metadata["types"],
                "rows": results,
            }
        except grpc.RpcError as e:
            log_error(
                transaction_id,
                error_message=f"{e.code()}: {e.details()}",
            )
            raise

    def execute_update(self, query: str, params: list = None) -> int:
        """
        Execute a SQL update on the server.

        Args:
            query (str): SQL update string.
            params (list, optional): List of parameters for the update.

        Returns:
            int: Number of rows affected by the update.
        """
        transaction_id = str(datetime.now(timezone.utc).timestamp())
        log_transaction(
            transaction_id=transaction_id,
            client_id="sqlite_client",
            request_type="ExecuteUpdate",
            status="pending",
            timestamp=datetime.now(timezone.utc),
        )

        log_request_details(
            request_id=transaction_id,
            details={"query": query, "params": params or []},
        )

        try:
            logger.info(f"📝 Sending update request: {query}")
            request = celersql_pb2.UpdateRequest(query=query)
            if params:
                request.params.extend([self._python_to_param(p) for p in params])

            response = self.stub.ExecuteUpdate(request)
            logger.info(f"✅ Update successful. Rows affected: {response.rows_affected}")

            log_response_details(
                response_id=transaction_id,
                details={"rows_affected": response.rows_affected},
            )

            log_transaction(
                transaction_id=transaction_id,
                client_id="sqlite_client",
                request_type="ExecuteUpdate",
                status="success",
                timestamp=datetime.now(timezone.utc),
            )

            return response.rows_affected
        except grpc.RpcError as e:
            log_error(
                transaction_id,
                error_message=f"{e.code()}: {e.details()}",
            )
            raise

    def _python_to_param(self, value):
        """
        Convert a Python value to a gRPC Parameter message.

        Args:
            value (Any): Python value to convert.

        Returns:
            celersql_pb2.Parameter: Converted gRPC Parameter message.
        """
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

    def _parse_rows(self, rows):
        """
        Parse rows from gRPC response into a Python structure.

        Args:
            rows (list): List of gRPC Row messages.

        Returns:
            list: Parsed rows as a list of dictionaries.
        """
        return [[self._param_to_python(value) for value in row.values] for row in rows]

    def _param_to_python(self, value):
        """
        Convert a gRPC Parameter message to a Python value.

        Args:
            value (celersql_pb2.Parameter): gRPC Parameter message.

        Returns:
            Any: Python representation of the value.
        """
        if value.HasField("int_value"):
            return value.int_value
        elif value.HasField("float_value"):
            return value.float_value
        elif value.HasField("string_value"):
            return value.string_value
        elif value.HasField("blob_value"):
            return value.blob_value
        return None


if __name__ == "__main__":
    try:
        logger.info("🚀 Starting SQLite client...")
        client = CelerSQLClient("localhost:50051")

        # Example operations
        client.execute_update(
            "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)"
        )
        client.execute_update(
            "INSERT INTO users (name) VALUES (?)", ["Test User"]
        )
        result = client.execute_query("SELECT * FROM users")
        logger.info(f"✨ Query result: {result}")
    except Exception as e:
        logger.error(f"❌ Client error: {e}")
