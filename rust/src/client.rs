use log::{error, info};
use std::env;
use std::io::Cursor;
use std::sync::Arc;
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Identity};

// Include the generated protobuf code
pub mod proto {
    tonic::include_proto!("proto");
}

use proto::kv_client::KvClient;
use proto::GetRequest;

fn load_certificates() -> Result<(Vec<u8>, Vec<u8>, Vec<u8>), Box<dyn std::error::Error>> {
    info!("📂 Checking environment variables...");

    let client_cert_pem = env::var("PLUGIN_CLIENT_CERT")
        .map_err(|_| "Missing PLUGIN_CLIENT_CERT environment variable")?;
    let client_key_pem = env::var("PLUGIN_CLIENT_KEY")
        .map_err(|_| "Missing PLUGIN_CLIENT_KEY environment variable")?;
    let server_cert_pem = env::var("PLUGIN_SERVER_CERT")
        .map_err(|_| "Missing PLUGIN_SERVER_CERT environment variable")?;

    info!(
        "📦 Certificate sizes - Client Cert: {} bytes, Client Key: {} bytes, Server Cert: {} bytes",
        client_cert_pem.len(),
        client_key_pem.len(),
        server_cert_pem.len()
    );

    Ok((
        client_cert_pem.into_bytes(),
        client_key_pem.into_bytes(),
        server_cert_pem.into_bytes(),
    ))
}

fn configure_tls() -> Result<ClientTlsConfig, Box<dyn std::error::Error>> {
    info!("🔐 Creating certificate objects...");

    let (client_cert, client_key, server_cert) = load_certificates()?;

    // Create client identity (cert + key)
    let identity = Identity::from_pem(client_cert, client_key);

    // Create CA certificate for server verification
    let ca_cert = Certificate::from_pem(server_cert);

    // Configure TLS
    let tls_config = ClientTlsConfig::new()
        .domain_name("localhost")
        .ca_certificate(ca_cert)
        .identity(identity);

    info!("🔒 TLS configuration created");

    Ok(tls_config)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    info!("🚀 Starting Rust gRPC client...");

    let host = env::var("PLUGIN_HOST").unwrap_or_else(|_| "localhost".to_string());
    let port = env::var("PLUGIN_PORT").unwrap_or_else(|_| "50051".to_string());
    let endpoint = format!("https://{}:{}", host, port);

    info!("🌐 Connecting to {}", endpoint);

    // Configure TLS
    let tls_config = configure_tls()?;

    // Create channel with TLS
    let channel = Channel::from_shared(endpoint)?
        .tls_config(tls_config)?
        .connect()
        .await?;

    let mut client = KvClient::new(channel);

    info!("👥 Created gRPC client");
    info!("📡 Sending Get request...");

    let request = tonic::Request::new(GetRequest {
        key: "test-key".to_string(),
    });

    let response = client.get(request).await?;

    let value = String::from_utf8_lossy(&response.get_ref().value);
    println!("✨ Response: {}", value);

    info!("✅ Request completed successfully");

    Ok(())
}
