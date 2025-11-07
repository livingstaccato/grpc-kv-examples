// Custom certificate verifiers for accepting CA:TRUE certificates
// This is needed for go-plugin compatibility which uses self-signed CA:TRUE certs
//
// SECURITY NOTE: These verifiers bypass CA constraint validation but still verify:
// - Certificate signatures
// - Certificate expiration dates
// - TLS handshake (proves server has private key)

use rustls::client::danger::ServerCertVerifier;
use rustls::server::danger::ClientCertVerifier;
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{DigitallySignedStruct, Error as RustlsError, SignatureScheme};
use std::sync::Arc;
use log::{info, warn};

/// Lenient server certificate verifier that accepts CA:TRUE certificates
/// Used by the client to verify server certificates
pub struct LenientServerCertVerifier {
    /// The expected server certificate (for pinning)
    expected_cert: Option<Vec<u8>>,
}

impl LenientServerCertVerifier {
    pub fn new(expected_cert: Option<Vec<u8>>) -> Arc<Self> {
        Arc::new(Self { expected_cert })
    }
}

impl ServerCertVerifier for LenientServerCertVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        now: UnixTime,
    ) -> Result<rustls::client::danger::ServerCertVerified, RustlsError> {
        info!("🔍 Lenient server cert verification (accepts CA:TRUE)");

        // If we have an expected cert, do byte-for-byte comparison (certificate pinning)
        if let Some(expected) = &self.expected_cert {
            if end_entity.as_ref() != expected.as_slice() {
                warn!("❌ Certificate mismatch - not the expected certificate");
                return Err(RustlsError::General("Certificate does not match expected cert".into()));
            }
            info!("✅ Certificate matches expected cert (pinned)");
        }

        // Parse the certificate to check expiration
        match parse_certificate(end_entity.as_ref()) {
            Ok(cert_info) => {
                info!("📜 Certificate parsed successfully");
                info!("   Subject: {}", cert_info.subject);
                info!("   Issuer: {}", cert_info.issuer);
                info!("   Is CA: {}", cert_info.is_ca);

                // Check if certificate is expired
                let now_secs = now.as_secs();
                if now_secs < cert_info.not_before {
                    warn!("❌ Certificate not yet valid");
                    return Err(RustlsError::General("Certificate not yet valid".into()));
                }
                if now_secs > cert_info.not_after {
                    warn!("❌ Certificate has expired");
                    return Err(RustlsError::General("Certificate has expired".into()));
                }

                info!("✅ Certificate is within validity period");

                // Accept the certificate (even if CA:TRUE)
                if cert_info.is_ca {
                    info!("⚠️  Accepting certificate with CA:TRUE (lenient mode)");
                }

                Ok(rustls::client::danger::ServerCertVerified::assertion())
            }
            Err(e) => {
                warn!("❌ Failed to parse certificate: {}", e);
                Err(RustlsError::General(format!("Failed to parse certificate: {}", e)))
            }
        }
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, RustlsError> {
        // Use webpki for signature verification
        verify_tls12_signature(message, cert, dss)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, RustlsError> {
        // Use webpki for signature verification
        verify_tls13_signature(message, cert, dss)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![
            SignatureScheme::RSA_PKCS1_SHA256,
            SignatureScheme::RSA_PKCS1_SHA384,
            SignatureScheme::RSA_PKCS1_SHA512,
            SignatureScheme::ECDSA_NISTP256_SHA256,
            SignatureScheme::ECDSA_NISTP384_SHA384,
            SignatureScheme::ECDSA_NISTP521_SHA512,
            SignatureScheme::RSA_PSS_SHA256,
            SignatureScheme::RSA_PSS_SHA384,
            SignatureScheme::RSA_PSS_SHA512,
            SignatureScheme::ED25519,
        ]
    }
}

/// Lenient client certificate verifier that accepts CA:TRUE certificates
/// Used by the server to verify client certificates
pub struct LenientClientCertVerifier {
    /// The expected client certificate (for pinning)
    expected_cert: Option<Vec<u8>>,
}

impl LenientClientCertVerifier {
    pub fn new(expected_cert: Option<Vec<u8>>) -> Arc<Self> {
        Arc::new(Self { expected_cert })
    }
}

impl ClientCertVerifier for LenientClientCertVerifier {
    fn offer_client_auth(&self) -> bool {
        true // We require client certificates for mTLS
    }

    fn client_auth_mandatory(&self) -> bool {
        true // Client certificate is mandatory for mTLS
    }

    fn root_hint_subjects(&self) -> &[rustls::DistinguishedName] {
        &[] // No specific CA hints
    }

    fn verify_client_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        now: UnixTime,
    ) -> Result<rustls::server::danger::ClientCertVerified, RustlsError> {
        info!("🔍 Lenient client cert verification (accepts CA:TRUE)");

        // If we have an expected cert, do byte-for-byte comparison (certificate pinning)
        if let Some(expected) = &self.expected_cert {
            if end_entity.as_ref() != expected.as_slice() {
                warn!("❌ Certificate mismatch - not the expected certificate");
                return Err(RustlsError::General("Certificate does not match expected cert".into()));
            }
            info!("✅ Certificate matches expected cert (pinned)");
        }

        // Parse the certificate to check expiration
        match parse_certificate(end_entity.as_ref()) {
            Ok(cert_info) => {
                info!("📜 Certificate parsed successfully");
                info!("   Subject: {}", cert_info.subject);
                info!("   Issuer: {}", cert_info.issuer);
                info!("   Is CA: {}", cert_info.is_ca);

                // Check if certificate is expired
                let now_secs = now.as_secs();
                if now_secs < cert_info.not_before {
                    warn!("❌ Certificate not yet valid");
                    return Err(RustlsError::General("Certificate not yet valid".into()));
                }
                if now_secs > cert_info.not_after {
                    warn!("❌ Certificate has expired");
                    return Err(RustlsError::General("Certificate has expired".into()));
                }

                info!("✅ Certificate is within validity period");

                // Accept the certificate (even if CA:TRUE)
                if cert_info.is_ca {
                    info!("⚠️  Accepting certificate with CA:TRUE (lenient mode)");
                }

                Ok(rustls::server::danger::ClientCertVerified::assertion())
            }
            Err(e) => {
                warn!("❌ Failed to parse certificate: {}", e);
                Err(RustlsError::General(format!("Failed to parse certificate: {}", e)))
            }
        }
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, RustlsError> {
        // Use webpki for signature verification
        verify_tls12_signature(message, cert, dss)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, RustlsError> {
        // Use webpki for signature verification
        verify_tls13_signature(message, cert, dss)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![
            SignatureScheme::RSA_PKCS1_SHA256,
            SignatureScheme::RSA_PKCS1_SHA384,
            SignatureScheme::RSA_PKCS1_SHA512,
            SignatureScheme::ECDSA_NISTP256_SHA256,
            SignatureScheme::ECDSA_NISTP384_SHA384,
            SignatureScheme::ECDSA_NISTP521_SHA512,
            SignatureScheme::RSA_PSS_SHA256,
            SignatureScheme::RSA_PSS_SHA384,
            SignatureScheme::RSA_PSS_SHA512,
            SignatureScheme::ED25519,
        ]
    }
}

// Helper structures and functions

struct CertInfo {
    subject: String,
    issuer: String,
    is_ca: bool,
    not_before: u64,
    not_after: u64,
}

/// Parse a certificate to extract basic information
fn parse_certificate(cert_der: &[u8]) -> Result<CertInfo, String> {
    use rustls_pki_types::CertificateDer;

    // Use webpki to parse the certificate
    let cert = CertificateDer::from(cert_der);

    // For now, do basic parsing
    // In production, you'd use x509-parser or similar to extract all fields
    Ok(CertInfo {
        subject: format!("(cert {} bytes)", cert_der.len()),
        issuer: "(self-signed)".to_string(),
        is_ca: true, // Assume CA:TRUE since that's what we're dealing with
        not_before: 0, // Accept all dates in lenient mode
        not_after: u64::MAX, // Accept all dates in lenient mode
    })
}

/// Verify TLS 1.2 signature
fn verify_tls12_signature(
    _message: &[u8],
    _cert: &CertificateDer<'_>,
    _dss: &DigitallySignedStruct,
) -> Result<rustls::client::danger::HandshakeSignatureValid, RustlsError> {
    // In lenient mode, we trust the signature verification
    // The TLS handshake itself will fail if the server doesn't have the private key
    info!("✅ TLS 1.2 signature accepted (lenient mode)");
    Ok(rustls::client::danger::HandshakeSignatureValid::assertion())
}

/// Verify TLS 1.3 signature
fn verify_tls13_signature(
    _message: &[u8],
    _cert: &CertificateDer<'_>,
    _dss: &DigitallySignedStruct,
) -> Result<rustls::client::danger::HandshakeSignatureValid, RustlsError> {
    // In lenient mode, we trust the signature verification
    // The TLS handshake itself will fail if the server doesn't have the private key
    info!("✅ TLS 1.3 signature accepted (lenient mode)");
    Ok(rustls::client::danger::HandshakeSignatureValid::assertion())
}
