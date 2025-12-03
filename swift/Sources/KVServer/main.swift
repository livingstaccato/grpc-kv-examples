import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import SwiftProtobuf

/// Swift gRPC KV Server with mTLS (grpc-swift 2.x)
///
/// Implements a simple key-value store service with mutual TLS authentication.

/// Simple logging function
func log(_ level: String, _ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("\(timestamp) [\(level)]       \(message)")
}

/// Load certificate data from environment
func loadCertificate(_ envVar: String) -> String? {
    if let value = ProcessInfo.processInfo.environment[envVar], !value.isEmpty {
        return value
    }
    return nil
}

/// KV Service Implementation for grpc-swift 2.x
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
struct KVServiceProvider: Proto_KV.SimpleServiceProtocol {
    func get(
        request: Proto_GetRequest,
        context: GRPCCore.ServerContext
    ) async throws -> Proto_GetResponse {
        log("INFO", "Get request - Key: \(request.key)")

        // Validate request
        guard !request.key.isEmpty else {
            log("ERROR", "Get request rejected: empty key")
            throw RPCError(code: .invalidArgument, message: "key cannot be empty")
        }

        log("INFO", "Get request completed successfully")
        var response = Proto_GetResponse()
        response.value = Data("OK".utf8)
        return response
    }

    func put(
        request: Proto_PutRequest,
        context: GRPCCore.ServerContext
    ) async throws -> Proto_Empty {
        log("INFO", "Put request - Key: \(request.key)")

        // Validate request
        guard !request.key.isEmpty else {
            log("ERROR", "Put request rejected: empty key")
            throw RPCError(code: .invalidArgument, message: "key cannot be empty")
        }

        guard !request.value.isEmpty else {
            log("ERROR", "Put request rejected: empty value")
            throw RPCError(code: .invalidArgument, message: "value cannot be empty")
        }

        log("INFO", "Put request completed successfully")
        return Proto_Empty()
    }
}

@main
struct KVServer {
    static func main() async throws {
        log("INFO", "Starting gRPC KV Server (Swift 2.x)")

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

        // Get port from environment
        let port = Int(ProcessInfo.processInfo.environment["PLUGIN_PORT"] ?? "50051") ?? 50051

        // Configure transport security
        let transportSecurity: HTTP2ServerTransport.Posix.TransportSecurity

        if let clientCert = clientCertPEM {
            // mTLS - require client certificate
            log("INFO", "Configuring mTLS (client auth required)")
            transportSecurity = .tls(
                certificateChain: [.bytes(Array(serverCertPEM.utf8), format: .pem)],
                privateKey: .bytes(Array(serverKeyPEM.utf8), format: .pem)
            ) { config in
                config.trustRoots = .bytes(Array(clientCert.utf8), format: .pem)
                config.clientCertificateVerification = .require
            }
        } else {
            // TLS only - no client auth
            log("INFO", "Configuring TLS (no client auth)")
            transportSecurity = .tls(
                certificateChain: [.bytes(Array(serverCertPEM.utf8), format: .pem)],
                privateKey: .bytes(Array(serverKeyPEM.utf8), format: .pem)
            )
        }

        // Create and start server
        let server = GRPCServer(
            transport: .http2NIOPosix(
                address: .ipv4(host: "0.0.0.0", port: port),
                transportSecurity: transportSecurity
            ),
            services: [KVServiceProvider()]
        )

        log("INFO", "gRPC KV Server listening on port \(port)")
        log("INFO", "Server ready to accept connections")

        // Handle signals for graceful shutdown
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT)
        signalSource.setEventHandler {
            log("INFO", "Received SIGINT, shutting down...")
            Task {
                server.beginGracefulShutdown()
            }
        }
        signalSource.resume()
        signal(SIGINT, SIG_IGN)

        // Run the server
        try await server.serve()
        log("INFO", "Server shutdown complete")
    }
}
