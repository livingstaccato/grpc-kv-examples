using System;
using System.IO;
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Net.Client;
using Proto;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Console;

namespace CSharpGrpcClient
{
    class Program
    {
        private static ILogger? _logger;

        static async Task Main(string[] args)
        {
            // setup our logger
            using var loggerFactory = LoggerFactory.Create(builder =>
            {
                builder
                    .AddFilter("CSharpGrpcClient.Program", LogLevel.Debug)
                    .AddConsole();
            });
            _logger = loggerFactory.CreateLogger<Program>();

            // 🔧 Setting up environment variables...
            _logger.LogDebug("🔧 Setting up environment variables...");
            // Load environment variables (consider using a more robust method for production)
            var clientCert = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_CERT");
            var clientKey = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_KEY");
            var serverCert = Environment.GetEnvironmentVariable("PLUGIN_SERVER_CERT");
            var serverEndpoint = Environment.GetEnvironmentVariable("PLUGIN_SERVER_ENDPOINT") ?? "https://localhost:50051";
            var serverNameOverride = Environment.GetEnvironmentVariable("GRPC_SSL_TARGET_NAME_OVERRIDE") ?? "localhost";

            // 🔍 Logging environment variables for debugging...
            _logger.LogDebug("🔍 PLUGIN_CLIENT_CERT: {clientCert}", !string.IsNullOrEmpty(clientCert) ? "<present>" : "<not set>");
            _logger.LogDebug("🔍 PLUGIN_CLIENT_KEY: {clientKey}", !string.IsNullOrEmpty(clientKey) ? "<present>" : "<not set>");
            _logger.LogDebug("🔍 PLUGIN_SERVER_CERT: {serverCert}", !string.IsNullOrEmpty(serverCert) ? "<present>" : "<not set>");

            if (string.IsNullOrEmpty(clientCert) || string.IsNullOrEmpty(clientKey) || string.IsNullOrEmpty(serverCert))
            {
                // ❌ Error: Missing environment variables...
                _logger.LogError("❌ Error: PLUGIN_CLIENT_CERT, PLUGIN_CLIENT_KEY, or PLUGIN_SERVER_CERT environment variables are not set.");
                return;
            }

            try
            {
                // 🔧 Creating credentials...
                _logger.LogDebug("🔧 Creating credentials...");
                var credentials = CreateCredentials(clientCert, clientKey, serverCert);

                var channelOptions = new GrpcChannelOptions
                {
                    Credentials = credentials,
                    HttpHandler = new SocketsHttpHandler
                    {
                        SslOptions = new SslClientAuthenticationOptions
                        {
                            ClientCertificates = new X509Certificate2Collection { LoadCertificateFromPem(clientCert, clientKey) },
                            RemoteCertificateValidationCallback = (sender, certificate, chain, sslPolicyErrors) =>
                            {
                                // 🔍 Basic certificate validation...
                                _logger.LogDebug("🔍 Basic certificate validation...");
                                if (sslPolicyErrors != SslPolicyErrors.None)
                                {
                                    // ❌ SSL Policy Errors: {sslPolicyErrors}
                                    _logger.LogError("❌ SSL Policy Errors: {sslPolicyErrors}", sslPolicyErrors);
                                    return false;
                                }

                                // 🔍 Check if the server's certificate matches the expected one...
                                _logger.LogDebug("🔍 Check if the server's certificate matches the expected one...");
                                
                                // Important: Use CreateFromPem to load the server certificate string
                                var serverCertObj = X509Certificate2.CreateFromPem(serverCert);

                                if (!certificate.Equals(serverCertObj))
                                {
                                    // ❌ Server's certificate does not match expected certificate.
                                    _logger.LogError("❌ Server's certificate does not match expected certificate.");
                                    return false;
                                }

                                // ✅ Server certificate is valid
                                _logger.LogDebug("✅ Server certificate is valid");
                                return true;
                            }
                        }
                    }
                };

                // Create a channel (consider reusing channels in production)
                // 🔌 Creating gRPC channel...
                _logger.LogDebug("🔌 Creating gRPC channel...");
                using var channel = GrpcChannel.ForAddress(serverEndpoint, channelOptions);

                // Create a client
                // 👥 Creating gRPC client...
                _logger.LogDebug("👥 Creating gRPC client...");
                var client = new KV.KVClient(channel);

                // Send a Get request
                // 📡 Sending Get request...
                _logger.LogDebug("📡 Sending Get request...");
                var response = await client.GetAsync(new GetRequest { Key = "test" });

                // ✨ Response: {response.Value}
                _logger.LogInformation("✨ Response: {response.Value}", response.Value);
            }
            catch (Exception ex)
            {
                // ❌ Error: {ex.Message}
                _logger.LogError("❌ Error: {ex.Message}", ex.Message);
                if (ex.InnerException != null)
                {
                    // ❌ Inner Exception: {ex.InnerException.Message}
                    _logger.LogError("❌ Inner Exception: {ex.InnerException.Message}", ex.InnerException.Message);
                }
            }
        }

        static X509Certificate2 LoadCertificateFromPem(string certPem, string keyPem)
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

        static SslCredentials CreateCredentials(string clientCert, string clientKey, string serverCert)
        {
            // 🔧 Loading client certificate and key...
            _logger.LogDebug("🔧 Loading client certificate and key...");

            // 🔑 Creating key certificate pair...
            _logger.LogDebug("🔑 Creating key certificate pair...");
            var keyCertPair = new KeyCertificatePair(clientCert, clientKey);

            // 🔒 Creating credentials...
            _logger.LogDebug("🔒 Creating credentials...");
            return new SslCredentials(serverCert, keyCertPair);
        }
    }
}
