using System;
using System.Net.Http;
using System.Net.Security;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Threading;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Net.Client;
using Grpc.Net.Client.Configuration;
using Microsoft.Extensions.Logging;

namespace CSharpGrpcClient;

public class GrpcClientHelper : IDisposable
{
    private readonly ILogger _logger;
    private readonly string _serverEndpoint;
    private readonly X509Certificate2 _clientCert;
    private readonly X509Certificate2 _serverCert;
    private readonly HttpClient _httpClient;
    private readonly GrpcChannel _channel;

    public GrpcClientHelper(ILoggerFactory loggerFactory, string clientCertPem, string clientKeyPem, string serverCertPem, string serverEndpoint)
    {
        _logger = loggerFactory.CreateLogger<GrpcClientHelper>();
        _serverEndpoint = serverEndpoint;

        // 🔐📜 Load client certificate
        _logger.LogDebug("🔐📜 Loading client certificate...");
        _clientCert = LoadCertificate(clientCertPem, clientKeyPem);
        _logger.LogDebug("✅✅ Client certificate loaded successfully.");

        // 🛡️📜 Load server certificate from PEM
        _logger.LogDebug("🛡️📜 Loading server certificate from PEM...");
        _serverCert = X509Certificate2.CreateFromPem(serverCertPem);
        _logger.LogDebug("✅✅ Server certificate loaded successfully.");

        // 🔍🪪 Log certificate details
        var certHelper = new CertificateHelper(loggerFactory.CreateLogger<CertificateHelper>());
        certHelper.LogCertificateDetails("Client", _clientCert);
        certHelper.LogCertificateDetails("Server", _serverCert);

        // 🔄🔗 Configure HTTP client handler
        _logger.LogDebug("🔄🔗 Configuring HTTP client handler...");
        var httpClientHandler = new HttpClientHandler();
        httpClientHandler.SslProtocols = SslProtocols.Tls13; // 🎯2️⃣ Force TLS 1.3
        httpClientHandler.ServerCertificateCustomValidationCallback = ValidateServerCertificate;

        // 🔧 HTTP/2 and Tracing
        _logger.LogDebug("🔧 Setting up HTTP/2 and gRPC tracing...");
        AppContext.SetSwitch("System.Net.Http.SocketsHttpHandler.Http2UnencryptedSupport", true);
        AppContext.SetSwitch("System.Net.Http.SocketsHttpHandler.Http2Support", true);
        // remove this line: GrpcChannel.EnableTracing = true;

        // Create an HttpClient with the configured handler
        _httpClient = new HttpClient(httpClientHandler)
        {
            DefaultRequestVersion = new Version(2, 0),
            DefaultVersionPolicy = HttpVersionPolicy.RequestVersionOrHigher
        };

        // 🔄🔗 Configure channel options
        _logger.LogDebug("🔄🔗 Configuring gRPC channel options...");
        var channelOptions = new GrpcChannelOptions
        {
            HttpClient = _httpClient,
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
            },
            LoggerFactory = loggerFactory
        };

        // 🔌🔗 Creating gRPC channel
        _logger.LogDebug("🔌🔗 Creating gRPC channel to {serverEndpoint}...", _serverEndpoint);
        _channel = GrpcChannel.ForAddress(_serverEndpoint, channelOptions);
    }

    public GrpcChannel Channel => _channel;

    private X509Certificate2 LoadCertificate(string certPem, string keyPem = null)
    {
        try
        {
            // 🔧🔑 Loading certificate from PEM data...
            _logger.LogDebug("🔧🔑 Loading certificate from PEM data...");
            if (keyPem == null)
            {
                return X509Certificate2.CreateFromPem(certPem);
            }
            else
            {
                return X509Certificate2.CreateFromPem(certPem, keyPem);
            }
        }
        catch (Exception ex)
        {
            // ❌💥 Error loading certificate from PEM
            _logger.LogError(ex, "❌💥 Error loading certificate from PEM");
            throw;
        }
    }

    private bool ValidateServerCertificate(HttpRequestMessage message, X509Certificate2? certificate, X509Chain? chain, SslPolicyErrors sslPolicyErrors)
    {
        // 🔎🛡️ Basic certificate validation
        _logger.LogDebug("🔎🛡️ Performing basic SSL/TLS policy checks...");

        if (sslPolicyErrors != SslPolicyErrors.None)
        {
            _logger.LogError("❌❌ SSL Policy Errors: {sslPolicyErrors}", sslPolicyErrors);

            // ℹ️⛓️ Log chain status if available
            if (chain != null)
            {
                _logger.LogDebug("ℹ️⛓️ Certificate chain status:");
                foreach (var chainStatus in chain.ChainStatus)
                {
                    _logger.LogDebug("ℹ️⛓️ Chain Status Element: {StatusInformation}", chainStatus.StatusInformation);
                }
            }

            return false;
        }

        _logger.LogDebug("✅✅ Basic SSL/TLS policy checks passed.");

        // 🎯🔍 Check if the server's certificate matches the expected one
        _logger.LogDebug("🎯🔍 Comparing server certificate with expected certificate...");

        if (certificate == null)
        {
            _logger.LogError("❌❌ Server certificate is null.");
            return false;
        }

        if (certificate.Thumbprint != _serverCert.Thumbprint)
        {
            _logger.LogError("❌❌ Server's certificate does not match expected certificate.");
            _logger.LogDebug("👀🏷️ Expected server cert thumbprint: {serverThumbprint}", _serverCert.Thumbprint);
            _logger.LogDebug("👀🪪 Received server cert thumbprint: {remoteThumbprint}", certificate.Thumbprint);
            return false;
        }

        _logger.LogDebug("✅✅ Server certificate is valid.");
        return true;
    }

    public void Dispose()
    {
        // 🗑️ Dispose of the channel and HTTP client
        _logger.LogDebug("🗑️ Disposing of the channel and HTTP client...");
        _channel?.Dispose();
        _httpClient?.Dispose();
        _logger.LogDebug("✅✅ Channel and HTTP client disposed.");
    }
}
