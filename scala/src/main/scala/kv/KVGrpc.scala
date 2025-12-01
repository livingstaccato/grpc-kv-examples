// Generated gRPC service code for KV service
package kv

import io.grpc._
import io.grpc.stub.{AbstractStub, ClientCalls, ServerCalls, StreamObserver}
import scala.concurrent.{ExecutionContext, Future, Promise}

object KVGrpc {
  val SERVICE: ServiceDescriptor = ServiceDescriptor.newBuilder("proto.KV")
    .addMethod(METHOD_GET)
    .addMethod(METHOD_PUT)
    .build()

  val METHOD_GET: MethodDescriptor[GetRequest, GetResponse] =
    MethodDescriptor.newBuilder[GetRequest, GetResponse]()
      .setType(MethodDescriptor.MethodType.UNARY)
      .setFullMethodName("proto.KV/Get")
      .setRequestMarshaller(new Marshaller[GetRequest] {
        def stream(value: GetRequest): java.io.InputStream = {
          val bytes = new Array[Byte](value.serializedSize)
          val output = com.google.protobuf.CodedOutputStream.newInstance(bytes)
          value.writeTo(output)
          new java.io.ByteArrayInputStream(bytes)
        }
        def parse(stream: java.io.InputStream): GetRequest = {
          GetRequest.parseFrom(com.google.protobuf.CodedInputStream.newInstance(stream))
        }
      })
      .setResponseMarshaller(new Marshaller[GetResponse] {
        def stream(value: GetResponse): java.io.InputStream = {
          val bytes = new Array[Byte](value.serializedSize)
          val output = com.google.protobuf.CodedOutputStream.newInstance(bytes)
          value.writeTo(output)
          new java.io.ByteArrayInputStream(bytes)
        }
        def parse(stream: java.io.InputStream): GetResponse = {
          GetResponse.parseFrom(com.google.protobuf.CodedInputStream.newInstance(stream))
        }
      })
      .build()

  val METHOD_PUT: MethodDescriptor[PutRequest, Empty] =
    MethodDescriptor.newBuilder[PutRequest, Empty]()
      .setType(MethodDescriptor.MethodType.UNARY)
      .setFullMethodName("proto.KV/Put")
      .setRequestMarshaller(new Marshaller[PutRequest] {
        def stream(value: PutRequest): java.io.InputStream = {
          val bytes = new Array[Byte](value.serializedSize)
          val output = com.google.protobuf.CodedOutputStream.newInstance(bytes)
          value.writeTo(output)
          new java.io.ByteArrayInputStream(bytes)
        }
        def parse(stream: java.io.InputStream): PutRequest = {
          PutRequest.parseFrom(com.google.protobuf.CodedInputStream.newInstance(stream))
        }
      })
      .setResponseMarshaller(new Marshaller[Empty] {
        def stream(value: Empty): java.io.InputStream = {
          val bytes = new Array[Byte](value.serializedSize)
          val output = com.google.protobuf.CodedOutputStream.newInstance(bytes)
          value.writeTo(output)
          new java.io.ByteArrayInputStream(bytes)
        }
        def parse(stream: java.io.InputStream): Empty = {
          Empty.parseFrom(com.google.protobuf.CodedInputStream.newInstance(stream))
        }
      })
      .build()

  trait KV {
    def get(request: GetRequest): Future[GetResponse]
    def put(request: PutRequest): Future[Empty]
  }

  abstract class KVImplBase extends BindableService {
    def get(request: GetRequest): Future[GetResponse]
    def put(request: PutRequest): Future[Empty]

    override def bindService(): ServerServiceDefinition = {
      implicit val ec: ExecutionContext = ExecutionContext.global
      ServerServiceDefinition.builder(SERVICE)
        .addMethod(METHOD_GET, ServerCalls.asyncUnaryCall(
          new ServerCalls.UnaryMethod[GetRequest, GetResponse] {
            def invoke(request: GetRequest, observer: StreamObserver[GetResponse]): Unit = {
              get(request).onComplete {
                case scala.util.Success(response) =>
                  observer.onNext(response)
                  observer.onCompleted()
                case scala.util.Failure(e) =>
                  observer.onError(e)
              }
            }
          }
        ))
        .addMethod(METHOD_PUT, ServerCalls.asyncUnaryCall(
          new ServerCalls.UnaryMethod[PutRequest, Empty] {
            def invoke(request: PutRequest, observer: StreamObserver[Empty]): Unit = {
              put(request).onComplete {
                case scala.util.Success(response) =>
                  observer.onNext(response)
                  observer.onCompleted()
                case scala.util.Failure(e) =>
                  observer.onError(e)
              }
            }
          }
        ))
        .build()
    }
  }

  class KVStub(channel: Channel, options: CallOptions = CallOptions.DEFAULT)
      extends AbstractStub[KVStub](channel, options) with KV {

    override def build(channel: Channel, options: CallOptions): KVStub =
      new KVStub(channel, options)

    override def get(request: GetRequest): Future[GetResponse] = {
      val promise = Promise[GetResponse]()
      ClientCalls.asyncUnaryCall(
        channel.newCall(METHOD_GET, options),
        request,
        new StreamObserver[GetResponse] {
          def onNext(value: GetResponse): Unit = promise.success(value)
          def onError(t: Throwable): Unit = promise.failure(t)
          def onCompleted(): Unit = ()
        }
      )
      promise.future
    }

    override def put(request: PutRequest): Future[Empty] = {
      val promise = Promise[Empty]()
      ClientCalls.asyncUnaryCall(
        channel.newCall(METHOD_PUT, options),
        request,
        new StreamObserver[Empty] {
          def onNext(value: Empty): Unit = promise.success(value)
          def onError(t: Throwable): Unit = promise.failure(t)
          def onCompleted(): Unit = ()
        }
      )
      promise.future
    }
  }

  def stub(channel: Channel): KVStub = new KVStub(channel)
}
