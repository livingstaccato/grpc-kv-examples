using System;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Net.Client;
using Microsoft.Extensions.Logging;
using Grpc.Net.Client.Configuration;

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

        // Load client certificate
        _clientCert = X509Certificate2.CreateFromPem(clientCertPem, clientKeyPem);
        _logger.LogDebug("🔧 Client certificate loaded.");

        // Log client certificate details
        var certHelper = new CertificateHelper(_logger);
        certHelper.LogCertificateDetails("Client", _clientCert);
    }

    public GrpcChannel CreateChannel()
    {
        var serverCert = X509Certificate2.CreateFromPem(_serverCertPem);

        var channelOptions = new GrpcChannelOptions
        {
            HttpHandler = new SocketsHttpHandler
            {
                SslOptions = new SslClientAuthenticationOptions
                {
                    ClientCertificates = new X509Certificate2Collection { _clientCert },
                    RemoteCertificateValidationCallback = (sender, certificate, chain, sslPolicyErrors) =>
                    {
                        // 1. Basic certificate validation
                        if (sslPolicyErrors != SslPolicyErrors.None)
                        {
                            _logger.LogError("❌ SSL Policy Errors: {sslPolicyErrors}", sslPolicyErrors);
                            return false;
                        }

                        // 2. Check if the server's certificate matches the expected one
                        var remoteCert = new X509Certificate2(certificate);
                        if (remoteCert.Thumbprint != serverCert.Thumbprint)
                        {
                            _logger.LogError("❌ Server's certificate does not match expected certificate.");
                            _logger.LogDebug("🔍 Expected server cert thumbprint: {serverThumbprint}", serverCert.Thumbprint);
                            _logger.LogDebug("🔍 Received server cert thumbprint: {remoteThumbprint}", remoteCert.Thumbprint);
                            return false;
                        }

                        // Log certificate details
                        var certHelper = new CertificateHelper(_logger);
                        certHelper.LogCertificateDetails("Server", remoteCert);

                        _logger.LogDebug("✅ Server certificate is valid");
                        return true;
                    }
                }
            },
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

        _logger.LogDebug("🔌 Creating gRPC channel to {serverEndpoint}...", _serverEndpoint);
        return GrpcChannel.ForAddress(_serverEndpoint, channelOptions);
    }
}
