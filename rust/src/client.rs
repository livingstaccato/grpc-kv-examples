use log::{info, debug};
use std::env;
use std::fs;
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Identity};
use clap::Parser;
use rustls;

// Custom certificate verifier module
mod lenient_verifier;

// Include the generated protobuf code
pub mod proto {
    tonic::include_proto!("proto");
}

use proto::kv_client::KvClient;
use proto::GetRequest;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Certificate CA mode: true for CA:TRUE (go-plugin compatible), false for CA:FALSE (strict validation)
    /// Usage: --ca-mode true or --ca-mode false (default: true)
    #[arg(long = "ca-mode", default_value = "true")]
    ca_mode: bool,
}

fn load_certificates(ca_mode: bool) -> Result<(Vec<u8>, Vec<u8>, Vec<u8>), Box<dyn std::error::Error>> {
    info!("📂 Loading certificates from files... 🔍");

    let cert_dir = env::var("CERT_DIR").unwrap_or_else(|_| "./certs".to_string());
    let curve = env::var("PLUGIN_CLIENT_ALGO").unwrap_or_else(|_| "ec-secp384r1".to_string());

    // Choose certificate prefix based on CA mode
    let prefix = if ca_mode {
        format!("{}", curve)  // Standard certs with CA:TRUE
    } else {
        format!("ca-false-{}", curve)  // CA:FALSE prefixed certs
    };

    let client_cert_path = format!("{}/{}-mtls-client.crt", cert_dir, prefix);
    let client_key_path = format!("{}/{}-mtls-client.key", cert_dir, prefix);
    let server_cert_path = format!("{}/{}-mtls-server.crt", cert_dir, prefix);

    info!("🔐 Reading certificates (CA mode: {}):", if ca_mode { "CA:TRUE" } else { "CA:FALSE" });
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

async fn create_channel_with_lenient_tls(
    endpoint: String,
    client_cert_pem: Vec<u8>,
    client_key_pem: Vec<u8>,
    server_cert_pem: Vec<u8>,
) -> Result<Channel, Box<dyn std::error::Error>> {
    info!("🔌 Creating gRPC channel with lenient TLS (CA:TRUE mode)... 🔄");
    info!("⚠️  Using custom certificate verifier to accept CA:TRUE certificates");

    // Parse PEM certificates and keys
    info!("🔑 Parsing client certificates and keys...");

    // Parse client certificate
    let client_certs = rustls_pemfile::certs(&mut client_cert_pem.as_slice())
        .collect::<Result<Vec<_>, _>>()?;
    if client_certs.is_empty() {
        return Err("No client certificates found in PEM".into());
    }

    // Parse client private key
    let client_key = rustls_pemfile::private_key(&mut client_key_pem.as_slice())?
        .ok_or("No private key found in PEM")?;

    // Parse server certificate (for pinning/verification)
    let server_certs = rustls_pemfile::certs(&mut server_cert_pem.as_slice())
        .collect::<Result<Vec<_>, _>>()?;
    if server_certs.is_empty() {
        return Err("No server certificates found in PEM".into());
    }

    info!("✅ Parsed {} client cert(s), 1 private key, {} server cert(s)",
          client_certs.len(), server_certs.len());

    // Create custom server certificate verifier
    info!("🔒 Creating custom certificate verifier (accepts CA:TRUE)...");
    let server_cert_verifier = lenient_verifier::LenientServerCertVerifier::new(
        Some(server_certs[0].to_vec()) // Pin to the expected server certificate
    );

    // Build rustls ClientConfig with custom verifier
    info!("🔧 Building rustls ClientConfig with dangerous configuration...");
    let client_config = rustls::ClientConfig::builder()
        .dangerous()
        .with_custom_certificate_verifier(server_cert_verifier)
        .with_client_auth_cert(client_certs, client_key)?;

    info!("✅ Rustls ClientConfig created (ALPN will be set by hyper-rustls)");

    // Create HTTPS connector with custom rustls config
    // Note: hyper-rustls will set ALPN protocols via enable_http2()
    info!("🔌 Creating HTTP connector...");
    let mut http = hyper_util::client::legacy::connect::HttpConnector::new();
    http.enforce_http(false);

    info!("🔒 Wrapping HTTP connector with custom TLS...");
    let https_connector = hyper_rustls::HttpsConnectorBuilder::new()
        .with_tls_config(client_config)
        .https_only()
        .enable_http2()
        .wrap_connector(http);

    // Build tonic channel with custom connector
    info!("🚀 Building tonic channel with custom connector...");
    let channel = Channel::builder(endpoint.parse()?)
        .connect_with_connector(https_connector)
        .await?;

    info!("✅ Successfully created gRPC channel with custom certificate verifier");

    Ok(channel)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    // Initialize crypto provider for rustls
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    // Parse command-line arguments
    let args = Args::parse();

    info!("🚀 Starting Rust gRPC client... 🌟");
    info!("🦀 Rust edition: 2024");
    info!("🔐 Certificate CA mode: {}", if args.ca_mode { "CA:TRUE (go-plugin compatible)" } else { "CA:FALSE (strict validation)" });

    let host = env::var("PLUGIN_HOST").unwrap_or_else(|_| "localhost".to_string());
    let port = env::var("PLUGIN_PORT").unwrap_or_else(|_| "50051".to_string());
    let endpoint = format!("https://{}:{}", host, port);

    info!("🌐 Target endpoint: {}", endpoint);

    // Load certificates based on CA mode
    let (client_cert, client_key, server_cert) = load_certificates(args.ca_mode)?;
    info!("✅ Certificates loaded successfully");

    // Create channel based on CA mode
    let channel = if args.ca_mode {
        // CA:TRUE mode - use standard TLS (Go/Python/Ruby will accept CA:TRUE)
        create_channel_with_lenient_tls(endpoint, client_cert, client_key, server_cert).await?
    } else {
        // CA:FALSE mode - use standard Tonic TLS
        info!("🔑 Creating client identity...");
        let identity = Identity::from_pem(client_cert, client_key);

        info!("🔐 Creating server CA certificate...");
        let ca_cert = Certificate::from_pem(server_cert);

        info!("🔒 Configuring TLS with mTLS (strict validation)...");
        let tls_config = ClientTlsConfig::new()
            .domain_name("localhost")
            .ca_certificate(ca_cert)
            .identity(identity);

        info!("✅ TLS configuration complete");

        info!("🔌 Creating gRPC channel...");
        Channel::from_shared(endpoint)?
            .tls_config(tls_config)?
            .connect()
            .await?
    };

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
