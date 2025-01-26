#!/usr/bin/env python3
#
# server/sqlite_server.py
#

import asyncio
import grpc
from concurrent import futures
import logging
from datetime import datetime
from proto import celersql_pb2, celersql_pb2_grpc
from utils.database import execute_query, execute_update, initialize_schema
from utils.certificate_helper import load_certificates_from_env, log_cert_info
from utils.logging_helper import (
    log_transaction,
    log_request_details,
    log_response_details,
    log_error,
    log_metadata,
    log_certificate_details,
)

# Configure root logger
logger = logging.getLogger(__name__)


class SQLServicer(celersql_pb2_grpc.CelerSQLStoreServicer):
    """
    gRPC Servicer for handling SQLite operations.

    This class provides methods to execute SQL queries and updates
    while logging metadata, transactions, and error details.
    """

    def __init__(self):
        """
        Initialize the SQLServicer with logging and database bootstrapping.
        """
        logger.info("🔧 Initializing SQLServicer.")
        initialize_schema()
        logger.info("✅ Schema initialized successfully.")

    async def ExecuteQuery(self, request, context):
        """
        Handle a gRPC request to execute a SQL query.

        Args:
            request (celersql_pb2.QueryRequest): Query request containing SQL query and parameters.
            context (grpc.aio.ServicerContext): gRPC context object for the request.

        Returns:
            celersql_pb2.QueryResponse: Streamed query results with metadata and rows.
        """
        transaction_id = str(datetime.utcnow().timestamp())
        log_transaction(
            transaction_id=transaction_id,
            client_id=context.peer(),
            request_type="ExecuteQuery",
            status="pending",
            timestamp=datetime.utcnow(),
        )

        log_request_details(
            request_id=transaction_id,
            details={"query": request.query, "params": [param.string_value for param in request.params]},
        )

        try:
            logger.info(f"📝 Processing query: {request.query}")
            rows = execute_query(request.query)
            response = celersql_pb2.QueryResponse()

            if rows:
                response.column_names.extend(rows[0].keys())
                response.column_types.extend([type(value).__name__ for value in rows[0].values()])
                for row in rows:
                    grpc_row = celersql_pb2.Row(values=[self._python_to_param(value) for value in row.values()])
                    response.rows.append(grpc_row)

            log_response_details(
                response_id=transaction_id,
                details={"rows": len(response.rows), "columns": response.column_names},
            )

            log_transaction(
                transaction_id=transaction_id,
                client_id=context.peer(),
                request_type="ExecuteQuery",
                status="success",
                timestamp=datetime.utcnow(),
            )
            return response

        except Exception as e:
            log_error(transaction_id, error_message=str(e))
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            raise

    async def ExecuteUpdate(self, request, context):
        """
        Handle a gRPC request to execute a SQL update/insert/delete.

        Args:
            request (celersql_pb2.UpdateRequest): Update request containing SQL statement and parameters.
            context (grpc.aio.ServicerContext): gRPC context object for the request.

        Returns:
            celersql_pb2.UpdateResponse: Response containing rows affected and last insert ID.
        """
        transaction_id = str(datetime.utcnow().timestamp())
        log_transaction(
            transaction_id=transaction_id,
            client_id=context.peer(),
            request_type="ExecuteUpdate",
            status="pending",
            timestamp=datetime.utcnow(),
        )

        log_request_details(
            request_id=transaction_id,
            details={"query": request.query, "params": [param.string_value for param in request.params]},
        )

        try:
            logger.info(f"📝 Processing update: {request.query}")
            rows_affected = execute_update(request.query)
            response = celersql_pb2.UpdateResponse(rows_affected=rows_affected)

            log_response_details(
                response_id=transaction_id,
                details={"rows_affected": rows_affected},
            )

            log_transaction(
                transaction_id=transaction_id,
                client_id=context.peer(),
                request_type="ExecuteUpdate",
                status="success",
                timestamp=datetime.utcnow(),
            )
            return response

        except Exception as e:
            log_error(transaction_id, error_message=str(e))
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
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


async def serve():
    """
    Starts the gRPC server with SSL credentials and sets up the SQLServicer.
    """
    logger.info("🚀 Starting SQL gRPC Server...")

    try:
        certs = load_certificates_from_env()
        server_credentials = grpc.ssl_server_credentials(
            [(certs["PLUGIN_SERVER_KEY"].encode(), certs["PLUGIN_SERVER_CERT"].encode())],
            root_certificates=certs["PLUGIN_CLIENT_CERT"].encode(),
            require_client_auth=True,
        )
        log_certificate_details(cert=certs["PLUGIN_SERVER_CERT"], prefix="Server Certificate")

    except Exception as e:
        logger.error(f"❌ Failed to load SSL credentials: {e}")
        raise

    server = grpc.aio.server(futures.ThreadPoolExecutor(max_workers=10))
    celersql_pb2_grpc.add_CelerSQLStoreServicer_to_server(SQLServicer(), server)

    try:
        server.add_secure_port("[::]:50051", server_credentials)
        logger.info("🌐 Server bound to port 50051 with SSL.")
    except Exception as e:
        logger.error(f"❌ Failed to bind server port: {e}")
        raise

    await server.start()
    logger.info("✅ SQL Server started successfully.")

    try:
        await server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info("⚠️ Server shutdown initiated.")
        await server.stop(0)


if __name__ == "__main__":
    asyncio.run(serve())
