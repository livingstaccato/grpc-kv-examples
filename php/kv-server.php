#!/usr/bin/env php
<?php
/**
 * PHP gRPC KV Server with mTLS
 *
 * NOTE: PHP gRPC server requires the grpc C extension.
 * This is a reference implementation - PHP is typically used as a gRPC client.
 *
 * For production gRPC servers in PHP, consider:
 * - RoadRunner with gRPC plugin
 * - Swoole with gRPC support
 * - Spiral Framework
 */

require_once __DIR__ . '/vendor/autoload.php';

use Spiral\RoadRunner\GRPC\Server;
use Spiral\RoadRunner\Worker;

// Logger function
function logMessage(string $level, string $message): void
{
    $timestamp = date('Y-m-d\TH:i:s.vP');
    echo "{$timestamp} [{$level}]     {$message}\n";
}

logMessage('INFO', 'PHP gRPC KV Server');
logMessage('INFO', 'NOTE: PHP typically requires RoadRunner or Swoole for gRPC server functionality');
logMessage('INFO', 'This is a reference implementation showing the service structure');

// Load certificates from environment
$serverCert = getenv('PLUGIN_SERVER_CERT');
$serverKey = getenv('PLUGIN_SERVER_KEY');
$clientCert = getenv('PLUGIN_CLIENT_CERT');

if (!$serverCert || !$serverKey) {
    logMessage('ERROR', 'Missing required environment variables: PLUGIN_SERVER_CERT, PLUGIN_SERVER_KEY');
    exit(1);
}

logMessage('INFO', 'Certificate configuration:');
logMessage('INFO', sprintf('  Server cert length: %d bytes', strlen($serverCert)));
logMessage('INFO', sprintf('  Server key length: %d bytes', strlen($serverKey)));
logMessage('INFO', sprintf('  Client cert length: %d bytes', $clientCert ? strlen($clientCert) : 0));

// Parse and display certificate info
$certInfo = openssl_x509_parse($serverCert);
if ($certInfo) {
    logMessage('INFO', 'Server Certificate Details:');
    logMessage('INFO', sprintf('  Subject: %s', $certInfo['subject']['CN'] ?? 'N/A'));
    logMessage('INFO', sprintf('  Issuer: %s', $certInfo['issuer']['CN'] ?? 'N/A'));
    logMessage('INFO', sprintf('  Valid From: %s', date('Y-m-d H:i:s', $certInfo['validFrom_time_t'])));
    logMessage('INFO', sprintf('  Valid To: %s', date('Y-m-d H:i:s', $certInfo['validTo_time_t'])));
}

// KV Service implementation
class KVService
{
    private array $store = [];

    public function Get(array $request): array
    {
        $key = $request['key'] ?? '';
        logMessage('INFO', sprintf('Get request - Key: %s', $key));

        if (empty($key)) {
            throw new \InvalidArgumentException('key cannot be empty');
        }

        return ['value' => 'OK'];
    }

    public function Put(array $request): array
    {
        $key = $request['key'] ?? '';
        $value = $request['value'] ?? '';
        logMessage('INFO', sprintf('Put request - Key: %s', $key));

        if (empty($key)) {
            throw new \InvalidArgumentException('key cannot be empty');
        }
        if (empty($value)) {
            throw new \InvalidArgumentException('value cannot be empty');
        }

        $this->store[$key] = $value;
        return [];
    }
}

$port = getenv('PLUGIN_PORT') ?: '50051';
logMessage('INFO', sprintf('Server would listen on 0.0.0.0:%s', $port));
logMessage('INFO', 'For actual PHP gRPC server, use RoadRunner or Swoole');
logMessage('INFO', 'See: https://roadrunner.dev/docs/plugins-grpc');

// Display implementation note
echo "\n";
echo "=== PHP gRPC Server Implementation Note ===\n";
echo "PHP's gRPC extension primarily supports client-side operations.\n";
echo "For server-side gRPC in PHP, recommended options:\n";
echo "  1. RoadRunner GRPC Plugin (https://roadrunner.dev)\n";
echo "  2. Swoole GRPC (https://github.com/swoole/grpc)\n";
echo "  3. Spiral Framework (https://spiral.dev)\n";
echo "\n";
echo "The client implementation (kv-client.php) is fully functional.\n";
echo "============================================\n";
