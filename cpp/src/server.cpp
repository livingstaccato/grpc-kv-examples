/**
 * C++ gRPC KV Server with mTLS
 *
 * Implements a simple key-value store service with mutual TLS authentication.
 */

#include <iostream>
#include <memory>
#include <string>
#include <cstdlib>
#include <chrono>
#include <iomanip>
#include <sstream>

#include <grpcpp/grpcpp.h>
#include <grpcpp/security/server_credentials.h>

#include "kv.grpc.pb.h"

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using grpc::StatusCode;

using proto::KV;
using proto::GetRequest;
using proto::GetResponse;
using proto::PutRequest;
using proto::Empty;

// Logging helper
void log(const std::string& level, const std::string& message) {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()) % 1000;

    std::cout << std::put_time(std::gmtime(&time_t), "%Y-%m-%dT%H:%M:%S")
              << "." << std::setfill('0') << std::setw(3) << ms.count()
              << "Z [" << level << "]       " << message << std::endl;
}

// Get environment variable with default
std::string getenv_or(const char* name, const std::string& default_value) {
    const char* value = std::getenv(name);
    return value ? std::string(value) : default_value;
}

// KV Service implementation
class KVServiceImpl final : public KV::Service {
public:
    Status Get(ServerContext* context, const GetRequest* request,
               GetResponse* response) override {
        log("INFO", "Get request - Key: " + request->key());

        if (request->key().empty()) {
            log("ERROR", "Get request rejected: empty key");
            return Status(StatusCode::INVALID_ARGUMENT, "key cannot be empty");
        }

        log("INFO", "Get request completed successfully");
        response->set_value("OK");
        return Status::OK;
    }

    Status Put(ServerContext* context, const PutRequest* request,
               Empty* response) override {
        log("INFO", "Put request - Key: " + request->key());

        if (request->key().empty()) {
            log("ERROR", "Put request rejected: empty key");
            return Status(StatusCode::INVALID_ARGUMENT, "key cannot be empty");
        }

        if (request->value().empty()) {
            log("ERROR", "Put request rejected: empty value");
            return Status(StatusCode::INVALID_ARGUMENT, "value cannot be empty");
        }

        log("INFO", "Put request completed successfully");
        return Status::OK;
    }
};

int main(int argc, char** argv) {
    log("INFO", "Starting gRPC KV Server (C++)");

    // Load certificates from environment
    std::string server_cert = getenv_or("PLUGIN_SERVER_CERT", "");
    std::string server_key = getenv_or("PLUGIN_SERVER_KEY", "");
    std::string client_ca = getenv_or("PLUGIN_CLIENT_CERT", "");

    if (server_cert.empty() || server_key.empty()) {
        log("ERROR", "Missing required environment variables: PLUGIN_SERVER_CERT, PLUGIN_SERVER_KEY");
        return 1;
    }

    log("INFO", "Loading certificates...");
    log("INFO", "Server cert length: " + std::to_string(server_cert.length()) + " bytes");
    log("INFO", "Server key length: " + std::to_string(server_key.length()) + " bytes");
    log("INFO", "Client CA length: " + std::to_string(client_ca.length()) + " bytes");

    // Configure SSL credentials
    grpc::SslServerCredentialsOptions ssl_opts;
    ssl_opts.pem_key_cert_pairs.push_back({server_key, server_cert});

    if (!client_ca.empty()) {
        ssl_opts.pem_root_certs = client_ca;
        ssl_opts.client_certificate_request = GRPC_SSL_REQUEST_AND_REQUIRE_CLIENT_CERTIFICATE_AND_VERIFY;
        log("INFO", "mTLS credentials configured (client auth required)");
    } else {
        ssl_opts.client_certificate_request = GRPC_SSL_DONT_REQUEST_CLIENT_CERTIFICATE;
        log("INFO", "TLS credentials configured (no client auth)");
    }

    auto creds = grpc::SslServerCredentials(ssl_opts);

    // Build server
    std::string port = getenv_or("PLUGIN_PORT", "50051");
    std::string server_address = "0.0.0.0:" + port;

    KVServiceImpl service;

    ServerBuilder builder;
    builder.AddListeningPort(server_address, creds);
    builder.RegisterService(&service);

    std::unique_ptr<Server> server(builder.BuildAndStart());

    log("INFO", "gRPC KV Server listening on " + server_address);
    log("INFO", "Server ready to accept connections");

    server->Wait();

    return 0;
}
