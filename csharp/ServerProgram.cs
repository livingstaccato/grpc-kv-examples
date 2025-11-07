using System.Net;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.AspNetCore.Server.Kestrel.Https;
using Serilog;
using CSharpGrpcServer;

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Debug()
    .WriteTo.Console(
        outputTemplate: "{Timestamp:HH:mm:ss} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

try
{
    Log.Information("🚀 🔄 Starting C# gRPC Server... 🌟");

    var builder = WebApplication.CreateBuilder(args);

    // Add Serilog
    builder.Host.UseSerilog();

    // Add gRPC services
    builder.Services.AddGrpc();

    // Load certificates from environment variables
    Log.Debug("📂 Loading certificates from environment... 🔍");

    var serverCertPem = Environment.GetEnvironmentVariable("PLUGIN_SERVER_CERT");
    var serverKeyPem = Environment.GetEnvironmentVariable("PLUGIN_SERVER_KEY");
    var clientCertPem = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_CERT");

    if (string.IsNullOrEmpty(serverCertPem) || string.IsNullOrEmpty(serverKeyPem) || string.IsNullOrEmpty(clientCertPem))
    {
        Log.Fatal("❌ Missing certificate environment variables. Run: source env.sh");
        return 1;
    }

    Log.Debug("📦 Certificate sizes:");
    Log.Debug("📦   Server Cert: {ServerCertSize} bytes", serverCertPem.Length);
    Log.Debug("📦   Server Key: {ServerKeySize} bytes", serverKeyPem.Length);
    Log.Debug("📦   Client CA Cert: {ClientCertSize} bytes", clientCertPem.Length);

    // Create certificates
    var serverCert = X509Certificate2.CreateFromPem(serverCertPem, serverKeyPem);
    var clientCaCert = X509Certificate2.CreateFromPem(clientCertPem);

    Log.Debug("🔐 Server Certificate Details:");
    LogCertificateDetails(serverCert);

    Log.Debug("🔐 Client CA Certificate Details:");
    LogCertificateDetails(clientCaCert);

    // Get port configuration
    var port = int.Parse(Environment.GetEnvironmentVariable("PLUGIN_PORT") ?? "50051");
    var host = Environment.GetEnvironmentVariable("PLUGIN_HOST") ?? "localhost";

    // Configure Kestrel
    builder.WebHost.ConfigureKestrel(options =>
    {
        Log.Information("🔧 Configuring Kestrel for gRPC with mTLS...");

        options.Listen(IPAddress.Any, port, listenOptions =>
        {
            listenOptions.Protocols = HttpProtocols.Http2;

            listenOptions.UseHttps(httpsOptions =>
            {
                httpsOptions.ServerCertificate = serverCert;

                // Configure client certificate validation (mTLS)
                httpsOptions.ClientCertificateMode = ClientCertificateMode.RequireCertificate;

                httpsOptions.ClientCertificateValidation = (clientCert, chain, policyErrors) =>
                {
                    Log.Debug("🔐 📜 Validating client certificate...");
                    Log.Debug("🔐 Client Certificate:");
                    LogCertificateDetails(clientCert);

                    // Build and validate the certificate chain
                    using var certChain = new X509Chain();

                    // Add our CA certificate to the extra store
                    certChain.ChainPolicy.ExtraStore.Add(clientCaCert);

                    // Configure chain policy for self-signed certificates
                    certChain.ChainPolicy.VerificationFlags = X509VerificationFlags.AllowUnknownCertificateAuthority;
                    certChain.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;

                    Log.Debug("🔗 Building certificate chain...");
                    bool chainValid = certChain.Build(clientCert);

                    if (chainValid)
                    {
                        Log.Debug("🔗 Certificate chain built successfully");

                        // Verify the chain ends with our trusted CA
                        var rootCert = certChain.ChainElements[certChain.ChainElements.Count - 1].Certificate;
                        bool isValid = rootCert.Thumbprint == clientCaCert.Thumbprint;

                        if (isValid)
                        {
                            Log.Information("✅ Client certificate validated successfully 🔒");
                            Log.Debug("✅ Chain length: {ChainLength}", certChain.ChainElements.Count);
                        }
                        else
                        {
                            Log.Warning("⚠️  Certificate chain does not end with trusted CA");
                            Log.Debug("Expected CA thumbprint: {Expected}", clientCaCert.Thumbprint);
                            Log.Debug("Actual root thumbprint: {Actual}", rootCert.Thumbprint);
                        }

                        return isValid;
                    }
                    else
                    {
                        Log.Warning("⚠️  Failed to build certificate chain");
                        foreach (var status in certChain.ChainStatus)
                        {
                            Log.Warning("⚠️  Chain status: {Status} - {Information}", status.Status, status.StatusInformation);
                        }
                        return false;
                    }
                };

                // TLS configuration
                httpsOptions.SslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13;

                Log.Debug("🔧 TLS Protocols: TLS 1.2, TLS 1.3");
            });

            Log.Information("🌐 Server bound to {Host}:{Port}", host, port);
        });
    });

    var app = builder.Build();

    // Map gRPC service
    app.MapGrpcService<KVServiceImpl>();

    Log.Information("📋 Registered KVService implementation");
    Log.Information("✅ Server configured successfully 🔒");
    Log.Information("🎧 Listening on {Host}:{Port} - Ready to accept connections! 🚀", host, port);

    await app.RunAsync();

    return 0;
}
catch (Exception ex)
{
    Log.Fatal(ex, "❌ Server terminated unexpectedly");
    return 1;
}
finally
{
    Log.CloseAndFlush();
}

// Helper method to log certificate details
static void LogCertificateDetails(X509Certificate2 cert)
{
    Log.Debug("  📝 Subject: {Subject}", cert.Subject);
    Log.Debug("  📝 Issuer: {Issuer}", cert.Issuer);
    Log.Debug("  ⏰ Valid From: {NotBefore}", cert.NotBefore);
    Log.Debug("  ⏰ Valid Until: {NotAfter}", cert.NotAfter);
    Log.Debug("  🔢 Serial Number: {SerialNumber}", cert.SerialNumber);
    Log.Debug("  📊 Version: {Version}", cert.Version);
    Log.Debug("  🔑 Signature Algorithm: {SignatureAlgorithm}", cert.SignatureAlgorithm.FriendlyName);
    Log.Debug("  🔑 Thumbprint: {Thumbprint}", cert.Thumbprint);

    // Key usage
    foreach (var extension in cert.Extensions)
    {
        if (extension is X509KeyUsageExtension keyUsage)
        {
            Log.Debug("  🔑 Key Usage: {KeyUsage}", keyUsage.KeyUsages);
        }
        else if (extension is X509EnhancedKeyUsageExtension enhancedKeyUsage)
        {
            var usages = string.Join(", ", enhancedKeyUsage.EnhancedKeyUsages.Cast<System.Security.Cryptography.Oid>().Select(o => o.Value));
            Log.Debug("  🔑 Enhanced Key Usage: {EnhancedKeyUsage}", usages);
        }
        else if (extension is X509SubjectAlternativeNameExtension san)
        {
            Log.Debug("  🌐 Subject Alternative Name: {SAN}", san.Format(false));
        }
        else if (extension is X509BasicConstraintsExtension basicConstraints)
        {
            Log.Debug("  📊 Basic Constraints: CA={CA}, PathLenConstraint={PathLen}",
                basicConstraints.CertificateAuthority,
                basicConstraints.HasPathLengthConstraint ? basicConstraints.PathLengthConstraint.ToString() : "None");
        }
    }
}
