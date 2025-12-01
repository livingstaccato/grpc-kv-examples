/**
 * C++ gRPC KV Client with mTLS
 *
 * Connects to a KV server using mutual TLS authentication.
 */

#include <iostream>
#include <memory>
#include <string>
#include <cstdlib>
#include <chrono>
#include <iomanip>

#include <grpcpp/grpcpp.h>
#include <grpcpp/security/credentials.h>

#include "kv.grpc.pb.h"

using grpc::Channel;
using grpc::ClientContext;
using grpc::Status;

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

// KV Client class
class KVClient {
public:
    KVClient(std::shared_ptr<Channel> channel)
        : stub_(KV::NewStub(channel)) {}

    std::string Get(const std::string& key) {
        GetRequest request;
        request.set_key(key);

        GetResponse response;
        ClientContext context;

        log("INFO", "Sending Get request...");
        Status status = stub_->Get(&context, request, &response);

        if (status.ok()) {
            return response.value();
        } else {
            log("ERROR", "Get request failed: " + status.error_message());
            throw std::runtime_error(status.error_message());
        }
    }

    void Put(const std::string& key, const std::string& value) {
        PutRequest request;
        request.set_key(key);
        request.set_value(value);

        Empty response;
        ClientContext context;

        log("INFO", "Sending Put request...");
        Status status = stub_->Put(&context, request, &response);

        if (!status.ok()) {
            log("ERROR", "Put request failed: " + status.error_message());
            throw std::runtime_error(status.error_message());
        }
    }

private:
    std::unique_ptr<KV::Stub> stub_;
};

int main(int argc, char** argv) {
    log("INFO", "Starting gRPC KV Client (C++)");

    // Load certificates from environment
    std::string client_cert = getenv_or("PLUGIN_CLIENT_CERT", "");
    std::string client_key = getenv_or("PLUGIN_CLIENT_KEY", "");
    std::string server_ca = getenv_or("PLUGIN_SERVER_CERT", "");

    if (client_cert.empty() || client_key.empty()) {
        log("ERROR", "Missing required environment variables: PLUGIN_CLIENT_CERT, PLUGIN_CLIENT_KEY");
        return 1;
    }

    if (server_ca.empty()) {
        log("ERROR", "Missing required environment variable: PLUGIN_SERVER_CERT");
        return 1;
    }

    log("INFO", "Loading certificates...");
    log("INFO", "Client cert length: " + std::to_string(client_cert.length()) + " bytes");
    log("INFO", "Client key length: " + std::to_string(client_key.length()) + " bytes");
    log("INFO", "Server CA length: " + std::to_string(server_ca.length()) + " bytes");

    // Configure SSL credentials
    grpc::SslCredentialsOptions ssl_opts;
    ssl_opts.pem_root_certs = server_ca;
    ssl_opts.pem_private_key = client_key;
    ssl_opts.pem_cert_chain = client_cert;

    auto creds = grpc::SslCredentials(ssl_opts);

    log("INFO", "mTLS credentials configured");

    // Build channel
    std::string host = getenv_or("PLUGIN_HOST", "localhost");
    std::string port = getenv_or("PLUGIN_PORT", "50051");
    std::string target = host + ":" + port;

    log("INFO", "Connecting to server at " + target + "...");

    grpc::ChannelArguments channel_args;
    channel_args.SetSslTargetNameOverride("localhost");

    auto channel = grpc::CreateCustomChannel(target, creds, channel_args);

    KVClient client(channel);

    try {
        std::string response = client.Get("test");
        std::cout << "Response: " << response << std::endl;
        log("INFO", "Request completed successfully");
    } catch (const std::exception& e) {
        log("ERROR", "Request failed: " + std::string(e.what()));
        return 1;
    }

    return 0;
}
