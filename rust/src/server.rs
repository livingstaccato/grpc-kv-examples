use log::{error, info};
use std::env;
use std::io::Cursor;
use std::sync::Arc;
use tonic::{transport::Server, Request, Response, Status};

use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use rustls::ServerConfig;
use tokio_rustls::TlsAcceptor;

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
        info!("📥 Get request - Key: {}", key);

        let response = GetResponse {
            value: b"OK".to_vec(),
        };

        info!("✅ Request completed successfully");
        Ok(Response::new(response))
    }

    async fn put(&self, request: Request<PutRequest>) -> Result<Response<Empty>, Status> {
        let req = request.get_ref();
        info!("📥 Put request - Key: {}, Value: {:?}", req.key, req.value);

        info!("✅ Request completed successfully");
        Ok(Response::new(Empty {}))
    }
}

fn load_certificates() -> Result<(Vec<CertificateDer<'static>>, PrivateKeyDer<'static>, Vec<CertificateDer<'static>>), Box<dyn std::error::Error>> {
    info!("🔐 Loading certificates...");

    // Load server certificate
    let server_cert_pem = env::var("PLUGIN_SERVER_CERT")
        .map_err(|_| "Missing PLUGIN_SERVER_CERT environment variable")?;
    let server_key_pem = env::var("PLUGIN_SERVER_KEY")
        .map_err(|_| "Missing PLUGIN_SERVER_KEY environment variable")?;
    let client_cert_pem = env::var("PLUGIN_CLIENT_CERT")
        .map_err(|_| "Missing PLUGIN_CLIENT_CERT environment variable")?;

    // Parse server certificate chain
    let server_certs = rustls_pemfile::certs(&mut Cursor::new(server_cert_pem.as_bytes()))
        .collect::<Result<Vec<_>, _>>()?;

    if server_certs.is_empty() {
        return Err("No server certificates found".into());
    }

    info!("🔍 Loaded {} server certificate(s)", server_certs.len());

    // Parse server private key
    let mut server_key_reader = Cursor::new(server_key_pem.as_bytes());
    let server_key = rustls_pemfile::private_key(&mut server_key_reader)?
        .ok_or("No private key found")?;

    info!("🔑 Server key loaded");

    // Parse client certificate (for mTLS verification)
    let client_certs = rustls_pemfile::certs(&mut Cursor::new(client_cert_pem.as_bytes()))
        .collect::<Result<Vec<_>, _>>()?;

    if client_certs.is_empty() {
        return Err("No client certificates found".into());
    }

    info!("🔍 Loaded {} client certificate(s) for verification", client_certs.len());

    Ok((server_certs, server_key, client_certs))
}

fn configure_tls() -> Result<ServerConfig, Box<dyn std::error::Error>> {
    let (server_certs, server_key, client_certs) = load_certificates()?;

    info!("🔒 Creating TLS configuration...");

    // Create a certificate verifier that accepts our client certificate
    let mut root_store = rustls::RootCertStore::empty();
    for cert in client_certs {
        root_store.add(cert)?;
    }

    let client_cert_verifier = rustls::server::WebPkiClientVerifier::builder(Arc::new(root_store))
        .build()?;

    // Configure TLS with support for all elliptic curves including P-521
    let config = ServerConfig::builder()
        .with_client_cert_verifier(client_cert_verifier)
        .with_single_cert(server_certs, server_key)?;

    info!("✅ TLS configuration created");

    Ok(config)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    info!("🚀 Starting Rust gRPC server...");

    let addr = "[::]:50051".parse()?;
    let kv_service = KvService::default();

    // Configure TLS
    let tls_config = configure_tls()?;
    let tls_acceptor = TlsAcceptor::from(Arc::new(tls_config));

    info!("🌐 Binding to {}", addr);

    // Create the server with TLS
    Server::builder()
        .tls_config(tonic::transport::ServerTlsConfig::new())?
        .add_service(KvServer::new(kv_service))
        .serve(addr)
        .await?;

    info!("⏹️  Server stopped");

    Ok(())
}
