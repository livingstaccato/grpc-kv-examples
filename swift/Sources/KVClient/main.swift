import Foundation
import GRPC
import NIO
import NIOSSL
import Logging

/// Swift gRPC KV Client with mTLS
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
    static func main() throws {
        log("INFO", "Starting gRPC KV Client (Swift)")

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

        // Create event loop group
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            try? group.syncShutdownGracefully()
        }

        // Configure TLS
        let clientCert = try NIOSSLCertificate(bytes: Array(clientCertPEM.utf8), format: .pem)
        let clientKey = try NIOSSLPrivateKey(bytes: Array(clientKeyPEM.utf8), format: .pem)
        let serverCA = try NIOSSLCertificate(bytes: Array(serverCertPEM.utf8), format: .pem)

        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.certificateChain = [.certificate(clientCert)]
        tlsConfig.privateKey = .privateKey(clientKey)
        tlsConfig.trustRoots = .certificates([serverCA])
        tlsConfig.certificateVerification = .fullVerification
        tlsConfig.minimumTLSVersion = .tlsv12

        log("INFO", "mTLS credentials configured")

        // Connect to server
        let host = ProcessInfo.processInfo.environment["PLUGIN_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["PLUGIN_PORT"] ?? "50051") ?? 50051

        log("INFO", "Connecting to server at \(host):\(port)...")

        let channel = try GRPCChannelPool.with(
            target: .host(host, port: port),
            transportSecurity: .tls(GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL(configuration: tlsConfig)),
            eventLoopGroup: group
        ) {
            $0.maximumReceiveMessageLength = 100 * 1024 * 1024
        }

        defer {
            try? channel.close().wait()
        }

        log("INFO", "Connected successfully")

        // Create client
        let client = KVNIOClient(channel: channel)

        // Send Get request
        log("INFO", "Sending Get request...")
        var request = GetRequest()
        request.key = "test"

        do {
            let response = try client.get(request).response.wait()
            let value = String(data: response.value, encoding: .utf8) ?? ""
            print("Response: \(value)")
            log("INFO", "Request completed successfully")
        } catch {
            log("ERROR", "Get request failed: \(error)")
            exit(1)
        }
    }
}
