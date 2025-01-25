using System.Security.Cryptography.X509Certificates;
using System.Text;
using Microsoft.Extensions.Logging;

namespace CSharpGrpcClient;

public class CertificateHelper
{
    private readonly ILogger _logger;

    public CertificateHelper(ILogger logger)
    {
        _logger = logger;
    }

    public X509Certificate2 LoadCertificateFromPem(string certPem, string keyPem)
    {
        // 🔧 Loading certificate from PEM data...
        _logger.LogDebug("🔧 Loading certificate from PEM data...");
        try
        {
            return X509Certificate2.CreateFromPem(certPem, keyPem);
        }
        catch (Exception ex)
        {
            // ❌ Error loading certificate from PEM: {ex.Message}
            _logger.LogError("❌ Error loading certificate from PEM: {ex.Message}", ex.Message);
            throw;
        }
    }

    public void LogCertificateDetails(string certType, X509Certificate2 cert)
    {
        _logger.LogDebug("🔍 {certType} Certificate Details:", certType);
        _logger.LogDebug("  📝 Subject: {Subject}", cert.Subject);
        _logger.LogDebug("  📝 Issuer: {Issuer}", cert.Issuer);
        _logger.LogDebug("  ⏰ Valid From: {NotBefore}", cert.NotBefore);
        _logger.LogDebug("  ⏰ Valid Until: {NotAfter}", cert.NotAfter);
        _logger.LogDebug("  🔢 Serial Number: {SerialNumber}", cert.SerialNumber);
        _logger.LogDebug("  📊 Version: {Version}", cert.Version);
        _logger.LogDebug("  🔑 Signature Algorithm: {SignatureAlgorithm}", cert.SignatureAlgorithm.FriendlyName);
        _logger.LogDebug("  🔑 Thumbprint: {Thumbprint}", cert.Thumbprint);

        // Log Key Usage extension
        var keyUsageExtension = cert.Extensions["2.5.29.15"] as X509KeyUsageExtension; // OID for Key Usage
        if (keyUsageExtension != null)
        {
            _logger.LogDebug("  🔑 Key Usage: {KeyUsage}", keyUsageExtension.KeyUsages);
        }
        else
        {
            _logger.LogWarning("  ⚠️ Key Usage extension not found.");
        }

        // Log Extended Key Usage extension
        var extKeyUsageExtension = cert.Extensions["2.5.29.37"] as X509EnhancedKeyUsageExtension; // OID for Extended Key Usage
        if (extKeyUsageExtension != null)
        {
            var usages = new StringBuilder();
            foreach (var oid in extKeyUsageExtension.EnhancedKeyUsages)
            {
                usages.Append($"{oid.FriendlyName ?? oid.Value}, ");
            }
            _logger.LogDebug("  🔑 Extended Key Usage: {ExtKeyUsage}", usages.ToString().TrimEnd(',', ' '));
        }
        else
        {
            _logger.LogWarning("  ⚠️ Extended Key Usage extension not found.");
        }

        // Log Subject Alternative Name extension
        var sanExtension = cert.Extensions["2.5.29.17"]; // OID for Subject Alternative Name
        if (sanExtension != null)
        {
            _logger.LogDebug("  🌐 Subject Alternative Name: {SAN}", sanExtension.Format(true));
        }
        else
        {
            _logger.LogWarning("  ⚠️ Subject Alternative Name extension not found.");
        }

        // Log Basic Constraints extension
        var basicConstraintsExtension = cert.Extensions["2.5.29.19"] as X509BasicConstraintsExtension;
        if (basicConstraintsExtension != null)
        {
            _logger.LogDebug("  📊 Basic Constraints: CA={IsCA}, PathLenConstraint={PathLenConstraint}",
                basicConstraintsExtension.CertificateAuthority,
                basicConstraintsExtension.PathLengthConstraint);
        }
        else
        {
            _logger.LogWarning("  ⚠️ Basic Constraints extension not found.");
        }

        // Log Issuer Alternative Name extension
        var issuerAltNameExtension = cert.Extensions["2.5.29.18"]; // OID for Issuer Alternative Name
        if (issuerAltNameExtension != null)
        {
            _logger.LogDebug("  📝 Issuer Alternative Name: {IssuerAltName}", issuerAltNameExtension.Format(true));
        }
        else
        {
            _logger.LogWarning("  ⚠️ Issuer Alternative Name extension not found.");
        }
    }
}
