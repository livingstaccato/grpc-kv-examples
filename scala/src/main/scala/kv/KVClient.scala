/**
 * Scala gRPC KV Client with mTLS
 *
 * Implements a gRPC client for the KV service with mutual TLS authentication.
 * Uses grpc-java with Netty for TLS support.
 */
package kv

import com.google.protobuf.ByteString
import io.grpc._
import io.grpc.netty.{GrpcSslContexts, NettyChannelBuilder}
import io.netty.handler.ssl.SslContextBuilder

import java.io.ByteArrayInputStream
import java.time.Instant
import scala.concurrent.{Await, ExecutionContext}
import scala.concurrent.duration._

object KVClient {
  implicit val ec: ExecutionContext = ExecutionContext.global

  def log(level: String, message: String): Unit = {
    val timestamp = Instant.now().toString
    System.err.println(s"$timestamp [$level]     $message")
  }

  def main(args: Array[String]): Unit = {
    log("INFO", "Starting gRPC KV Client (Scala)")

    // Load certificates from environment
    val serverCert = Option(System.getenv("PLUGIN_SERVER_CERT")).getOrElse {
      log("ERROR", "Missing required environment variable: PLUGIN_SERVER_CERT")
      System.exit(1)
      ""
    }
    val clientCert = Option(System.getenv("PLUGIN_CLIENT_CERT"))
    val clientKey = Option(System.getenv("PLUGIN_CLIENT_KEY"))

    log("INFO", "Loading certificates...")
    log("INFO", s"Server cert length: ${serverCert.length} bytes")
    log("INFO", s"Client cert length: ${clientCert.map(_.length).getOrElse(0)} bytes")
    log("INFO", s"Client key length: ${clientKey.map(_.length).getOrElse(0)} bytes")

    val host = Option(System.getenv("PLUGIN_HOST")).getOrElse("localhost")
    val port = Option(System.getenv("PLUGIN_PORT")).map(_.toInt).getOrElse(50051)
    val address = s"$host:$port"

    log("INFO", s"Connecting to $address")

    try {
      // Build SSL context
      var sslContextBuilder = SslContextBuilder.forClient()
        .trustManager(new ByteArrayInputStream(serverCert.getBytes("UTF-8")))

      (clientCert, clientKey) match {
        case (Some(cert), Some(key)) =>
          sslContextBuilder = sslContextBuilder.keyManager(
            new ByteArrayInputStream(cert.getBytes("UTF-8")),
            new ByteArrayInputStream(key.getBytes("UTF-8"))
          )
          log("INFO", "mTLS credentials configured")
        case _ =>
          log("INFO", "TLS credentials configured (no client auth)")
      }

      val sslContext = GrpcSslContexts.configure(sslContextBuilder).build()

      // Create channel
      val channel = NettyChannelBuilder.forAddress(host, port)
        .sslContext(sslContext)
        .overrideAuthority("localhost")
        .build()

      val client = KVGrpc.stub(channel)

      // Test Get operation
      log("INFO", "Sending Get request...")
      val getRequest = GetRequest(key = "test-key")
      val getResponse = Await.result(client.get(getRequest), 30.seconds)
      log("INFO", s"Get response: ${getResponse.value.toStringUtf8}")

      // Test Put operation
      log("INFO", "Sending Put request...")
      val putRequest = PutRequest(
        key = "test-key",
        value = ByteString.copyFromUtf8("test-value")
      )
      Await.result(client.put(putRequest), 30.seconds)
      log("INFO", "Put request successful")

      channel.shutdown()

      log("INFO", "All operations completed successfully")
      println("OK")
      System.exit(0)
    } catch {
      case e: Exception =>
        log("ERROR", s"Client error: ${e.getMessage}")
        e.printStackTrace()
        System.exit(1)
    }
  }
}
