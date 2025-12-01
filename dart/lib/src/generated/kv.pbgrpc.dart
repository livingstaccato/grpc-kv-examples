// Generated gRPC service code for KV service

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/grpc.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'kv.pb.dart' as $0;

export 'kv.pb.dart';

class KVClient extends $grpc.Client {
  static final _$get = $grpc.ClientMethod<$0.GetRequest, $0.GetResponse>(
      '/proto.KV/Get',
      ($0.GetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetResponse.fromBuffer(value));
  static final _$put = $grpc.ClientMethod<$0.PutRequest, $0.Empty>(
      '/proto.KV/Put',
      ($0.PutRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Empty.fromBuffer(value));

  KVClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  $grpc.ResponseFuture<$0.GetResponse> get($0.GetRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$get, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> put($0.PutRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$put, request, options: options);
  }
}

abstract class KVServiceBase extends $grpc.Service {
  $core.String get $name => 'proto.KV';

  KVServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetRequest, $0.GetResponse>(
        'Get',
        get_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetRequest.fromBuffer(value),
        ($0.GetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PutRequest, $0.Empty>(
        'Put',
        put_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PutRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetResponse> get_Pre(
      $grpc.ServiceCall call, $async.Future<$0.GetRequest> request) async {
    return get(call, await request);
  }

  $async.Future<$0.Empty> put_Pre(
      $grpc.ServiceCall call, $async.Future<$0.PutRequest> request) async {
    return put(call, await request);
  }

  $async.Future<$0.GetResponse> get($grpc.ServiceCall call, $0.GetRequest request);
  $async.Future<$0.Empty> put($grpc.ServiceCall call, $0.PutRequest request);
}
