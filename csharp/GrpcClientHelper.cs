using System;
using System.Net.Security;
using System.Net.Http;
using System.Security.Cryptography.X509Certificates;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Net.Client;
using Microsoft.Extensions.Logging;
using Grpc.Net.Client.Configuration;
using System.Security.Authentication;

namespace CSharpGrpcClient;

public class GrpcClientHelper
{
    private readonly ILogger _logger;
    private readonly string _serverEndpoint;
    private readonly X509Certificate2 _clientCert;
    private readonly string _serverCertPem;

    public GrpcClientHelper(ILogger logger, string clientCertPem, string clientKeyPem, string serverCertPem, string serverEndpoint)
    {
        _logger = logger;
        _serverEndpoint = serverEndpoint;
        _serverCertPem = serverCertPem;

        // 🔐📜 Load client certificate
        _logger.LogDebug("🔐📜 Loading client certificate...");
        _clientCert = X509Certificate2.CreateFromPem(clientCertPem, clientKeyPem);
        _logger.LogDebug("✅✅ Client certificate loaded successfully.");

        // 🔍🪪 Log client certificate details
        _logger.LogDebug("🔍🪪 Logging client certificate details...");
        var certHelper = new CertificateHelper(_logger);
        certHelper.LogCertificateDetails("Client", _clientCert);
    }

    public GrpcChannel CreateChannel()
    {
        // 🛡️📜 Load server certificate from PEM
        _logger.LogDebug("🛡️📜 Loading server certificate from PEM...");
        var serverCert = X509Certificate2.CreateFromPem(_serverCertPem);
        _logger.LogDebug("✅✅ Server certificate loaded successfully.");

        // 🔍📑 Log server certificate details
        _logger.LogDebug("🔍📑 Logging server certificate details...");
        var certHelper = new CertificateHelper(_logger);
        certHelper.LogCertificateDetails("Server", serverCert);

        // 🔄🔗 Configure channel options
        _logger.LogDebug("🔄🔗 Configuring gRPC channel options...");

        // Create an HttpClientHandler
        var httpClientHandler = new HttpClientHandler();

        // 🎯2️⃣ Force TLS 1.3 
        httpClientHandler.SslProtocols = SslProtocols.Tls13;

        // !!! TEMPORARY !!!
        httpClientHandler.ServerCertificateCustomValidationCallback = (message, cert, chain, errors) => { 
            _logger.LogWarning("⚠️⚠️⚠️ WARNING: Skipping server certificate validation. DO NOT USE IN PRODUCTION. ⚠️⚠️⚠️");
            return true; 
        };

        // Create an HttpClient with the configured handler
        var httpClient = new HttpClient(httpClientHandler)
        {
            // 🚀2️⃣ Specify HTTP/2 version
            DefaultRequestVersion = new Version(2, 0),
            DefaultVersionPolicy = HttpVersionPolicy.RequestVersionOrHigher
        };

        var channelOptions = new GrpcChannelOptions
        {
            HttpClient = httpClient,
            ServiceConfig = new ServiceConfig
            {
                MethodConfigs =
                {
                    new MethodConfig
                    {
                        Names = { MethodName.Default },
                        RetryPolicy = new RetryPolicy
                        {
                            MaxAttempts = 5,
                            InitialBackoff = TimeSpan.FromSeconds(1),
                            MaxBackoff = TimeSpan.FromSeconds(5),
                            BackoffMultiplier = 1.5,
                            RetryableStatusCodes = { StatusCode.Unavailable }
                        }
                    }
                }
            }
        };

        // 🔌🔗 Creating gRPC channel
        _logger.LogDebug("🔌🔗 Creating gRPC channel to {serverEndpoint}...", _serverEndpoint);
        return GrpcChannel.ForAddress(_serverEndpoint, channelOptions);
    }
}
