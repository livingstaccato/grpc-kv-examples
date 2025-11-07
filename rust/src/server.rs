use log::{info, debug};
use std::env;
use std::fs;
use tonic::{transport::{Server, Identity, ServerTlsConfig, Certificate}, Request, Response, Status};
use rustls;

// Include the generated protobuf code
pub mod proto {
    tonic::include_proto!("proto");
}

use proto::kv_server::{Kv, KvServer};
use proto::{Empty, GetRequest, GetResponse, PutRequest};

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

fn configure_tls() -> Result<ServerTlsConfig, Box<dyn std::error::Error>> {
    info!("🔐 Loading certificates from files...");

    // Use standard certificates (now with CA:FALSE for proper end-entity certs)
    let cert_dir = env::var("CERT_DIR").unwrap_or_else(|_| "./certs".to_string());
    let curve = env::var("PLUGIN_SERVER_ALGO").unwrap_or_else(|_| "ec-secp384r1".to_string());

    // Use standard certificate names
    let server_cert_path = format!("{}/{}-mtls-server.crt", cert_dir, curve);
    let server_key_path = format!("{}/{}-mtls-server.key", cert_dir, curve);
    let client_cert_path = format!("{}/{}-mtls-client.crt", cert_dir, curve);

    info!("🔐 Reading certificates:");
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

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    // Initialize crypto provider for rustls (must be done before any TLS operations)
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    info!("🚀 🔄 Starting Rust gRPC server... 🌟");
    info!("🦀 Rust edition: 2024");
    info!("🔐 Using standard certificates with CA:FALSE");

    let addr = "[::]:50051".parse()?;
    info!("🌐 Address parsed: {}", addr);

    let kv_service = KvService::default();
    info!("🔧 KV service initialized");

    // Configure TLS
    info!("🔐 Configuring TLS...");
    let tls_config = configure_tls()?;

    info!("🌐 Binding server to {} with TLS...", addr);

    // Create the server with TLS
    let server = Server::builder()
        .tls_config(tls_config)?
        .add_service(KvServer::new(kv_service));

    info!("✅ Server configured successfully");
    info!("🎧 Listening on {} - Ready to accept connections! 🚀", addr);

    server.serve(addr).await?;

    info!("⏹️  Server stopped gracefully");

    Ok(())
}
