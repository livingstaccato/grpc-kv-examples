using System;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Net.Client;
using Microsoft.Extensions.Logging;
using Grpc.Net.Client.Configuration;
using System.Net.Http;

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
        var channelOptions = new GrpcChannelOptions
        {
            HttpHandler = new SocketsHttpHandler
            {
                SslOptions = new SslClientAuthenticationOptions
                {
                    // 🪪⛓️ Client certificates for mTLS
                    ClientCertificates = new X509Certificate2Collection { _clientCert },
                    // 👮🚨 Remote certificate validation callback
                    RemoteCertificateValidationCallback = (sender, certificate, chain, sslPolicyErrors) =>
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
                        var remoteCert = new X509Certificate2(certificate);
                        if (remoteCert.Thumbprint != serverCert.Thumbprint)
                        {
                            _logger.LogError("❌❌ Server's certificate does not match expected certificate.");
                            _logger.LogDebug("👀🏷️ Expected server cert thumbprint: {serverThumbprint}", serverCert.Thumbprint);
                            _logger.LogDebug("👀🪪 Received server cert thumbprint: {remoteThumbprint}", remoteCert.Thumbprint);
                            return false;
                        }

                        // 📋🔍 Log certificate details
                        _logger.LogDebug("📋🔍 Logging server certificate details...");
                        certHelper.LogCertificateDetails("Server", remoteCert);

                        _logger.LogDebug("✅✅ Server certificate is valid.");
                        return true;
                    },
                    // 🎯2️⃣ Force HTTP/2
                    EnabledSslProtocols = System.Security.Authentication.SslProtocols.Tls13
                },
                // 🚀2️⃣ Force HTTP/2
                DefaultVersionPolicy = HttpVersionPolicy.RequestVersionOrHigher,
            },
            // 🔁🔄 Configure service config for retry policy
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
