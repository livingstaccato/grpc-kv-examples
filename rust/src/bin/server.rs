//! Rust gRPC KV Server with mTLS
//!
//! Implements a simple key-value store service with mutual TLS authentication.

use grpc_kv_rust::proto::kv_server::{Kv, KvServer};
use grpc_kv_rust::proto::{Empty, GetRequest, GetResponse, PutRequest};
use grpc_kv_rust::{log, log_certificate_info};
use std::env;
use tonic::transport::{Certificate, Identity, Server, ServerTlsConfig};
use tonic::{Request, Response, Status};

#[derive(Debug, Default)]
pub struct KvService {}

#[tonic::async_trait]
impl Kv for KvService {
    async fn get(&self, request: Request<GetRequest>) -> Result<Response<GetResponse>, Status> {
        let req = request.into_inner();
        log("INFO", &format!("Get request - Key: {}", req.key));

        if req.key.is_empty() {
            log("ERROR", "Get request rejected: empty key");
            return Err(Status::invalid_argument("key cannot be empty"));
        }

        log("INFO", "Get request completed successfully");
        Ok(Response::new(GetResponse {
            value: b"OK".to_vec(),
        }))
    }

    async fn put(&self, request: Request<PutRequest>) -> Result<Response<Empty>, Status> {
        let req = request.into_inner();
        log("INFO", &format!("Put request - Key: {}", req.key));

        if req.key.is_empty() {
            log("ERROR", "Put request rejected: empty key");
            return Err(Status::invalid_argument("key cannot be empty"));
        }

        if req.value.is_empty() {
            log("ERROR", "Put request rejected: empty value");
            return Err(Status::invalid_argument("value cannot be empty"));
        }

        log("INFO", "Put request completed successfully");
        Ok(Response::new(Empty {}))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    log("INFO", "Starting gRPC KV Server (Rust)");

    // Load certificates from environment
    let server_cert = env::var("PLUGIN_SERVER_CERT")
        .expect("Missing PLUGIN_SERVER_CERT environment variable");
    let server_key = env::var("PLUGIN_SERVER_KEY")
        .expect("Missing PLUGIN_SERVER_KEY environment variable");
    let client_ca = env::var("PLUGIN_CLIENT_CERT").ok();

    log("INFO", "Loading certificates...");
    log("INFO", &format!("Server cert length: {} bytes", server_cert.len()));
    log("INFO", &format!("Server key length: {} bytes", server_key.len()));
    log("INFO", &format!("Client CA length: {} bytes", client_ca.as_ref().map(|c| c.len()).unwrap_or(0)));

    log_certificate_info(&server_cert, "Server");
    if let Some(ref ca) = client_ca {
        log_certificate_info(ca, "Client CA");
    }

    // Create identity from server cert and key
    let identity = Identity::from_pem(&server_cert, &server_key);

    // Configure TLS
    let mut tls_config = ServerTlsConfig::new().identity(identity);

    if let Some(ca_cert) = client_ca {
        // mTLS - require client certificate
        let ca = Certificate::from_pem(&ca_cert);
        tls_config = tls_config.client_ca_root(ca);
        log("INFO", "mTLS credentials configured (client auth required)");
    } else {
        log("INFO", "TLS credentials configured (no client auth)");
    }

    let port: u16 = env::var("PLUGIN_PORT")
        .unwrap_or_else(|_| "50051".to_string())
        .parse()
        .unwrap_or(50051);

    let addr = format!("0.0.0.0:{}", port).parse()?;

    let service = KvService::default();

    log("INFO", &format!("gRPC KV Server listening on {}", addr));
    log("INFO", "Server ready to accept connections");

    Server::builder()
        .tls_config(tls_config)?
        .add_service(KvServer::new(service))
        .serve(addr)
        .await?;

    Ok(())
}
