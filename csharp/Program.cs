using System;
using System.Threading.Tasks;
using Grpc.Net.Client;
using Microsoft.Extensions.Logging;
using Proto;
using Grpc.Core;
using Serilog;
using Serilog.Extensions.Logging;

namespace CSharpGrpcClient;

class Program
{
    private static ILoggerFactory _loggerFactory = null!; // Add null-forgiving operator

    static async Task Main(string[] args)
    {
        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Debug()
            .WriteTo.Console(outputTemplate: "{Timestamp:HH:mm:ss} [{Level:u3}] {Message:lj}{NewLine}")
            .CreateLogger();

        _loggerFactory = LoggerFactory.Create(builder =>
            builder.AddSerilog(Log.Logger));

        var logger = _loggerFactory.CreateLogger<Program>();

        // 🔧 Setting up environment variables...
        logger.LogDebug("🔧 Setting up environment variables...");

        // Load environment variables
        var clientCert = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_CERT") ?? string.Empty;
        var clientKey = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_KEY") ?? string.Empty;
        var serverCert = Environment.GetEnvironmentVariable("PLUGIN_SERVER_CERT") ?? string.Empty;
        var serverEndpoint = Environment.GetEnvironmentVariable("PLUGIN_CS_SERVER_ENDPOINT") ?? "http://localhost:50051";

        // 🔍 Logging environment variables for debugging...
        logger.LogDebug("🔍 PLUGIN_CLIENT_CERT: {clientCert}", !string.IsNullOrEmpty(clientCert) ? "<present>" : "<not set>");
        logger.LogDebug("🔍 PLUGIN_CLIENT_KEY: {clientKey}", !string.IsNullOrEmpty(clientKey) ? "<present>" : "<not set>");
        logger.LogDebug("🔍 PLUGIN_SERVER_CERT: {serverCert}", !string.IsNullOrEmpty(serverCert) ? "<present>" : "<not set>");

        if (string.IsNullOrEmpty(clientCert) || string.IsNullOrEmpty(clientKey) || string.IsNullOrEmpty(serverCert))
        {
            // ❌ Error: Missing environment variables...
            logger.LogError("❌ Error: PLUGIN_CLIENT_CERT, PLUGIN_CLIENT_KEY, or PLUGIN_SERVER_CERT environment variables are not set.");
            return;
        }

        try
        {
            // Use 'using' so that GrpcClientHelper is disposed of properly
            using var clientHelper = new GrpcClientHelper(_loggerFactory, clientCert, clientKey, serverCert, serverEndpoint);
            using var channel = clientHelper.Channel;

            // Create a client
            // 👥 Creating gRPC client...
            logger.LogDebug("👥 Creating gRPC client...");
            var client = new KV.KVClient(channel);

            // Send a Get request
            // 📡 Sending Get request...
            logger.LogDebug("📡 Sending Get request...");
            var response = await client.GetAsync(new GetRequest { Key = "test" });

            // ✨ Response: {response.Value}
            logger.LogInformation("✨ Response: {response.Value}", response.Value);
        }
        catch (Exception ex)
        {
            // ❌ Error: {ex.Message}
            logger.LogError(ex, "❌ Error");
        }
        finally
        {
            // Dispose the logger factory
            _loggerFactory.Dispose();
        }
    }
}
