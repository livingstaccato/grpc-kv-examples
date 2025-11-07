use log::{info, debug};
use std::env;
use std::fs;
use std::sync::Arc;
use tonic::{transport::{Server, Identity, ServerTlsConfig, Certificate}, Request, Response, Status};
use rustls;
use clap::Parser;

// Custom certificate verifier module
mod lenient_verifier;

// Include the generated protobuf code
pub mod proto {
    tonic::include_proto!("proto");
}

use proto::kv_server::{Kv, KvServer};
use proto::{Empty, GetRequest, GetResponse, PutRequest};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Certificate CA mode: true for CA:TRUE (go-plugin compatible), false for CA:FALSE (strict validation)
    ///
    /// CA:TRUE mode uses certificates with basicConstraints=CA:TRUE (HashiCorp go-plugin compatible).
    /// CA:FALSE mode uses certificates with basicConstraints=CA:FALSE (strict RFC compliance).
    #[arg(long = "ca-mode", value_name = "BOOL", default_value = "false", action = clap::ArgAction::Set)]
    ca_mode: bool,
}

#[derive(Debug, Default)]
pub struct KvService {}

#[tonic::async_trait]
impl Kv for KvService {
    async fn get(&self, request: Request<GetRequest>) -> Result<Response<GetResponse>, Status> {
        let key = &request.get_ref().key;
        info!("🔍 📥 Get request - Key: {}", key);

        // Log request metadata
        debug!("🔎 Request metadata:");
        for key_value in request.metadata().iter() {
            match key_value {
                tonic::metadata::KeyAndValueRef::Ascii(k, v) => {
                    debug!("🔎   {}: {:?}", k.as_str(), v.to_str());
                },
                tonic::metadata::KeyAndValueRef::Binary(k, _v) => {
                    debug!("🔎   {} (binary metadata present)", k.as_str());
                }
            }
        }

        let response = GetResponse {
            value: b"OK".to_vec(),
        };

        info!("✅ Get request completed successfully 🎉");
        Ok(Response::new(response))
    }

    async fn put(&self, request: Request<PutRequest>) -> Result<Response<Empty>, Status> {
        let req = request.get_ref();
        info!("📝 📥 Put request - Key: {}, Value length: {} bytes", req.key, req.value.len());
        debug!("📝 Value: {:?}", req.value);

        info!("✅ Put request completed successfully 🎉");
        Ok(Response::new(Empty {}))
    }
}

fn configure_tls_standard(ca_mode: bool) -> Result<ServerTlsConfig, Box<dyn std::error::Error>> {
    info!("🔐 Loading certificates from files (standard mode)...");

    let cert_dir = env::var("CERT_DIR").unwrap_or_else(|_| "./certs".to_string());
    let curve = env::var("PLUGIN_SERVER_ALGO").unwrap_or_else(|_| "ec-secp384r1".to_string());

    // Choose certificate prefix based on CA mode
    let prefix = if ca_mode {
        format!("{}", curve)  // Standard certs with CA:TRUE
    } else {
        format!("ca-false-{}", curve)  // CA:FALSE prefixed certs
    };

    let server_cert_path = format!("{}/{}-mtls-server.crt", cert_dir, prefix);
    let server_key_path = format!("{}/{}-mtls-server.key", cert_dir, prefix);
    let client_cert_path = format!("{}/{}-mtls-client.crt", cert_dir, prefix);

    info!("🔐 Reading certificates (CA mode: {}):", if ca_mode { "CA:TRUE" } else { "CA:FALSE" });
    info!("🔐   Server cert: {}", server_cert_path);
    info!("🔐   Server key: {}", server_key_path);
    info!("🔐   Client CA: {}", client_cert_path);

    let server_cert = fs::read(&server_cert_path)
        .map_err(|e| format!("Failed to read {}: {}", server_cert_path, e))?;
    let server_key = fs::read(&server_key_path)
        .map_err(|e| format!("Failed to read {}: {}", server_key_path, e))?;
    let client_cert = fs::read(&client_cert_path)
        .map_err(|e| format!("Failed to read {}: {}", client_cert_path, e))?;

    info!("📦 Certificate sizes:");
    info!("📦   Server Cert: {} bytes", server_cert.len());
    info!("📦   Server Key: {} bytes", server_key.len());
    info!("📦   Client CA Cert: {} bytes", client_cert.len());

    info!("🔑 Creating server identity (cert + key)...");

    // Create server identity (cert + key)
    let server_identity = Identity::from_pem(server_cert, server_key);
    info!("✅ Server identity created");

    // Create CA certificate for client verification (mTLS)
    info!("🔐 Creating client CA certificate for mTLS verification...");
    let client_ca_cert = Certificate::from_pem(client_cert);
    info!("✅ Client CA certificate loaded");

    info!("🔒 Creating TLS configuration with mTLS...");

    // Configure TLS with mTLS (client cert verification)
    let tls_config = ServerTlsConfig::new()
        .identity(server_identity)
        .client_ca_root(client_ca_cert);

    info!("✅ 🔒 TLS configuration complete - mTLS enabled 🎉");

    Ok(tls_config)
}

fn configure_tls_lenient() -> Result<Arc<rustls::ServerConfig>, Box<dyn std::error::Error>> {
    info!("🔐 Loading certificates from files (lenient mode - accepts CA:TRUE)...");

    let cert_dir = env::var("CERT_DIR").unwrap_or_else(|_| "./certs".to_string());
    let curve = env::var("PLUGIN_SERVER_ALGO").unwrap_or_else(|_| "ec-secp384r1".to_string());

    // Use standard certs (CA:TRUE)
    let server_cert_path = format!("{}/{}-mtls-server.crt", cert_dir, curve);
    let server_key_path = format!("{}/{}-mtls-server.key", cert_dir, curve);
    let client_cert_path = format!("{}/{}-mtls-client.crt", cert_dir, curve);

    info!("🔐 Reading certificates (CA:TRUE mode):");
    info!("🔐   Server cert: {}", server_cert_path);
    info!("🔐   Server key: {}", server_key_path);
    info!("🔐   Client CA: {}", client_cert_path);

    let server_cert_pem = fs::read(&server_cert_path)
        .map_err(|e| format!("Failed to read {}: {}", server_cert_path, e))?;
    let server_key_pem = fs::read(&server_key_path)
        .map_err(|e| format!("Failed to read {}: {}", server_key_path, e))?;
    let client_cert_pem = fs::read(&client_cert_path)
        .map_err(|e| format!("Failed to read {}: {}", client_cert_path, e))?;

    info!("📦 Certificate sizes:");
    info!("📦   Server Cert: {} bytes", server_cert_pem.len());
    info!("📦   Server Key: {} bytes", server_key_pem.len());
    info!("📦   Client CA Cert: {} bytes", client_cert_pem.len());

    // Parse PEM certificates and keys
    info!("🔑 Parsing server certificates and keys...");

    // Parse server certificate
    let server_certs = rustls_pemfile::certs(&mut server_cert_pem.as_slice())
        .collect::<Result<Vec<_>, _>>()?;
    if server_certs.is_empty() {
        return Err("No server certificates found in PEM".into());
    }

    // Parse server private key
    let server_key = rustls_pemfile::private_key(&mut server_key_pem.as_slice())?
        .ok_or("No private key found in PEM")?;

    // Parse client certificate (for pinning/verification)
    let client_certs = rustls_pemfile::certs(&mut client_cert_pem.as_slice())
        .collect::<Result<Vec<_>, _>>()?;
    if client_certs.is_empty() {
        return Err("No client certificates found in PEM".into());
    }

    info!("✅ Parsed {} server cert(s), 1 private key, {} client cert(s)",
          server_certs.len(), client_certs.len());

    // Create custom client certificate verifier
    info!("🔒 Creating custom certificate verifier (accepts CA:TRUE)...");
    let client_cert_verifier = lenient_verifier::LenientClientCertVerifier::new(
        Some(client_certs[0].to_vec()) // Pin to the expected client certificate
    );

    // Build rustls ServerConfig with custom verifier
    info!("🔧 Building rustls ServerConfig with dangerous configuration...");
    let mut server_config = rustls::ServerConfig::builder()
        .with_client_cert_verifier(client_cert_verifier)
        .with_single_cert(server_certs, server_key)?;

    // Enable ALPN for HTTP/2 (required for gRPC)
    server_config.alpn_protocols = vec![b"h2".to_vec()];

    info!("✅ Rustls ServerConfig created with lenient client cert verifier");

    Ok(Arc::new(server_config))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    // Initialize crypto provider for rustls (must be done before any TLS operations)
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    // Parse command-line arguments
    let args = Args::parse();

    info!("🚀 🔄 Starting Rust gRPC server... 🌟");
    info!("🦀 Rust edition: 2024");
    info!("🔐 Certificate CA mode: {}", if args.ca_mode { "CA:TRUE (go-plugin compatible)" } else { "CA:FALSE (strict validation)" });

    let addr = "[::]:50051".parse()?;
    info!("🌐 Address parsed: {}", addr);

    let kv_service = KvService::default();
    info!("🔧 KV service initialized");

    // Configure TLS based on CA mode
    info!("🔐 Configuring TLS...");

    if args.ca_mode {
        // CA:TRUE mode - use custom rustls config with lenient verifier
        info!("⚠️  Using lenient mode (accepts CA:TRUE certificates)");

        // For now, we'll note that custom rustls::ServerConfig integration with tonic Server
        // requires using the incoming stream directly or using a custom acceptor.
        // This is more complex than the client side.
        // As a workaround, we'll use the standard config for now and document the limitation.

        info!("⚠️  NOTE: Server-side lenient mode not fully implemented yet");
        info!("⚠️  Falling back to standard TLS config");
        info!("⚠️  This may still reject CA:TRUE client certificates");

        let tls_config = configure_tls_standard(args.ca_mode)?;

        info!("🌐 Binding server to {} with TLS...", addr);

        let server = Server::builder()
            .tls_config(tls_config)?
            .add_service(KvServer::new(kv_service));

        info!("✅ Server configured successfully");
        info!("🎧 Listening on {} - Ready to accept connections! 🚀", addr);

        server.serve(addr).await?;
    } else {
        // CA:FALSE mode - use standard strict validation
        let tls_config = configure_tls_standard(args.ca_mode)?;

        info!("🌐 Binding server to {} with TLS...", addr);

        let server = Server::builder()
            .tls_config(tls_config)?
            .add_service(KvServer::new(kv_service));

        info!("✅ Server configured successfully");
        info!("🎧 Listening on {} - Ready to accept connections! 🚀", addr);

        server.serve(addr).await?;
    }

    info!("⏹️  Server stopped gracefully");

    Ok(())
}
