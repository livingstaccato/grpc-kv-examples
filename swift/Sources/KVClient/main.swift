import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import SwiftProtobuf

/// Swift gRPC KV Client with mTLS (grpc-swift 2.x)
///
/// Connects to a KV server using mutual TLS authentication.

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

@main
struct KVClient {
    static func main() async throws {
        log("INFO", "Starting gRPC KV Client (Swift 2.x)")

        // Load certificates from environment
        guard let clientCertPEM = loadCertificate("PLUGIN_CLIENT_CERT") else {
            log("ERROR", "Missing PLUGIN_CLIENT_CERT environment variable")
            exit(1)
        }

        guard let clientKeyPEM = loadCertificate("PLUGIN_CLIENT_KEY") else {
            log("ERROR", "Missing PLUGIN_CLIENT_KEY environment variable")
            exit(1)
        }

        guard let serverCertPEM = loadCertificate("PLUGIN_SERVER_CERT") else {
            log("ERROR", "Missing PLUGIN_SERVER_CERT environment variable")
            exit(1)
        }

        log("INFO", "Loading certificates...")
        log("INFO", "Client cert length: \(clientCertPEM.count) bytes")
        log("INFO", "Client key length: \(clientKeyPEM.count) bytes")
        log("INFO", "Server cert length: \(serverCertPEM.count) bytes")

        // Get connection details from environment
        let host = ProcessInfo.processInfo.environment["PLUGIN_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["PLUGIN_PORT"] ?? "50051") ?? 50051

        log("INFO", "mTLS credentials configured")
        log("INFO", "Connecting to server at \(host):\(port)...")

        // Configure mTLS transport security
        let transportSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .tls(
            certificateChain: [.bytes(Array(clientCertPEM.utf8), format: .pem)],
            privateKey: .bytes(Array(clientKeyPEM.utf8), format: .pem)
        ) { config in
            config.trustRoots = .bytes(Array(serverCertPEM.utf8), format: .pem)
            config.certificateVerification = .fullVerification
        }

        // Connect and send request using withGRPCClient
        try await withGRPCClient(
            transport: .http2NIOPosix(
                target: .dns(host: host, port: port),
                transportSecurity: transportSecurity
            )
        ) { grpcClient in
            log("INFO", "Connected successfully")

            // Create the KV service client
            let client = Proto_KV.Client(wrapping: grpcClient)

            // Send Get request
            log("INFO", "Sending Get request...")
            var request = Proto_GetRequest()
            request.key = "test"

            do {
                let response = try await client.get(request)
                let value = String(data: response.value, encoding: .utf8) ?? ""
                print("Response: \(value)")
                log("INFO", "Request completed successfully")
            } catch let error as RPCError {
                log("ERROR", "Get request failed: \(error.code) - \(error.message)")
                exit(1)
            } catch {
                log("ERROR", "Get request failed: \(error)")
                exit(1)
            }
        }
    }
}
