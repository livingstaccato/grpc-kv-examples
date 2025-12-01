//! Rust gRPC KV Client with mTLS
//!
//! Connects to a KV server using mutual TLS authentication.

use grpc_kv_rust::proto::kv_client::KvClient;
use grpc_kv_rust::proto::GetRequest;
use grpc_kv_rust::{log, log_certificate_info};
use std::env;
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Identity};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    log("INFO", "Starting gRPC KV Client (Rust)");

    // Load certificates from environment
    let client_cert = env::var("PLUGIN_CLIENT_CERT")
        .expect("Missing PLUGIN_CLIENT_CERT environment variable");
    let client_key = env::var("PLUGIN_CLIENT_KEY")
        .expect("Missing PLUGIN_CLIENT_KEY environment variable");
    let server_ca = env::var("PLUGIN_SERVER_CERT")
        .expect("Missing PLUGIN_SERVER_CERT environment variable");

    log("INFO", "Loading certificates...");
    log("INFO", &format!("Client cert length: {} bytes", client_cert.len()));
    log("INFO", &format!("Client key length: {} bytes", client_key.len()));
    log("INFO", &format!("Server CA length: {} bytes", server_ca.len()));

    log_certificate_info(&client_cert, "Client");
    log_certificate_info(&server_ca, "Server CA");

    // Create client identity
    let identity = Identity::from_pem(&client_cert, &client_key);

    // Create CA certificate for server verification
    let ca = Certificate::from_pem(&server_ca);

    // Configure TLS
    let tls_config = ClientTlsConfig::new()
        .domain_name("localhost")
        .ca_certificate(ca)
        .identity(identity);

    log("INFO", "mTLS credentials configured");

    let host = env::var("PLUGIN_HOST").unwrap_or_else(|_| "localhost".to_string());
    let port = env::var("PLUGIN_PORT").unwrap_or_else(|_| "50051".to_string());
    let addr = format!("https://{}:{}", host, port);

    log("INFO", &format!("Connecting to server at {}...", addr));

    let channel = Channel::from_shared(addr)?
        .tls_config(tls_config)?
        .connect()
        .await?;

    log("INFO", "Connected successfully");

    let mut client = KvClient::new(channel);

    // Send Get request
    log("INFO", "Sending Get request...");
    let request = tonic::Request::new(GetRequest {
        key: "test".to_string(),
    });

    let response = client.get(request).await?;
    let value = String::from_utf8_lossy(&response.into_inner().value);

    println!("Response: {}", value);
    log("INFO", "Request completed successfully");

    Ok(())
}
