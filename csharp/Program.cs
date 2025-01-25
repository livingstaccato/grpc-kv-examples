using System;
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;
using Grpc.Net.Client;
using Proto;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Console;

namespace CSharpGrpcClient;

internal class Program
{
    private static ILogger _logger = null!;

    private static async Task Main(string[] args)
    {
        // Setup our logger
        using var loggerFactory = LoggerFactory.Create(builder =>
        {
            builder
                .AddFilter("CSharpGrpcClient.Program", LogLevel.Debug)
                .AddConsole();
        });
        _logger = loggerFactory.CreateLogger<Program>();

        // 🔧 Setting up environment variables...
        _logger.LogDebug("🔧 Setting up environment variables...");
        // Load environment variables
        var clientCert = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_CERT") ?? string.Empty;
        var clientKey = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_KEY") ?? string.Empty;
        var serverCert = Environment.GetEnvironmentVariable("PLUGIN_SERVER_CERT") ?? string.Empty;
        var serverEndpoint = Environment.GetEnvironmentVariable("PLUGIN_SERVER_ENDPOINT") ?? "https://localhost:50051";

        // 🔍 Logging environment variables for debugging...
        _logger.LogDebug("🔍 PLUGIN_CLIENT_CERT: {ClientCert}", !string.IsNullOrEmpty(clientCert) ? "<present>" : "<not set>");
        _logger.LogDebug("🔍 PLUGIN_CLIENT_KEY: {ClientKey}", !string.IsNullOrEmpty(clientKey) ? "<present>" : "<not set>");
        _logger.LogDebug("🔍 PLUGIN_SERVER_CERT: {ServerCert}", !string.IsNullOrEmpty(serverCert) ? "<present>" : "<not set>");

        if (string.IsNullOrEmpty(clientCert) || string.IsNullOrEmpty(clientKey) || string.IsNullOrEmpty(serverCert))
        {
            // ❌ Error: Missing environment variables...
            _logger.LogError("❌ Error: PLUGIN_CLIENT_CERT, PLUGIN_CLIENT_KEY, or PLUGIN_SERVER_CERT environment variables are not set.");
            return;
        }

        try
        {
            // 🔧 Creating client certificate collection...
            _logger.LogDebug("🔧 Creating client certificate collection...");
            var clientCertificates = new X509Certificate2Collection
            {
                X509Certificate2.CreateFromPem(clientCert, clientKey)
            };

            // 🔍 Logging client certificate details...
            LogCertificateDetails("Client", clientCertificates[0]);

            // Create an HttpClientHandler
            var handler = new HttpClientHandler
            {
                ClientCertificates = clientCertificates,
                ServerCertificateCustomValidationCallback = (sender, cert, chain, sslPolicyErrors) =>
                {
                    // 🔍 Basic certificate validation...
                    _logger.LogDebug("🔍 Basic certificate validation...");
                    if (sslPolicyErrors != SslPolicyErrors.None)
                    {
                        // ❌ SSL Policy Errors: {sslPolicyErrors}
                        _logger.LogError("❌ SSL Policy Errors: {SslPolicyErrors}", sslPolicyErrors);

                        // 🔍 Log details about the chain
                        if (chain != null)
                        {
                            _logger.LogDebug("🔍 Certificate chain status: {ChainStatus}", (object)chain.ChainStatus);
                            foreach (var chainStatus in chain.ChainStatus)
                            {
                                _logger.LogDebug("🔍 Chain Status Element: {StatusInformation}", chainStatus.StatusInformation);
                            }

                            _logger.LogDebug("🔍 Certificate chain elements:");
                            foreach (var chainElement in chain.ChainElements)
                            {
                                _logger.LogDebug("🔍 Chain Element Subject: {Subject}", chainElement.Certificate.Subject);
                                _logger.LogDebug("🔍 Chain Element Issuer: {Issuer}", chainElement.Certificate.Issuer);
                                _logger.LogDebug("🔍 Chain Element Status: {Status}", (object)chainElement.ChainElementStatus);
                            }
                        }

                        return false;
                    }

                    // 🔍 Check if the server's certificate matches the expected one...
                    _logger.LogDebug("🔍 Check if the server's certificate matches the expected one...");

                    if (cert == null)
                    {
                        _logger.LogError("❌ Server certificate is null.");
                        return false;
                    }

                    var remoteCert = new X509Certificate2(cert);

                    // 🔍 Logging server certificate details...
                    LogCertificateDetails("Server", remoteCert);

                    var serverCertObj = X509Certificate2.CreateFromPem(serverCert);

                    // Compare certificate thumbprints
                    if (remoteCert.Thumbprint != serverCertObj.Thumbprint)
                    {
                        // ❌ Server's certificate does not match expected certificate.
                        _logger.LogError("❌ Server's certificate does not match expected certificate.");
                        _logger.LogDebug("🔍 Expected server cert thumbprint: {ServerThumbprint}", serverCertObj.Thumbprint);
                        _logger.LogDebug("🔍 Received server cert thumbprint: {RemoteThumbprint}", remoteCert.Thumbprint);
                        return false;
                    }

                    // ✅ Server certificate is valid
                    _logger.LogDebug("✅ Server certificate is valid");
                    return true;
                }
            };

            // Create a channel with the HttpClientHandler
            // 🔌 Creating gRPC channel...
            _logger.LogDebug("🔌 Creating gRPC channel...");
            using var channel = GrpcChannel.ForAddress(serverEndpoint, new GrpcChannelOptions
            {
                HttpHandler = handler
            });

            // Create a client
            // 👥 Creating gRPC client...
            _logger.LogDebug("👥 Creating gRPC client...");
            var client = new KV.KVClient(channel);

            // Send a Get request
            // 📡 Sending Get request...
            _logger.LogDebug("📡 Sending Get request...");
            var response = await client.GetAsync(new GetRequest { Key = "test" });

            // ✨ Response: {response.Value}
            _logger.LogInformation("✨ Response: {ResponseValue}", response.Value);
        }
        catch (Exception ex)
        {
            // ❌ Error: {ex.Message}
            _logger.LogError("❌ Error: {ExMessage}", ex.Message);
            if (ex.InnerException != null)
            {
                // ❌ Inner Exception: {ex.InnerException.Message}
                _logger.LogError("❌ Inner Exception: {InnerExceptionMessage}", ex.InnerException.Message);
            }
        }
    }

    private static void LogCertificateDetails(string certType, X509Certificate2 cert)
    {
        _logger.LogDebug("🔍 {CertType} Certificate Details:", certType);
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
