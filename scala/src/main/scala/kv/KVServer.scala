/**
 * Scala gRPC KV Server with mTLS
 *
 * Implements a simple key-value store service with mutual TLS authentication.
 * Uses grpc-java with Netty for TLS support.
 */
package kv

import com.google.protobuf.ByteString
import io.grpc._
import io.grpc.netty.{GrpcSslContexts, NettyServerBuilder}
import io.netty.handler.ssl.{ClientAuth, SslContext, SslContextBuilder}

import java.io.{ByteArrayInputStream, StringReader}
import java.time.Instant
import scala.collection.mutable
import scala.concurrent.{ExecutionContext, Future}
import scala.io.Source

object KVServer {
  implicit val ec: ExecutionContext = ExecutionContext.global

  def log(level: String, message: String): Unit = {
    val timestamp = Instant.now().toString
    System.err.println(s"$timestamp [$level]     $message")
  }

  class KVServiceImpl extends KVGrpc.KVImplBase {
    private val store = mutable.Map[String, Array[Byte]]()

    override def get(request: GetRequest): Future[GetResponse] = Future {
      val key = request.key
      log("INFO", s"Get request - Key: $key")

      if (key.isEmpty) {
        log("ERROR", "Get request rejected: empty key")
        throw Status.INVALID_ARGUMENT.withDescription("key cannot be empty").asRuntimeException()
      }

      log("INFO", "Get request completed successfully")
      GetResponse(ByteString.copyFromUtf8("OK"))
    }

    override def put(request: PutRequest): Future[Empty] = Future {
      val key = request.key
      val value = request.value
      log("INFO", s"Put request - Key: $key")

      if (key.isEmpty) {
        log("ERROR", "Put request rejected: empty key")
        throw Status.INVALID_ARGUMENT.withDescription("key cannot be empty").asRuntimeException()
      }
      if (value.isEmpty) {
        log("ERROR", "Put request rejected: empty value")
        throw Status.INVALID_ARGUMENT.withDescription("value cannot be empty").asRuntimeException()
      }

      store(key) = value.toByteArray
      log("INFO", "Put request completed successfully")
      Empty()
    }
  }

  def main(args: Array[String]): Unit = {
    log("INFO", "Starting gRPC KV Server (Scala)")

    // Load certificates from environment
    val serverCert = Option(System.getenv("PLUGIN_SERVER_CERT")).getOrElse {
      log("ERROR", "Missing required environment variable: PLUGIN_SERVER_CERT")
      System.exit(1)
      ""
    }
    val serverKey = Option(System.getenv("PLUGIN_SERVER_KEY")).getOrElse {
      log("ERROR", "Missing required environment variable: PLUGIN_SERVER_KEY")
      System.exit(1)
      ""
    }
    val clientCert = Option(System.getenv("PLUGIN_CLIENT_CERT"))

    log("INFO", "Loading certificates...")
    log("INFO", s"Server cert length: ${serverCert.length} bytes")
    log("INFO", s"Server key length: ${serverKey.length} bytes")
    log("INFO", s"Client cert length: ${clientCert.map(_.length).getOrElse(0)} bytes")

    val port = Option(System.getenv("PLUGIN_PORT")).map(_.toInt).getOrElse(50051)

    try {
      // Build SSL context
      var sslContextBuilder = SslContextBuilder.forServer(
        new ByteArrayInputStream(serverCert.getBytes("UTF-8")),
        new ByteArrayInputStream(serverKey.getBytes("UTF-8"))
      )

      clientCert.foreach { ca =>
        sslContextBuilder = sslContextBuilder
          .trustManager(new ByteArrayInputStream(ca.getBytes("UTF-8")))
          .clientAuth(ClientAuth.REQUIRE)
        log("INFO", "mTLS configured (client auth required)")
      }

      val sslContext = GrpcSslContexts.configure(sslContextBuilder).build()

      // Create and start server
      val server = NettyServerBuilder.forPort(port)
        .sslContext(sslContext)
        .addService(new KVServiceImpl())
        .build()
        .start()

      log("INFO", s"gRPC KV Server listening on 0.0.0.0:$port")
      log("INFO", "Server ready to accept connections")

      // Shutdown hook
      Runtime.getRuntime.addShutdownHook(new Thread(() => {
        log("INFO", "Received shutdown signal...")
        server.shutdown()
        log("INFO", "Server shutdown complete")
      }))

      server.awaitTermination()
    } catch {
      case e: Exception =>
        log("ERROR", s"Failed to start server: ${e.getMessage}")
        e.printStackTrace()
        System.exit(1)
    }
  }
}
