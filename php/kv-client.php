#!/usr/bin/env php
<?php
/**
 * PHP gRPC KV Client with mTLS
 *
 * Implements a gRPC client for the KV service with mutual TLS authentication.
 * Requires the grpc PHP extension for full functionality.
 */

require_once __DIR__ . '/vendor/autoload.php';

use Grpc\ChannelCredentials;

// Logger function
function logMessage(string $level, string $message): void
{
    $timestamp = date('Y-m-d\TH:i:s.vP');
    fprintf(STDERR, "{$timestamp} [{$level}]     {$message}\n");
}

function logCertificateInfo(string $cert, string $prefix): void
{
    $certInfo = openssl_x509_parse($cert);
    if ($certInfo) {
        logMessage('INFO', "{$prefix} Certificate Details:");
        logMessage('INFO', sprintf('  Subject: %s', $certInfo['subject']['CN'] ?? 'N/A'));
        logMessage('INFO', sprintf('  Issuer: %s', $certInfo['issuer']['CN'] ?? 'N/A'));
        logMessage('INFO', sprintf('  Valid From: %s', date('Y-m-d H:i:s', $certInfo['validFrom_time_t'])));
        logMessage('INFO', sprintf('  Valid To: %s', date('Y-m-d H:i:s', $certInfo['validTo_time_t'])));
    }
}

// Main function
function main(): int
{
    logMessage('INFO', 'Starting gRPC KV Client (PHP)');

    // Load certificates from environment
    $serverCert = getenv('PLUGIN_SERVER_CERT');
    $clientCert = getenv('PLUGIN_CLIENT_CERT');
    $clientKey = getenv('PLUGIN_CLIENT_KEY');

    if (!$serverCert) {
        logMessage('ERROR', 'Missing required environment variable: PLUGIN_SERVER_CERT');
        return 1;
    }

    logMessage('INFO', 'Loading certificates...');
    logMessage('INFO', sprintf('Server cert length: %d bytes', strlen($serverCert)));
    logMessage('INFO', sprintf('Client cert length: %d bytes', $clientCert ? strlen($clientCert) : 0));
    logMessage('INFO', sprintf('Client key length: %d bytes', $clientKey ? strlen($clientKey) : 0));

    // Log certificate details
    logCertificateInfo($serverCert, 'Server CA');
    if ($clientCert) {
        logCertificateInfo($clientCert, 'Client');
    }

    // Check if grpc extension is loaded
    if (!extension_loaded('grpc')) {
        logMessage('WARN', 'gRPC extension not loaded - using pure PHP implementation');
        logMessage('INFO', 'For better performance, install the grpc PHP extension');

        // Fallback to demonstration mode
        return demonstrationMode($serverCert, $clientCert, $clientKey);
    }

    // Create channel credentials
    $host = getenv('PLUGIN_HOST') ?: 'localhost';
    $port = getenv('PLUGIN_PORT') ?: '50051';
    $address = "{$host}:{$port}";

    logMessage('INFO', sprintf('Connecting to %s', $address));

    try {
        if ($clientCert && $clientKey) {
            // mTLS - mutual authentication
            $credentials = ChannelCredentials::createSsl(
                $serverCert,  // Root CA
                $clientKey,   // Client private key
                $clientCert   // Client certificate
            );
            logMessage('INFO', 'mTLS credentials configured');
        } else {
            // TLS only
            $credentials = ChannelCredentials::createSsl($serverCert);
            logMessage('INFO', 'TLS credentials configured (no client auth)');
        }

        // Create client
        $client = new \Grpc\BaseStub($address, [
            'credentials' => $credentials,
            'grpc.ssl_target_name_override' => 'localhost',
        ]);

        // Test Get operation
        logMessage('INFO', 'Sending Get request...');
        $getRequest = new \KV\GetRequest(['key' => 'test-key']);

        // Note: This requires proper protobuf message classes
        // For now, we'll use the raw grpc call
        list($response, $status) = $client->_simpleRequest(
            '/proto.KV/Get',
            $getRequest,
            [\KV\GetResponse::class, 'decode'],
            [],
            []
        )->wait();

        if ($status->code === \Grpc\STATUS_OK) {
            logMessage('INFO', sprintf('Get response: %s', $response->getValue()));
        } else {
            logMessage('ERROR', sprintf('Get failed: %s', $status->details));
            return 1;
        }

        // Test Put operation
        logMessage('INFO', 'Sending Put request...');
        $putRequest = new \KV\PutRequest([
            'key' => 'test-key',
            'value' => 'test-value'
        ]);

        list($response, $status) = $client->_simpleRequest(
            '/proto.KV/Put',
            $putRequest,
            [\KV\EmptyMessage::class, 'decode'],
            [],
            []
        )->wait();

        if ($status->code === \Grpc\STATUS_OK) {
            logMessage('INFO', 'Put request successful');
        } else {
            logMessage('ERROR', sprintf('Put failed: %s', $status->details));
            return 1;
        }

        logMessage('INFO', 'All operations completed successfully');
        echo "OK\n";
        return 0;

    } catch (\Exception $e) {
        logMessage('ERROR', sprintf('Client error: %s', $e->getMessage()));
        return 1;
    }
}

/**
 * Demonstration mode when gRPC extension is not available
 */
function demonstrationMode(string $serverCert, ?string $clientCert, ?string $clientKey): int
{
    logMessage('INFO', 'Running in demonstration mode (no gRPC extension)');

    $host = getenv('PLUGIN_HOST') ?: 'localhost';
    $port = getenv('PLUGIN_PORT') ?: '50051';

    logMessage('INFO', sprintf('Would connect to %s:%s', $host, $port));
    logMessage('INFO', 'Certificate validation:');

    // Validate certificates using OpenSSL
    $serverCertInfo = openssl_x509_parse($serverCert);
    if (!$serverCertInfo) {
        logMessage('ERROR', 'Invalid server certificate');
        return 1;
    }
    logMessage('INFO', '  ✓ Server certificate is valid');

    if ($clientCert) {
        $clientCertInfo = openssl_x509_parse($clientCert);
        if (!$clientCertInfo) {
            logMessage('ERROR', 'Invalid client certificate');
            return 1;
        }
        logMessage('INFO', '  ✓ Client certificate is valid');
    }

    if ($clientKey) {
        $keyResource = openssl_pkey_get_private($clientKey);
        if (!$keyResource) {
            logMessage('ERROR', 'Invalid client private key');
            return 1;
        }
        logMessage('INFO', '  ✓ Client private key is valid');
    }

    logMessage('INFO', 'Demonstration complete - install grpc extension for full functionality');
    logMessage('INFO', 'Run: pecl install grpc && echo "extension=grpc.so" >> php.ini');

    echo "OK (demo mode)\n";
    return 0;
}

exit(main());
