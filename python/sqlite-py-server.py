#!/usr/bin/env python3

import grpc
import logging
from concurrent import futures
from proto import celersql_pb2, celersql_pb2_grpc
import time
import os
import asyncio
import sqlite3
from certificate_helper import log_cert_info, load_certificates_from_env, load_pem_certificate

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(levelname)s %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class SQLServicer(celersql_pb2_grpc.CelerSQLStoreServicer):
    def __init__(self, db_path='database.db'):
        logger.info("🔧 🚀 Initializing SQLServicer with database: %s", db_path)
        self.db_path = db_path
        self._ensure_db_exists()

    def _ensure_db_exists(self):
        """Ensure database exists and initialize if needed"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                logger.info("📦 Database connection successful")
        except Exception as e:
            logger.error(f"❌ Database initialization error: {e}")
            raise

    async def _log_request_details(self, context):
        """Log gRPC request details"""
        try:
            logger.debug(f"🔎 🌐 Peer: {context.peer()}")
            auth_context = context.auth_context()
            #for k, v in auth_context.items():
            #    logger.debug(f"🔎 🔒 Auth Context {k}: {v}")
            if b"x509_common_name" in auth_context:
                common_name = auth_context[b"x509_common_name"][0].decode()
                logger.info(f"🔑 Client Common Name: {common_name}")
        except Exception as e:
            logger.error(f"🔎 ❌ Logging error: {e}")

    def _get_db(self):
        """Get database connection with error handling"""
        try:
            return sqlite3.connect(self.db_path)
        except Exception as e:
            logger.error(f"❌ Database connection error: {e}")
            raise

    async def ExecuteQuery(self, request, context):
        logger.info(f"📝 Query request: {request.query}")
        await self._log_request_details(context)

        with self._get_db() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(request.query, [param.string_value for param in request.params])

                response = celersql_pb2.QueryResponse()
                if cursor.description:
                    response.column_names.extend([desc[0] for desc in cursor.description])
                    response.column_types.extend([type(desc[1]).__name__ for desc in cursor.description])

                    for row in cursor.fetchall():
                        row_data = celersql_pb2.Row()
                        for value in row:
                            param = self._python_to_param(value)
                            row_data.values.append(param)
                        response.rows.append(row_data)

                response.rows_affected = cursor.rowcount
                logger.info(f"✅ Query executed successfully. Rows affected: {cursor.rowcount}")
                return response

            except Exception as e:
                logger.error(f"❌ Query execution error: {e}")
                context.set_code(grpc.StatusCode.INTERNAL)
                context.set_details(str(e))
                raise

    async def ExecuteUpdate(self, request, context):
        logger.info(f"📝 Update request: {request.query}")
        await self._log_request_details(context)

        with self._get_db() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(request.query, [param.string_value for param in request.params])
                conn.commit()
                
                response = celersql_pb2.UpdateResponse(
                    rows_affected=cursor.rowcount,
                    last_insert_id=cursor.lastrowid
                )
                logger.info(f"✅ Update executed successfully. Rows affected: {cursor.rowcount}")
                return response

            except Exception as e:
                logger.error(f"❌ Update execution error: {e}")
                context.set_code(grpc.StatusCode.INTERNAL)
                context.set_details(str(e))
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

async def serve():
    logger.info("🚀 Starting SQL Server...")

    try:
        certs = load_certificates_from_env()
        server_cert = certs["PLUGIN_SERVER_CERT"]
        server_key = certs["PLUGIN_SERVER_KEY"]
        client_cert = certs.get("PLUGIN_CLIENT_CERT")

        server_credentials = grpc.ssl_server_credentials(
            [(server_key.encode(), server_cert.encode())],
            root_certificates=client_cert.encode() if client_cert else None,
            require_client_auth=True if client_cert else False
        )
        logger.info("🔒 SSL credentials created successfully")

    except Exception as e:
        logger.error(f"🔒 ❌ SSL credentials setup failed: {e}")
        raise

    server = grpc.aio.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ('grpc.ssl_target_name_override', 'localhost'),
            ('grpc.default_authority', 'localhost'),
        ]
    )

    celersql_pb2_grpc.add_CelerSQLStoreServicer_to_server(SQLServicer(), server)

    try:
        server.add_secure_port('[::]:50051', server_credentials)
        logger.info("🌐 Server port bound successfully")
    except Exception as e:
        logger.error(f"🌐 ❌ Port binding failed: {e}")
        raise

    await server.start()
    logger.info("✅ Server started successfully")

    try:
        await server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info("⚠️ Server shutdown initiated")
        await server.stop(0)

if __name__ == '__main__':
    asyncio.run(serve())
