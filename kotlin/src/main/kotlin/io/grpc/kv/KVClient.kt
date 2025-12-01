package io.grpc.kv

import io.grpc.ManagedChannel
import io.grpc.netty.shaded.io.grpc.netty.GrpcSslContexts
import io.grpc.netty.shaded.io.grpc.netty.NettyChannelBuilder
import kotlinx.coroutines.runBlocking
import proto.KVGrpcKt
import proto.Kv
import java.io.ByteArrayInputStream
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * Kotlin gRPC KV Client with mTLS
 */

fun log(level: String, message: String) {
    val timestamp = Instant.now().toString()
    println("$timestamp [$level]       $message")
}

fun logCertificateInfo(certPem: String, prefix: String) {
    try {
        val cf = CertificateFactory.getInstance("X.509")
        val cert = cf.generateCertificate(
            ByteArrayInputStream(certPem.toByteArray())
        ) as X509Certificate

        log("INFO", "$prefix Certificate Details:")
        log("INFO", "  Subject: ${cert.subjectX500Principal.name}")
        log("INFO", "  Issuer: ${cert.issuerX500Principal.name}")
        log("INFO", "  Valid From: ${cert.notBefore}")
        log("INFO", "  Valid To: ${cert.notAfter}")
        log("INFO", "  Serial: ${cert.serialNumber.toString(16).uppercase()}")
    } catch (e: Exception) {
        log("WARN", "Failed to parse $prefix certificate: ${e.message}")
    }
}

fun main() = runBlocking {
    log("INFO", "Starting gRPC KV Client (Kotlin)")

    val clientCertPem = System.getenv("PLUGIN_CLIENT_CERT")
    val clientKeyPem = System.getenv("PLUGIN_CLIENT_KEY")
    val serverCertPem = System.getenv("PLUGIN_SERVER_CERT")

    if (clientCertPem.isNullOrBlank() || clientKeyPem.isNullOrBlank()) {
        log("ERROR", "Missing required environment variables: PLUGIN_CLIENT_CERT, PLUGIN_CLIENT_KEY")
        System.exit(1)
    }

    if (serverCertPem.isNullOrBlank()) {
        log("ERROR", "Missing required environment variable: PLUGIN_SERVER_CERT")
        System.exit(1)
    }

    log("INFO", "Loading certificates...")
    log("INFO", "Client cert length: ${clientCertPem.length} bytes")
    log("INFO", "Client key length: ${clientKeyPem.length} bytes")
    log("INFO", "Server cert length: ${serverCertPem.length} bytes")

    logCertificateInfo(clientCertPem, "Client")
    logCertificateInfo(serverCertPem, "Server")

    log("INFO", "Creating SSL context for mTLS...")
    val sslContext = GrpcSslContexts.forClient()
        .keyManager(
            ByteArrayInputStream(clientCertPem.toByteArray()),
            ByteArrayInputStream(clientKeyPem.toByteArray())
        )
        .trustManager(
            ByteArrayInputStream(serverCertPem.toByteArray())
        )
        .build()

    log("INFO", "mTLS credentials configured")

    val host = System.getenv("PLUGIN_HOST") ?: "localhost"
    val port = System.getenv("PLUGIN_PORT")?.toIntOrNull() ?: 50051

    log("INFO", "Connecting to server at $host:$port...")

    val channel: ManagedChannel = NettyChannelBuilder.forAddress(host, port)
        .sslContext(sslContext)
        .overrideAuthority("localhost")
        .build()

    try {
        val stub = KVGrpcKt.KVCoroutineStub(channel)

        log("INFO", "Sending Get request...")
        val request = Kv.GetRequest.newBuilder().setKey("test").build()

        val response = stub.get(request)
        val value = response.value.toStringUtf8()

        println("Response: $value")
        log("INFO", "Request completed successfully")

    } catch (e: Exception) {
        log("ERROR", "Request failed: ${e.message}")
        System.exit(1)
    } finally {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS)
    }
}
