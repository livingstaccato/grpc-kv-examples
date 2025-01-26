Okay, here's a comprehensive C# gRPC client implementation based on your `go-kv-client`, designed to work on Linux and be compatible with your existing infrastructure.

**Project Setup:**

1.  **Create a .NET Core Project:**
    ```bash
    dotnet new console -o CSharpGrpcClient
    cd CSharpGrpcClient
    ```

2.  **Install NuGet Packages:**
    ```bash
    dotnet add package Grpc.Net.Client
    dotnet add package Google.Protobuf
    dotnet add package Grpc.Tools
    ```

3.  **Add `kv.proto`:**
    *   Create a `Protos` directory: `mkdir Protos`
    *   Copy your existing `kv.proto` file into the `Protos` directory.

4.  **Update `CSharpGrpcClient.csproj`:**
    Modify the `.csproj` file to include the proto file and enable gRPC code generation:

    ```xml
    <Project Sdk="Microsoft.NET.Sdk">
    
      <PropertyGroup>
        <OutputType>Exe</OutputType>
        <TargetFramework>net8.0</TargetFramework>
        <ImplicitUsings>enable</ImplicitUsings>
        <Nullable>enable</Nullable>
      </PropertyGroup>
    
      <ItemGroup>
        <PackageReference Include="Google.Protobuf" Version="3.25.2" />
        <PackageReference Include="Grpc.Net.Client" Version="2.60.0" />
        <PackageReference Include="Grpc.Tools" Version="2.60.0">
          <PrivateAssets>all</PrivateAssets>
          <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
        </PackageReference>
      </ItemGroup>
    
      <ItemGroup>
        <Protobuf Include="Protos\kv.proto" GrpcServices="Client" />
      </ItemGroup>
    
    </Project>
    ```

    *   Replace the version numbers with the latest available versions if necessary.

**Code Implementation (Program.cs):**

```csharp
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
```

**Explanation of Changes:**

1.  **Project Setup:** The instructions ensure you have the correct .NET Core project type, necessary NuGet packages, and proper Protobuf compilation settings in your `.csproj` file.
2.  **Certificate Loading:** The code loads the client certificate, client key, and server certificate from files. It uses `X509Certificate2` which is cross-platform.
3.  **gRPC Channel Options:** Sets up a `GrpcChannel` with `SslCredentials` created from your certificates.
4.  **Server Certificate Selection:**
    *   Added logic to use the `RUBY_SERVER_CERT` if it's set and the server endpoint indicates you're connecting to the Ruby server.
    *   Uses the standard `PLUGIN_SERVER_CERT` otherwise.
5.  **Remote Certificate Validation:**
    *   Added a basic `RemoteCertificateValidationCallback` that:
        *   Checks for basic `SslPolicyErrors`.
        *   Compares the received server certificate with the expected certificate (either Ruby's or the default based on the environment variables).
6.  **Error Handling:** Includes a `try-catch` block to handle potential exceptions during the process.
7.  **Comments:** Added comments to clarify different parts of the code.

**How to Run on Linux:**

1.  **Install .NET SDK:** Make sure you have the .NET SDK installed on your Linux machine. You can download it from the official .NET website or use your distribution's package manager.

2.  **Copy Files:** Copy the following files/directories to your Linux machine:
    *   `CSharpGrpcClient` (the entire project directory)
    *   `certs` (your certificate directory)
    *   `proto` (directory with `kv.proto`)

3.  **Set Environment Variables:**
    ```bash
    export PLUGIN_CLIENT_CERT=./certs/ec-secp384r1-mtls-client.crt
    export PLUGIN_CLIENT_KEY=./certs/ec-secp384r1-mtls-client.key
    export PLUGIN_SERVER_CERT=./certs/ec-secp384r1-mtls-server.crt # Go/Python server
    export RUBY_SERVER_CERT=./certs/ec-secp384r1-mtls-server.crt  # Ruby server (update with the correct path if different)
    export PLUGIN_SERVER_ENDPOINT=https://localhost:50051
    # If testing with the Ruby server, also set:
    # export PLUGIN_SERVER_ENDPOINT=https://localhost:50051
    ```

4.  **Build and Run:**
    ```bash
    cd CSharpGrpcClient
    dotnet build
    dotnet run
    ```

**Important Considerations:**

*   **Certificate Paths:** The code assumes the certificates are in a `certs` subdirectory relative to the executable. Adjust the paths in `CreateCredentials` if your certificates are located elsewhere.
*   **Server Name Override:** The `serverNameOverride` variable in `Main` is set to "localhost." This might need to be adjusted if your server certificate's common name (CN) or subject alternative name (SAN) is different.
*   **Error Handling:** This code provides basic error handling. For production, you'll want more robust error handling and logging.
*   **Dependencies:** Ensure that the `Grpc.Net.Client`, `Google.Protobuf`, and `Grpc.Tools` NuGet packages (and their dependencies) are correctly resolved on your Linux system.
*   **mTLS:** The code now explicitly loads the `RUBY_SERVER_CERT` for validation when the endpoint suggests you're targeting the Ruby server. This implements the direct trust needed for your mTLS setup.

This comprehensive C# client should work on Linux and properly handle the certificate verification for both your Go/Python and Ruby servers in your mTLS environment. Remember to adjust paths and environment variables as needed.

