package io.grpc.kv;

import io.grpc.ManagedChannel;
import io.grpc.netty.shaded.io.grpc.netty.GrpcSslContexts;
import io.grpc.netty.shaded.io.grpc.netty.NettyChannelBuilder;
import io.grpc.netty.shaded.io.netty.handler.ssl.SslContext;
import io.grpc.netty.shaded.io.netty.handler.ssl.SslContextBuilder;
import proto.KVGrpc;
import proto.Kv;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.TimeUnit;

/**
 * Java gRPC KV Client with mTLS
 *
 * Connects to a KV server using mutual TLS authentication.
 */
public class KVClient {
    private final ManagedChannel channel;
    private final KVGrpc.KVBlockingStub blockingStub;

    public KVClient(String host, int port, SslContext sslContext) {
        channel = NettyChannelBuilder.forAddress(host, port)
            .sslContext(sslContext)
            .overrideAuthority("localhost")
            .build();
        blockingStub = KVGrpc.newBlockingStub(channel);
    }

    public void shutdown() throws InterruptedException {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
    }

    public String get(String key) {
        log("INFO", "Sending Get request - Key: " + key);
        Kv.GetRequest request = Kv.GetRequest.newBuilder().setKey(key).build();

        try {
            Kv.GetResponse response = blockingStub.get(request);
            String value = response.getValue().toStringUtf8();
            log("INFO", "Get response received");
            return value;
        } catch (Exception e) {
            log("ERROR", "Get request failed: " + e.getMessage());
            throw e;
        }
    }

    public void put(String key, byte[] value) {
        log("INFO", "Sending Put request - Key: " + key);
        Kv.PutRequest request = Kv.PutRequest.newBuilder()
            .setKey(key)
            .setValue(com.google.protobuf.ByteString.copyFrom(value))
            .build();

        try {
            blockingStub.put(request);
            log("INFO", "Put request completed successfully");
        } catch (Exception e) {
            log("ERROR", "Put request failed: " + e.getMessage());
            throw e;
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

        } catch (Exception e) {
            log("WARN", "Failed to parse " + prefix + " certificate: " + e.getMessage());
        }
    }

    public static void main(String[] args) throws Exception {
        log("INFO", "Starting gRPC KV Client (Java)");

        // Load certificates from environment
        String clientCertPem = System.getenv("PLUGIN_CLIENT_CERT");
        String clientKeyPem = System.getenv("PLUGIN_CLIENT_KEY");
        String serverCertPem = System.getenv("PLUGIN_SERVER_CERT");

        if (clientCertPem == null || clientKeyPem == null) {
            log("ERROR", "Missing required environment variables: PLUGIN_CLIENT_CERT, PLUGIN_CLIENT_KEY");
            System.exit(1);
        }

        if (serverCertPem == null) {
            log("ERROR", "Missing required environment variable: PLUGIN_SERVER_CERT");
            System.exit(1);
        }

        log("INFO", "Loading certificates...");
        log("INFO", "Client cert length: " + clientCertPem.length() + " bytes");
        log("INFO", "Client key length: " + clientKeyPem.length() + " bytes");
        log("INFO", "Server cert length: " + serverCertPem.length() + " bytes");

        // Log certificate details
        logCertificateInfo(clientCertPem, "Client");
        logCertificateInfo(serverCertPem, "Server");

        // Build SSL context with mTLS
        log("INFO", "Creating SSL context for mTLS...");
        SslContext sslContext = GrpcSslContexts.forClient()
            .keyManager(
                new ByteArrayInputStream(clientCertPem.getBytes(StandardCharsets.UTF_8)),
                new ByteArrayInputStream(clientKeyPem.getBytes(StandardCharsets.UTF_8))
            )
            .trustManager(
                new ByteArrayInputStream(serverCertPem.getBytes(StandardCharsets.UTF_8))
            )
            .build();

        log("INFO", "mTLS credentials configured");

        String host = System.getenv().getOrDefault("PLUGIN_HOST", "localhost");
        int port = Integer.parseInt(System.getenv().getOrDefault("PLUGIN_PORT", "50051"));

        log("INFO", "Connecting to server at " + host + ":" + port + "...");

        KVClient client = new KVClient(host, port, sslContext);

        try {
            // Send Get request
            String response = client.get("test");
            System.out.println("Response: " + response);
            log("INFO", "Request completed successfully");
        } finally {
            client.shutdown();
        }
    }
}
