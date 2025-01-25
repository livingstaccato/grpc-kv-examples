#!/usr/bin/env python3
import grpc
from certificate_helper import load_certificates_from_env
import proto.sqlite_pb2 as pb2
import proto.sqlite_pb2_grpc as pb2_grpc

def create_channel_credentials():
    certs = load_certificates_from_env()
    return grpc.ssl_channel_credentials(
        root_certificates=certs["PLUGIN_SERVER_CERT"].encode(),
        private_key=certs["PLUGIN_CLIENT_KEY"].encode(),
        certificate_chain=certs["PLUGIN_CLIENT_CERT"].encode()
    )


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
    channel_creds = create_channel_credentials()
    options = [
        ('grpc.ssl_target_name_override', 'localhost'),
        ('grpc.default_authority', 'localhost')
    ]
    #channel = grpc.secure_channel('localhost:50051', channel_creds, options=options)
    channel = grpc.insecure_channel('[::]:50051')
    client = SQLiteClient(channel)

    print("Let's add a test user first")
    client.execute_update("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)")
    client.execute_update("INSERT INTO users (name) VALUES (?)", ["Test User"])

    # Now try querying
    print("\nNow querying:")
    print(client.execute_query("SELECT * FROM users"))

    # Example queries
    #print(client.execute_query("SELECT * FROM users WHERE id = ?", [1]))
    print(client.execute_update("INSERT INTO users (name) VALUES (?)", ["Alice"]))

if __name__ == '__main__':
    main()
