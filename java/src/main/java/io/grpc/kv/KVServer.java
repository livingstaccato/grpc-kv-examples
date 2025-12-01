package io.grpc.kv;

import io.grpc.Server;
import io.grpc.netty.shaded.io.grpc.netty.GrpcSslContexts;
import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder;
import io.grpc.netty.shaded.io.netty.handler.ssl.ClientAuth;
import io.grpc.netty.shaded.io.netty.handler.ssl.SslContext;
import io.grpc.netty.shaded.io.netty.handler.ssl.SslContextBuilder;
import io.grpc.stub.StreamObserver;
import proto.KVGrpc;
import proto.Kv;

import javax.net.ssl.SSLSession;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Java gRPC KV Server with mTLS
 *
 * Implements a simple key-value store service with mutual TLS authentication.
 */
public class KVServer {
    private static final Logger logger = Logger.getLogger(KVServer.class.getName());
    private Server server;

    private void start() throws IOException {
        int port = Integer.parseInt(System.getenv().getOrDefault("PLUGIN_PORT", "50051"));

        log("INFO", "Starting gRPC KV Server (Java)");

        // Load certificates from environment
        String serverCertPem = System.getenv("PLUGIN_SERVER_CERT");
        String serverKeyPem = System.getenv("PLUGIN_SERVER_KEY");
        String clientCertPem = System.getenv("PLUGIN_CLIENT_CERT");

        if (serverCertPem == null || serverKeyPem == null) {
            log("ERROR", "Missing required environment variables: PLUGIN_SERVER_CERT, PLUGIN_SERVER_KEY");
            System.exit(1);
        }

        log("INFO", "Loading certificates...");
        log("INFO", "Server cert length: " + serverCertPem.length() + " bytes");
        log("INFO", "Server key length: " + serverKeyPem.length() + " bytes");
        log("INFO", "Client cert length: " + (clientCertPem != null ? clientCertPem.length() : 0) + " bytes");

        // Log certificate details
        logCertificateInfo(serverCertPem, "Server");
        if (clientCertPem != null) {
            logCertificateInfo(clientCertPem, "Client CA");
        }

        try {
            // Build SSL context with mTLS
            SslContextBuilder sslContextBuilder = SslContextBuilder.forServer(
                new ByteArrayInputStream(serverCertPem.getBytes(StandardCharsets.UTF_8)),
                new ByteArrayInputStream(serverKeyPem.getBytes(StandardCharsets.UTF_8))
            );

            if (clientCertPem != null) {
                sslContextBuilder.trustManager(
                    new ByteArrayInputStream(clientCertPem.getBytes(StandardCharsets.UTF_8))
                );
                sslContextBuilder.clientAuth(ClientAuth.REQUIRE);
                log("INFO", "mTLS credentials configured (client auth required)");
            } else {
                sslContextBuilder.clientAuth(ClientAuth.NONE);
                log("INFO", "TLS credentials configured (no client auth)");
            }

            SslContext sslContext = GrpcSslContexts.configure(sslContextBuilder).build();

            // Build and start server
            server = NettyServerBuilder.forPort(port)
                .sslContext(sslContext)
                .addService(new KVServiceImpl())
                .build()
                .start();

            log("INFO", "gRPC KV Server listening on port " + port);
            log("INFO", "Server ready to accept connections");

        } catch (Exception e) {
            log("ERROR", "Failed to start server: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }

        // Add shutdown hook
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            log("INFO", "Shutting down gRPC server...");
            try {
                KVServer.this.stop();
            } catch (InterruptedException e) {
                e.printStackTrace(System.err);
            }
            log("INFO", "Server shut down");
        }));
    }

    private void stop() throws InterruptedException {
        if (server != null) {
            server.shutdown().awaitTermination(30, TimeUnit.SECONDS);
        }
    }

    private void blockUntilShutdown() throws InterruptedException {
        if (server != null) {
            server.awaitTermination();
        }
    }

    private static void log(String level, String message) {
        String timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now());
        System.out.println(timestamp + " [" + level + "]       " + message);
    }

    private static void logCertificateInfo(String certPem, String prefix) {
        try {
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            X509Certificate cert = (X509Certificate) cf.generateCertificate(
                new ByteArrayInputStream(certPem.getBytes(StandardCharsets.UTF_8))
            );

            log("INFO", prefix + " Certificate Details:");
            log("INFO", "  Subject: " + cert.getSubjectX500Principal().getName());
            log("INFO", "  Issuer: " + cert.getIssuerX500Principal().getName());
            log("INFO", "  Valid From: " + cert.getNotBefore());
            log("INFO", "  Valid To: " + cert.getNotAfter());
            log("INFO", "  Serial: " + cert.getSerialNumber().toString(16).toUpperCase());
            log("INFO", "  Algorithm: " + cert.getSigAlgName());
            log("INFO", "  Public Key: " + cert.getPublicKey().getAlgorithm());

        } catch (Exception e) {
            log("WARN", "Failed to parse " + prefix + " certificate: " + e.getMessage());
        }
    }

    /**
     * KV Service implementation
     */
    static class KVServiceImpl extends KVGrpc.KVImplBase {

        @Override
        public void get(Kv.GetRequest request, StreamObserver<Kv.GetResponse> responseObserver) {
            String key = request.getKey();
            log("INFO", "Get request - Key: " + key);

            // Validate request
            if (key == null || key.trim().isEmpty()) {
                log("ERROR", "Get request rejected: empty key");
                responseObserver.onError(
                    io.grpc.Status.INVALID_ARGUMENT
                        .withDescription("key cannot be empty")
                        .asRuntimeException()
                );
                return;
            }

            log("INFO", "Get request completed successfully");
            Kv.GetResponse response = Kv.GetResponse.newBuilder()
                .setValue(com.google.protobuf.ByteString.copyFromUtf8("OK"))
                .build();
            responseObserver.onNext(response);
            responseObserver.onCompleted();
        }

        @Override
        public void put(Kv.PutRequest request, StreamObserver<Kv.Empty> responseObserver) {
            String key = request.getKey();
            log("INFO", "Put request - Key: " + key);

            // Validate request
            if (key == null || key.trim().isEmpty()) {
                log("ERROR", "Put request rejected: empty key");
                responseObserver.onError(
                    io.grpc.Status.INVALID_ARGUMENT
                        .withDescription("key cannot be empty")
                        .asRuntimeException()
                );
                return;
            }

            if (request.getValue().isEmpty()) {
                log("ERROR", "Put request rejected: empty value");
                responseObserver.onError(
                    io.grpc.Status.INVALID_ARGUMENT
                        .withDescription("value cannot be empty")
                        .asRuntimeException()
                );
                return;
            }

            log("INFO", "Put request completed successfully");
            responseObserver.onNext(Kv.Empty.getDefaultInstance());
            responseObserver.onCompleted();
        }
    }

    public static void main(String[] args) throws IOException, InterruptedException {
        final KVServer server = new KVServer();
        server.start();
        server.blockUntilShutdown();
    }
}
