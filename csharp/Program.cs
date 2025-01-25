using System;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography.X509Certificates;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Net.Client;
using Proto; // This namespace will be generated from your kv.proto

namespace CSharpGrpcClient
{
    class Program
    {
        static async Task Main(string[] args)
        {
            // Load environment variables (consider using a more robust method for production)
            var clientCert = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_CERT");
            var clientKey = Environment.GetEnvironmentVariable("PLUGIN_CLIENT_KEY");
            var serverCert = Environment.GetEnvironmentVariable("PLUGIN_SERVER_CERT");
            var serverEndpoint = Environment.GetEnvironmentVariable("PLUGIN_SERVER_ENDPOINT") ?? "https://localhost:50051";
            var serverNameOverride = Environment.GetEnvironmentVariable("GRPC_SSL_TARGET_NAME_OVERRIDE") ?? "localhost";
            var rubyServerCert = Environment.GetEnvironmentVariable("RUBY_SERVER_CERT");

            if (string.IsNullOrEmpty(clientCert) || string.IsNullOrEmpty(clientKey))
            {
                Console.WriteLine("Error: PLUGIN_CLIENT_CERT or PLUGIN_CLIENT_KEY environment variables are not set.");
                return;
            }

            try
            {
                // Create credentials
                var credentials = CreateCredentials(clientCert, clientKey, serverCert);

                // Use the appropriate server certificate based on the target.
                if (!string.IsNullOrEmpty(rubyServerCert) && serverEndpoint.Contains("ruby"))
                {
                    Console.WriteLine("Using Ruby server certificate for connection.");
                    credentials = CreateCredentials(clientCert, clientKey, rubyServerCert);
                }
                else
                {
                  Console.WriteLine("Using default server certificate for connection.");
                  credentials = CreateCredentials(clientCert, clientKey, serverCert);
                }

                var channelOptions = new GrpcChannelOptions
                {
                    Credentials = credentials,
                    HttpHandler = new SocketsHttpHandler
                    {
                        SslOptions = new System.Net.Security.SslClientAuthenticationOptions
                        {
                            ClientCertificates = new X509Certificate2Collection
                            {
                                new X509Certificate2(
                                    X509Certificate.CreateFromCertFile(Path.GetTempFileName()).Export(X509ContentType.Pfx), "")
                            },
                            RemoteCertificateValidationCallback = (sender, certificate, chain, sslPolicyErrors) =>
                            {
                                // basic certificate validation
                                if (sslPolicyErrors != System.Net.Security.SslPolicyErrors.None)
                                {
                                    Console.WriteLine($"SSL Policy Errors: {sslPolicyErrors}");
                                    return false;
                                }

                                // check if the server's certificate matches the expected one
                                var expectedCert = new X509Certificate2(
                                    string.IsNullOrEmpty(rubyServerCert) ? 
                                    serverCert : 
                                    rubyServerCert);

                                if (!certificate.Equals(expectedCert))
                                {
                                    Console.WriteLine("Server's certificate does not match expected certificate.");
                                    return false;
                                }

                                return true;
                            }
                        }
                    }
                };

                // Create a channel (consider reusing channels in production)
                using var channel = GrpcChannel.ForAddress(serverEndpoint, channelOptions);

                // Create a client
                var client = new KV.KVClient(channel);

                // Send a Get request
                Console.WriteLine("Sending Get request...");
                var response = await client.GetAsync(new GetRequest { Key = "test" });

                Console.WriteLine("Response: " + response.Value.ToStringUtf8());
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"Inner Exception: {ex.InnerException.Message}");
                }
            }
        }

        static SslCredentials CreateCredentials(string clientCert, string clientKey, string? serverCert = null)
        {
          // Load client certificate and key
          var clientCertData = File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "certs", clientCert));
          var clientKeyData = File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "certs", clientKey));
          var clientCertPem = new X509Certificate2(X509Certificate.CreateFromCertFile(Path.Combine(Directory.GetCurrentDirectory(), "certs", clientCert)).Export(X509ContentType.Pfx), "");

          // Load server certificate if provided
          X509Certificate2? serverCertPem = null;
          if (!string.IsNullOrEmpty(serverCert))
          {
            var serverCertData = File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "certs", serverCert));
            serverCertPem = new X509Certificate2(X509Certificate.CreateFromCertFile(Path.Combine(Directory.GetCurrentDirectory(), "certs", serverCert)));
          }

          // Create credentials
          var credentials = new SslCredentials(
            serverCertPem?.ExportCertificatePem(),
            new KeyCertificatePair(clientCertPem.ExportCertificatePem(), clientKeyData));

          return credentials;
        }
    }
}
