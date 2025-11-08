#!/usr/bin/env php
<?php
/**
 * PHP gRPC Key-Value Client with mTLS and comprehensive emoji logging
 *
 * Features:
 * - Mutual TLS (mTLS) authentication
 * - Comprehensive emoji logging for debugging
 * - Certificate validation and inspection
 */

require_once __DIR__ . '/vendor/autoload.php';

use Proto\KV\KVClient;
use Proto\KV\GetRequest;
use Proto\KV\PutRequest;
use Grpc\ChannelCredentials;

/**
 * Log certificate details with emoji indicators
 */
function logCertificateDetails(string $label, string $certPem): void
{
    echo "🔍 {$label} Certificate Details: 📋\n";

    $cert = openssl_x509_parse($certPem);
    if ($cert === false) {
        echo "❌ Failed to parse certificate\n";
        return;
    }

    echo "🔍  Subject: {$cert['subject']['CN']}" .
         (isset($cert['subject']['O']) ? ", O={$cert['subject']['O']}" : "") . " 📝\n";
    echo "🔍  Issuer: {$cert['issuer']['CN']}" .
         (isset($cert['issuer']['O']) ? ", O={$cert['issuer']['O']}" : "") . " 📝\n";
    echo "🔍  Valid From: " . date('Y-m-d H:i:s', $cert['validFrom_time_t']) . " ⏰\n";
    echo "🔍  Valid Until: " . date('Y-m-d H:i:s', $cert['validTo_time_t']) . " ⏰\n";
    echo "🔍  Serial Number: {$cert['serialNumberHex']} 🔢\n";
    echo "🔍  Version: {$cert['version']} 📊\n";

    if (isset($cert['extensions'])) {
        if (isset($cert['extensions']['keyUsage'])) {
            echo "🔍  Key Usage: {$cert['extensions']['keyUsage']} 🔑\n";
        }
        if (isset($cert['extensions']['subjectAltName'])) {
            echo "🔍  DNS Names: {$cert['extensions']['subjectAltName']} 🌐\n";
        }
    }
}

// Main client setup
echo "🚀 Starting gRPC client... 🌟\n";

// Load environment variables
echo "📂 Checking environment variables... 🔍\n";

$clientCert = getenv('PLUGIN_CLIENT_CERT');
$clientKey = getenv('PLUGIN_CLIENT_KEY');
$serverCert = getenv('PLUGIN_SERVER_CERT');

if (empty($clientCert) || empty($clientKey) || empty($serverCert)) {
    echo "❌ Missing required environment variables\n";
    echo "   Please source env.sh before running this client\n";
    exit(1);
}

echo "🔒 Using provided certificates 📜\n";
echo "📦 Certificate sizes - Client Cert: " . strlen($clientCert) . " bytes, " .
     "Client Key: " . strlen($clientKey) . " bytes, " .
     "Server Cert: " . strlen($serverCert) . " bytes 📊\n";

echo "🔐 Creating certificate credentials... 🔄\n";

// Log client certificate details
logCertificateDetails("Client", $clientCert);

echo "✅ Client certificate loaded successfully 🔒\n";

// Server configuration
$host = getenv('PLUGIN_HOST') ?: 'localhost';
$port = getenv('PLUGIN_PORT') ?: '50051';
$address = "{$host}:{$port}";

echo "⚙️ Configuring TLS... 🔄\n";

// Create temporary files for certificates (PHP gRPC requires file paths)
$tempDir = sys_get_temp_dir() . '/grpc-kv-php-client';
if (!is_dir($tempDir)) {
    mkdir($tempDir, 0700, true);
}

$clientCertFile = $tempDir . '/client.crt';
$clientKeyFile = $tempDir . '/client.key';
$serverCaFile = $tempDir . '/server-ca.crt';

file_put_contents($clientCertFile, $clientCert);
file_put_contents($clientKeyFile, $clientKey);
file_put_contents($serverCaFile, $serverCert);

echo "✅ TLS configuration complete 🔒\n";

// Create SSL credentials
$channelCredentials = \Grpc\ChannelCredentials::createSsl(
    file_get_contents($serverCaFile),  // Root CA
    file_get_contents($clientKeyFile),  // Client private key
    file_get_contents($clientCertFile)  // Client certificate
);

echo "🔌 Creating gRPC connection... 🔄\n";
echo "🔌 Connecting to: {$address}\n";

// Create the client
$client = new \Proto\KV\KVClient($address, [
    'credentials' => $channelCredentials,
    'grpc.ssl_target_name_override' => $host,
    'grpc.default_authority' => $host
]);

echo "✅ Connection established successfully 🔗\n";

// Test: Put a value
echo "\n📝 Testing Put request...\n";
$putRequest = new \Proto\KV\PutRequest();
$putRequest->setKey('test');
$putRequest->setValue('Hello from PHP!');

try {
    list($response, $status) = $client->Put($putRequest)->wait();

    if ($status->code === \Grpc\STATUS_OK) {
        echo "✅ Put request successful 🎉\n";
    } else {
        echo "❌ Put request failed: {$status->details}\n";
        exit(1);
    }
} catch (Exception $e) {
    echo "❌ Put request error: " . $e->getMessage() . "\n";
    exit(1);
}

// Test: Get the value
echo "\n🔍 Testing Get request...\n";
$getRequest = new \Proto\KV\GetRequest();
$getRequest->setKey('test');

try {
    list($response, $status) = $client->Get($getRequest)->wait();

    if ($status->code === \Grpc\STATUS_OK) {
        $value = $response->getValue();
        echo "✅ Get request successful 🎉\n";
        echo "📦 Response: {$value}\n";
    } else {
        echo "❌ Get request failed: {$status->details}\n";
        exit(1);
    }
} catch (Exception $e) {
    echo "❌ Get request error: " . $e->getMessage() . "\n";
    exit(1);
}

echo "\n✅ All operations completed successfully! 🎊\n";

// Cleanup temp files
@unlink($clientCertFile);
@unlink($clientKeyFile);
@unlink($serverCaFile);
@rmdir($tempDir);
