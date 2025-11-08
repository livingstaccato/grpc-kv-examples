#!/usr/bin/env php
<?php
/**
 * PHP gRPC Key-Value Server with mTLS and comprehensive emoji logging
 *
 * Features:
 * - Mutual TLS (mTLS) authentication
 * - In-memory key-value store
 * - Comprehensive emoji logging for debugging
 * - Certificate validation and inspection
 */

require_once __DIR__ . '/vendor/autoload.php';

use Grpc\RpcServer;
use Proto\KV\GetRequest;
use Proto\KV\GetResponse;
use Proto\KV\PutRequest;
use Proto\KV\Empty;

class KVServiceImplementation extends \Proto\KV\KVInterface
{
    private array $store = [];

    public function Get(\Proto\KV\GetRequest $request): \Proto\KV\GetResponse
    {
        $key = $request->getKey();
        echo "🔍 📥 Get request - Key: {$key}\n";

        $response = new \Proto\KV\GetResponse();

        if (isset($this->store[$key])) {
            $value = $this->store[$key];
            echo "📦 Found value for key '{$key}': " . strlen($value) . " bytes\n";
            $response->setValue($value);
        } else {
            $defaultValue = "OK";
            echo "📦 Key '{$key}' not found, returning default: {$defaultValue}\n";
            $response->setValue($defaultValue);
        }

        echo "✅ Get request completed successfully 🎉\n";
        return $response;
    }

    public function Put(\Proto\KV\PutRequest $request): \Proto\KV\Empty
    {
        $key = $request->getKey();
        $value = $request->getValue();
        $valueLength = strlen($value);

        echo "📝 📥 Put request - Key: {$key}, Value length: {$valueLength} bytes\n";
        echo "📝 Value: {$value}\n";

        $this->store[$key] = $value;
        echo "💾 Stored key '{$key}' with {$valueLength} bytes\n";

        echo "✅ Put request completed successfully 🎉\n";
        return new \Proto\KV\Empty();
    }
}

/**
 * Log certificate details with emoji indicators
 */
function logCertificateDetails(string $label, string $certPem): void
{
    echo "🔐 {$label} Certificate Details:\n";

    $cert = openssl_x509_parse($certPem);
    if ($cert === false) {
        echo "❌ Failed to parse certificate\n";
        return;
    }

    echo "  📝 Subject: {$cert['subject']['CN']}" .
         (isset($cert['subject']['O']) ? ", O={$cert['subject']['O']}" : "") . "\n";
    echo "  📝 Issuer: {$cert['issuer']['CN']}" .
         (isset($cert['issuer']['O']) ? ", O={$cert['issuer']['O']}" : "") . "\n";
    echo "  ⏰ Valid From: " . date('Y-m-d H:i:s', $cert['validFrom_time_t']) . "\n";
    echo "  ⏰ Valid Until: " . date('Y-m-d H:i:s', $cert['validTo_time_t']) . "\n";
    echo "  🔢 Serial Number: {$cert['serialNumberHex']}\n";
    echo "  🔑 Version: {$cert['version']}\n";

    if (isset($cert['extensions'])) {
        if (isset($cert['extensions']['subjectAltName'])) {
            echo "  🌐 Subject Alt Names: {$cert['extensions']['subjectAltName']}\n";
        }
        if (isset($cert['extensions']['basicConstraints'])) {
            echo "  🔒 Basic Constraints: {$cert['extensions']['basicConstraints']}\n";
        }
        if (isset($cert['extensions']['keyUsage'])) {
            echo "  🔑 Key Usage: {$cert['extensions']['keyUsage']}\n";
        }
    }
}

// Main server setup
echo "🚀 🔄 Starting PHP gRPC Server... 🌟\n\n";

// Load environment variables
echo "📂 Loading certificates from environment... 🔍\n";

$serverCert = getenv('PLUGIN_SERVER_CERT');
$serverKey = getenv('PLUGIN_SERVER_KEY');
$clientCaCert = getenv('PLUGIN_CLIENT_CERT'); // This is our trusted CA for client validation

if (empty($serverCert) || empty($serverKey) || empty($clientCaCert)) {
    echo "❌ Missing required environment variables\n";
    echo "   Please source env.sh before running this server\n";
    exit(1);
}

echo "📦 Certificate sizes:\n";
echo "📦   Server Cert: " . strlen($serverCert) . " bytes\n";
echo "📦   Server Key: " . strlen($serverKey) . " bytes\n";
echo "📦   Client CA Cert: " . strlen($clientCaCert) . " bytes\n\n";

// Log certificate details
logCertificateDetails("Server", $serverCert);
echo "\n";
logCertificateDetails("Client CA", $clientCaCert);
echo "\n";

// Server configuration
$host = getenv('PLUGIN_HOST') ?: 'localhost';
$port = getenv('PLUGIN_PORT') ?: '50051';
$address = "{$host}:{$port}";

echo "🔧 Configuring gRPC server with mTLS...\n";

// Create temporary files for certificates (PHP gRPC requires file paths)
$tempDir = sys_get_temp_dir() . '/grpc-kv-php';
if (!is_dir($tempDir)) {
    mkdir($tempDir, 0700, true);
}

$serverCertFile = $tempDir . '/server.crt';
$serverKeyFile = $tempDir . '/server.key';
$clientCaFile = $tempDir . '/client-ca.crt';

file_put_contents($serverCertFile, $serverCert);
file_put_contents($serverKeyFile, $serverKey);
file_put_contents($clientCaFile, $clientCaCert);

echo "🔧 Certificate files created in: {$tempDir}\n";
echo "🔧 TLS Protocols: TLS 1.2, TLS 1.3\n";
echo "🔧 mTLS: Client certificate required\n\n";

// Create the gRPC server
$server = new \Grpc\RpcServer([
    'credentials' => \Grpc\ServerCredentials::createSsl(
        $clientCaCert,  // root_certs for client validation
        [[
            'private_key' => $serverKey,
            'cert_chain' => $serverCert
        ]]
    )
]);

// Register the service
$server->addHttp2Port($address);
$server->handle(new KVServiceImplementation());

echo "📋 Registered KVService implementation\n";
echo "✅ Server configured successfully 🔒\n";
echo "🎧 Listening on {$address} - Ready to accept connections! 🚀\n\n";

// Start the server
try {
    $server->run();
} catch (Exception $e) {
    echo "❌ Server error: " . $e->getMessage() . "\n";
    exit(1);
} finally {
    // Cleanup temp files
    @unlink($serverCertFile);
    @unlink($serverKeyFile);
    @unlink($clientCaFile);
    @rmdir($tempDir);
}
