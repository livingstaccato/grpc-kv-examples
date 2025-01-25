#!/usr/bin/env python3

from concurrent import futures
import grpc
import proto.sqlite_pb2 as pb2
import proto.sqlite_pb2_grpc as pb2_grpc

class SQLiteClient:
   def __init__(self, channel):
       self.stub = pb2_grpc.SQLiteStoreStub(channel)

   def execute_query(self, query, params=None):
       request = pb2.QueryRequest(
           query=query,
           params=[self._python_to_param(p) for p in (params or [])]
       )
       response = self.stub.ExecuteQuery(request)
       return self._parse_query_response(response)

   def execute_update(self, query, params=None):
       request = pb2.UpdateRequest(
           query=query, 
           params=[self._python_to_param(p) for p in (params or [])]
       )
       return self.stub.ExecuteUpdate(request)

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

   def _parse_query_response(self, response):
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
           'rows': results,
           'affected': response.rows_affected
       }

def main():
   channel = grpc.secure_channel('localhost:50051', create_channel_credentials())
   client = SQLiteClient(channel)

   # Example queries
   print(client.execute_query("SELECT * FROM users WHERE id = ?", [1]))
   print(client.execute_update("INSERT INTO users (name) VALUES (?)", ["Alice"]))

if __name__ == '__main__':
   main()