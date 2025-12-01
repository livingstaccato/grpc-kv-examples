import Foundation
import GRPC
import NIO
import NIOSSL
import Logging

/// Swift gRPC KV Server with mTLS
///
/// Implements a simple key-value store service with mutual TLS authentication.

// Logger setup
let logger = Logger(label: "io.grpc.kv.server")

/// KV Service Implementation
final class KVServiceProvider: KVProvider {
    var interceptors: KVServerInterceptorFactoryProtocol? { nil }

    func get(request: GetRequest, context: StatusOnlyCallContext) -> EventLoopFuture<GetResponse> {
        log("INFO", "Get request - Key: \(request.key)")

        // Validate request
        guard !request.key.isEmpty else {
            log("ERROR", "Get request rejected: empty key")
            return context.eventLoop.makeFailedFuture(
                GRPCStatus(code: .invalidArgument, message: "key cannot be empty")
            )
        }

        log("INFO", "Get request completed successfully")
        var response = GetResponse()
        response.value = Data("OK".utf8)
        return context.eventLoop.makeSucceededFuture(response)
    }

    func put(request: PutRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Empty> {
        log("INFO", "Put request - Key: \(request.key)")

        // Validate request
        guard !request.key.isEmpty else {
            log("ERROR", "Put request rejected: empty key")
            return context.eventLoop.makeFailedFuture(
                GRPCStatus(code: .invalidArgument, message: "key cannot be empty")
            )
        }

        guard !request.value.isEmpty else {
            log("ERROR", "Put request rejected: empty value")
            return context.eventLoop.makeFailedFuture(
                GRPCStatus(code: .invalidArgument, message: "value cannot be empty")
            )
        }

        log("INFO", "Put request completed successfully")
        return context.eventLoop.makeSucceededFuture(Empty())
    }
}

/// Simple logging function
func log(_ level: String, _ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("\(timestamp) [\(level)]       \(message)")
}

/// Load certificate data from environment or file
func loadCertificate(_ envVar: String) -> String? {
    if let value = ProcessInfo.processInfo.environment[envVar], !value.isEmpty {
        return value
    }
    return nil
}

@main
struct KVServer {
    static func main() throws {
        log("INFO", "Starting gRPC KV Server (Swift)")

        // Load certificates from environment
        guard let serverCertPEM = loadCertificate("PLUGIN_SERVER_CERT") else {
            log("ERROR", "Missing PLUGIN_SERVER_CERT environment variable")
            exit(1)
        }

        guard let serverKeyPEM = loadCertificate("PLUGIN_SERVER_KEY") else {
            log("ERROR", "Missing PLUGIN_SERVER_KEY environment variable")
            exit(1)
        }

        let clientCertPEM = loadCertificate("PLUGIN_CLIENT_CERT")

        log("INFO", "Loading certificates...")
        log("INFO", "Server cert length: \(serverCertPEM.count) bytes")
        log("INFO", "Server key length: \(serverKeyPEM.count) bytes")
        log("INFO", "Client cert length: \(clientCertPEM?.count ?? 0) bytes")

        // Create event loop group
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            try? group.syncShutdownGracefully()
        }

        // Configure TLS
        let serverCert = try NIOSSLCertificate(bytes: Array(serverCertPEM.utf8), format: .pem)
        let serverKey = try NIOSSLPrivateKey(bytes: Array(serverKeyPEM.utf8), format: .pem)

        var tlsConfig = TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(serverCert)],
            privateKey: .privateKey(serverKey)
        )

        if let clientCert = clientCertPEM {
            // mTLS - require client certificate
            let clientCA = try NIOSSLCertificate(bytes: Array(clientCert.utf8), format: .pem)
            tlsConfig.trustRoots = .certificates([clientCA])
            tlsConfig.certificateVerification = .fullVerification
            log("INFO", "mTLS credentials configured (client auth required)")
        } else {
            tlsConfig.certificateVerification = .none
            log("INFO", "TLS credentials configured (no client auth)")
        }

        tlsConfig.minimumTLSVersion = .tlsv12

        // Create server
        let port = Int(ProcessInfo.processInfo.environment["PLUGIN_PORT"] ?? "50051") ?? 50051

        let server = try Server.usingTLS(with: GRPCTLSConfiguration.makeServerConfigurationBackedByNIOSSL(configuration: tlsConfig), on: group)
            .withServiceProviders([KVServiceProvider()])
            .bind(host: "0.0.0.0", port: port)
            .wait()

        log("INFO", "gRPC KV Server listening on port \(port)")
        log("INFO", "Server ready to accept connections")

        // Handle signals
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT)
        signalSource.setEventHandler {
            log("INFO", "Received SIGINT, shutting down...")
            try? server.close().wait()
        }
        signalSource.resume()
        signal(SIGINT, SIG_IGN)

        // Wait for server to close
        try server.onClose.wait()
        log("INFO", "Server shutdown complete")
    }
}
