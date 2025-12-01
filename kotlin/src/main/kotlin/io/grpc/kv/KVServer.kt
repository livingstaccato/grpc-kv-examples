package io.grpc.kv

import io.grpc.Server
import io.grpc.ServerBuilder
import io.grpc.netty.shaded.io.grpc.netty.GrpcSslContexts
import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder
import io.grpc.netty.shaded.io.netty.handler.ssl.ClientAuth
import io.grpc.netty.shaded.io.netty.handler.ssl.SslContextBuilder
import proto.KVGrpcKt
import proto.Kv
import java.io.ByteArrayInputStream
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * Kotlin gRPC KV Server with mTLS
 */
class KVService : KVGrpcKt.KVCoroutineImplBase() {

    override suspend fun get(request: Kv.GetRequest): Kv.GetResponse {
        log("INFO", "Get request - Key: ${request.key}")

        if (request.key.isBlank()) {
            log("ERROR", "Get request rejected: empty key")
            throw io.grpc.StatusException(
                io.grpc.Status.INVALID_ARGUMENT.withDescription("key cannot be empty")
            )
        }

        log("INFO", "Get request completed successfully")
        return Kv.GetResponse.newBuilder()
            .setValue(com.google.protobuf.ByteString.copyFromUtf8("OK"))
            .build()
    }

    override suspend fun put(request: Kv.PutRequest): Kv.Empty {
        log("INFO", "Put request - Key: ${request.key}")

        if (request.key.isBlank()) {
            log("ERROR", "Put request rejected: empty key")
            throw io.grpc.StatusException(
                io.grpc.Status.INVALID_ARGUMENT.withDescription("key cannot be empty")
            )
        }

        if (request.value.isEmpty) {
            log("ERROR", "Put request rejected: empty value")
            throw io.grpc.StatusException(
                io.grpc.Status.INVALID_ARGUMENT.withDescription("value cannot be empty")
            )
        }

        log("INFO", "Put request completed successfully")
        return Kv.Empty.getDefaultInstance()
    }
}

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
        log("INFO", "  Algorithm: ${cert.sigAlgName}")
    } catch (e: Exception) {
        log("WARN", "Failed to parse $prefix certificate: ${e.message}")
    }
}

fun main() {
    log("INFO", "Starting gRPC KV Server (Kotlin)")

    val serverCertPem = System.getenv("PLUGIN_SERVER_CERT")
    val serverKeyPem = System.getenv("PLUGIN_SERVER_KEY")
    val clientCertPem = System.getenv("PLUGIN_CLIENT_CERT")

    if (serverCertPem.isNullOrBlank() || serverKeyPem.isNullOrBlank()) {
        log("ERROR", "Missing required environment variables: PLUGIN_SERVER_CERT, PLUGIN_SERVER_KEY")
        System.exit(1)
    }

    log("INFO", "Loading certificates...")
    log("INFO", "Server cert length: ${serverCertPem.length} bytes")
    log("INFO", "Server key length: ${serverKeyPem.length} bytes")
    log("INFO", "Client cert length: ${clientCertPem?.length ?: 0} bytes")

    logCertificateInfo(serverCertPem, "Server")
    clientCertPem?.let { logCertificateInfo(it, "Client CA") }

    val sslContextBuilder = SslContextBuilder.forServer(
        ByteArrayInputStream(serverCertPem.toByteArray()),
        ByteArrayInputStream(serverKeyPem.toByteArray())
    )

    if (!clientCertPem.isNullOrBlank()) {
        sslContextBuilder.trustManager(ByteArrayInputStream(clientCertPem.toByteArray()))
        sslContextBuilder.clientAuth(ClientAuth.REQUIRE)
        log("INFO", "mTLS credentials configured (client auth required)")
    } else {
        sslContextBuilder.clientAuth(ClientAuth.NONE)
        log("INFO", "TLS credentials configured (no client auth)")
    }

    val sslContext = GrpcSslContexts.configure(sslContextBuilder).build()

    val port = System.getenv("PLUGIN_PORT")?.toIntOrNull() ?: 50051

    val server: Server = NettyServerBuilder.forPort(port)
        .sslContext(sslContext)
        .addService(KVService())
        .build()
        .start()

    log("INFO", "gRPC KV Server listening on port $port")
    log("INFO", "Server ready to accept connections")

    Runtime.getRuntime().addShutdownHook(Thread {
        log("INFO", "Shutting down gRPC server...")
        server.shutdown()
        server.awaitTermination(30, TimeUnit.SECONDS)
        log("INFO", "Server shut down")
    })

    server.awaitTermination()
}
