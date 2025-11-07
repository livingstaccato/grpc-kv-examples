use log::{info, debug};
use std::env;
use std::fs;
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Identity};
use rustls;

// Include the generated protobuf code
pub mod proto {
    tonic::include_proto!("proto");
}

use proto::kv_client::KvClient;
use proto::GetRequest;

fn load_certificates() -> Result<(Vec<u8>, Vec<u8>, Vec<u8>), Box<dyn std::error::Error>> {
    info!("📂 Loading certificates from files... 🔍");

    // Use standard certificates (now with CA:FALSE for proper end-entity certs)
    let cert_dir = env::var("CERT_DIR").unwrap_or_else(|_| "./certs".to_string());
    let curve = env::var("PLUGIN_CLIENT_ALGO").unwrap_or_else(|_| "ec-secp384r1".to_string());

    // Use standard certificate names
    let client_cert_path = format!("{}/{}-mtls-client.crt", cert_dir, curve);
    let client_key_path = format!("{}/{}-mtls-client.key", cert_dir, curve);
    let server_cert_path = format!("{}/{}-mtls-server.crt", cert_dir, curve);

    info!("🔐 Reading certificates:");
    info!("🔐   Client cert: {}", client_cert_path);
    info!("🔐   Client key: {}", client_key_path);
    info!("🔐   Server CA: {}", server_cert_path);

    let client_cert = fs::read(&client_cert_path)
        .map_err(|e| format!("Failed to read {}: {}", client_cert_path, e))?;
    let client_key = fs::read(&client_key_path)
        .map_err(|e| format!("Failed to read {}: {}", client_key_path, e))?;
    let server_cert = fs::read(&server_cert_path)
        .map_err(|e| format!("Failed to read {}: {}", server_cert_path, e))?;

    info!("📦 Certificate sizes - Client Cert: {} bytes, Client Key: {} bytes, Server Cert: {} bytes 📊",
        client_cert.len(),
        client_key.len(),
        server_cert.len()
    );

    Ok((client_cert, client_key, server_cert))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    // Initialize crypto provider for rustls
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    info!("🚀 Starting Rust gRPC client... 🌟");
    info!("🦀 Rust edition: 2024");
    info!("🔐 Using standard certificates with CA:FALSE");

    let host = env::var("PLUGIN_HOST").unwrap_or_else(|_| "localhost".to_string());
    let port = env::var("PLUGIN_PORT").unwrap_or_else(|_| "50051".to_string());
    let endpoint = format!("https://{}:{}", host, port);

    info!("🌐 Target endpoint: {}", endpoint);

    // Load certificates
    let (client_cert, client_key, server_cert) = load_certificates()?;
    info!("✅ Certificates loaded successfully");

    // Create client identity (cert + key)
    info!("🔑 Creating client identity...");
    let identity = Identity::from_pem(client_cert, client_key);

    // Create CA certificate for server verification
    info!("🔐 Creating server CA certificate...");
    let ca_cert = Certificate::from_pem(server_cert);

    // Configure TLS
    info!("🔒 Configuring TLS with mTLS...");
    let tls_config = ClientTlsConfig::new()
        .domain_name("localhost")
        .ca_certificate(ca_cert)
        .identity(identity);

    info!("✅ TLS configuration complete");

    // Create channel
    info!("🔌 Creating gRPC channel...");
    let channel = Channel::from_shared(endpoint)?
        .tls_config(tls_config)?
        .connect()
        .await?;

    info!("✅ Channel created successfully");

    let mut client = KvClient::new(channel);

    info!("👥 gRPC client created");
    info!("📡 Sending Get request for key: 'test-key'...");

    let request = tonic::Request::new(GetRequest {
        key: "test-key".to_string(),
    });

    debug!("🔎 Request details: {:?}", request);

    let response = client.get(request).await?;

    let value = String::from_utf8_lossy(&response.get_ref().value);
    info!("📥 Response received - Value length: {} bytes", response.get_ref().value.len());
    println!("✨ Response: {} 📄", value);

    info!("✅ Request completed successfully 🎉");

    Ok(())
}
