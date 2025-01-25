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

                // Create a collection for client certificates
                var clientCertificates = new X509Certificate2Collection();
                clientCertificates.Add(X509Certificate2.CreateFromPem(clientCert, clientKey));

                var channelOptions = new GrpcChannelOptions
                {
                    Credentials = ChannelCredentials.Create(new SslCredentials(serverCert), CallCredentials.FromInterceptor((ctx, meta) =>
                    {
                        return Task.CompletedTask;
                    })),
                    HttpHandler = new SocketsHttpHandler
                    {
                        SslOptions = new SslClientAuthenticationOptions
                        {
                            ClientCertificates = clientCertificates,
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

                                // Handle null certificate
                                if (certificate == null)
                                {
                                    _logger.LogError("❌ Server certificate is null.");
                                    return false;
                                }
                                var remoteCert = new X509Certificate2(certificate);
                                var serverCertObj = X509Certificate2.CreateFromPem(serverCert);

                                // Compare certificate thumbprints
                                if (remoteCert.Thumbprint != serverCertObj.Thumbprint)
                                {
                                    // ❌ Server's certificate does not match expected certificate.
                                    _logger.LogError("❌ Server's certificate does not match expected certificate.");
                                    _logger.LogDebug("🔍 Expected server cert thumbprint: {serverThumbprint}", serverCertObj.Thumbprint);
                                    _logger.LogDebug("🔍 Received server cert thumbprint: {remoteThumbprint}", remoteCert.Thumbprint);
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
    }
}
