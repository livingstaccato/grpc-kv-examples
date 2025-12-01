pub mod proto {
    tonic::include_proto!("proto");
}

use chrono::Utc;

pub fn log(level: &str, message: &str) {
    let timestamp = Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ");
    println!("{} [{}]       {}", timestamp, level, message);
}

pub fn log_certificate_info(cert_pem: &str, prefix: &str) {
    // Simple PEM parsing for logging
    if cert_pem.contains("BEGIN CERTIFICATE") {
        log("INFO", &format!("{} Certificate loaded ({} bytes)", prefix, cert_pem.len()));
    }
}
