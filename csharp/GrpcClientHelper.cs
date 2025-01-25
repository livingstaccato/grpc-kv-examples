using System;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Net.Client;
using Microsoft.Extensions.Logging;

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
        var channelOptions = new GrpcChannelOptions
        {
            HttpHandler = new SocketsHttpHandler
            {
                SslOptions = new SslClientAuthenticationOptions
                {
                    ClientCertificates = new X509Certificate2Collection { _clientCert },
                    RemoteCertificateValidationCallback = ValidateServerCertificate
                }
            }
        };

        _logger.LogDebug("🔌 Creating gRPC channel to {serverEndpoint}...", _serverEndpoint);
        return GrpcChannel.ForAddress(_serverEndpoint, channelOptions);
    }

    private bool ValidateServerCertificate(object sender, X509Certificate? certificate, X509Chain? chain, SslPolicyErrors sslPolicyErrors)
    {
        // 🔍 Basic certificate validation...
        _logger.LogDebug("🔍 Basic certificate validation...");
        if (sslPolicyErrors != SslPolicyErrors.None)
        {
            // ❌ SSL Policy Errors: {sslPolicyErrors}
            _logger.LogError("❌ SSL Policy Errors: {sslPolicyErrors}", sslPolicyErrors);

            // 🔍 Log details about the chain
            if (chain != null)
            {
                _logger.LogDebug("🔍 Certificate chain status: {ChainStatus}", (object)chain.ChainStatus);
                foreach (var chainStatus in chain.ChainStatus)
                {
                    _logger.LogDebug("🔍 Chain Status Element: {StatusInformation}", chainStatus.StatusInformation);
                }

                _logger.LogDebug("🔍 Certificate chain elements:");
                foreach (var chainElement in chain.ChainElements)
                {
                    _logger.LogDebug("🔍 Chain Element Subject: {Subject}", chainElement.Certificate.Subject);
                    _logger.LogDebug("🔍 Chain Element Issuer: {Issuer}", chainElement.Certificate.Issuer);
                    _logger.LogDebug("🔍 Chain Element Status: {Status}", (object)chainElement.ChainElementStatus);
                }
            }

            return false;
        }

        // 🔍 Check if the server's certificate matches the expected one...
        _logger.LogDebug("🔍 Check if the server's certificate matches the expected one...");

        if (certificate == null)
        {
            _logger.LogError("❌ Server certificate is null.");
            return false;
        }

        var remoteCert = new X509Certificate2(certificate);

        // 🔍 Logging server certificate details...
        var certHelper = new CertificateHelper(_logger);
        certHelper.LogCertificateDetails("Server", remoteCert);

        var serverCertObj = X509Certificate2.CreateFromPem(_serverCertPem);

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
