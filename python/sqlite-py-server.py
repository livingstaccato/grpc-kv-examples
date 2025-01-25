#!/usr/bin/env python3

import sqlite3
from concurrent import futures
import grpc
import proto.sqlite_pb2 as pb2
import proto.sqlite_pb2_grpc as pb2_grpc

class SQLiteService(pb2_grpc.SQLiteStoreServicer):
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return sqlite3.connect(self.db_path)

    def _param_to_python(self, param):
        if param.HasField('int_value'):
            return param.int_value
        elif param.HasField('float_value'):
            return param.float_value
        elif param.HasField('string_value'):
            return param.string_value
        elif param.HasField('blob_value'):
            return param.blob_value
        return None

    def _python_to_param(self, value):
        param = pb2.Parameter()
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

    def ExecuteQuery(self, request, context):
        with self._get_db() as conn:
            cursor = conn.cursor()
            params = [self._param_to_python(p) for p in request.params]
            cursor.execute(request.query, params)

            response = pb2.QueryResponse()
            response.column_names.extend([desc[0] for desc in cursor.description])
            response.column_types.extend([type(desc[1]).__name__ for desc in cursor.description])

            for row in cursor.fetchall():
                row_set = pb2.RowSet()
                row_set.values.extend([self._python_to_param(value) for value in row])
                response.rows.append(row_set)

            response.rows_affected = cursor.rowcount
            return response

    def ExecuteUpdate(self, request, context):
        with self._get_db() as conn:
            cursor = conn.cursor()
            params = [self._param_to_python(p) for p in request.params]
            cursor.execute(request.query, params)
            conn.commit()

            return pb2.UpdateResponse(
                rows_affected=cursor.rowcount,
                last_insert_id=cursor.lastrowid
            )

    def BatchExecute(self, request, context):
        response = pb2.BatchResponse()
        with self._get_db() as conn:
            cursor = conn.cursor()
            for query_request in request.queries:
                params = [self._param_to_python(p) for p in query_request.params]
                cursor.execute(query_request.query, params)

                query_response = pb2.QueryResponse()
                if cursor.description:
                    query_response.column_names.extend([desc[0] for desc in cursor.description])
                    query_response.column_types.extend([type(desc[1]).__name__ for desc in cursor.description])

                    for row in cursor.fetchall():
                        row_set = pb2.RowSet()
                        row_set.values.extend([self._python_to_param(value) for value in row])
                        query_response.rows.append(row_set)

                query_response.rows_affected = cursor.rowcount
                response.results.append(query_response)
            conn.commit()
        return response

    def GetSchema(self, request, context):
        with self._get_db() as conn:
            cursor = conn.cursor()
            cursor.execute(f"PRAGMA table_info({request.table_name})")

            response = pb2.SchemaResponse()
            for row in cursor.fetchall():
                column = pb2.ColumnInfo(
                    name=row[1],
                    type=row[2],
                    nullable=not row[3],
                    primary_key=bool(row[5])
                )
                response.columns.append(column)
            return response

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    pb2_grpc.add_SQLiteStoreServicer_to_server(SQLiteService('database.db'), server)
    server.add_insecure_port('[::]:50051')
    server.start()
    server.wait_for_termination()

if __name__ == '__main__':
    serve()
