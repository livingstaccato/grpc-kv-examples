using System;
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
        private static ILogger _logger = null!;

        static async Task Main(string[] args)
        {
            // Setup our logger
            using var loggerFactory = LoggerFactory.Create(builder =>
            {
                builder
                    .AddFilter("CSharpGrpcClient", LogLevel.Debug)
                    .AddConsole();
            });
            _logger = loggerFactory.CreateLogger<Program>();

            // 🔧 Setting up environment variables...
            _logger.LogDebug("🔧 Setting up environment variables...");
            // Load environment variables
            var clientCert = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_CERT") ?? string.Empty;
            var clientKey = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_KEY") ?? string.Empty;
            var serverCert = Environment.GetEnvironmentVariable("PLUGIN_SERVER_CERT") ?? string.Empty;
            var serverEndpoint = Environment.GetEnvironmentVariable("PLUGIN_CS_SERVER_ENDPOINT") ?? "https://localhost:50051";

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
                var clientHelper = new GrpcClientHelper(_logger, clientCert, clientKey, serverCert, serverEndpoint);
                using var channel = clientHelper.CreateChannel();

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
