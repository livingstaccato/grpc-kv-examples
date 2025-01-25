#!/usr/bin/env php

<?php

require_once __DIR__ . '/vendor/autoload.php';

use Grpc\ChannelCredentials;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Proto\GetRequest;
use Proto\KVClient;

class CertificateLogger {
    private Logger $logger;

    public function __construct(Logger $logger) {
        $this->logger = $logger;
    }

    public function logCertInfo($cert, string $prefix): void {
        $certInfo = openssl_x509_parse($cert);
        
        $this->logger->info("🔍 {$prefix} Certificate Details: 📋");
        $this->logger->info("🔍  Subject: " . $this->formatDN($certInfo['subject']) . " 📝");
        $this->logger->info("🔍  Issuer: " . $this->formatDN($certInfo['issuer']) . " 📝");
        $this->logger->info("🔍  Valid From: " . date('Y-m-d H:i:s', $certInfo['validFrom_time_t']) . " ⏰");
        $this->logger->info("🔍  Valid Until: " . date('Y-m-d H:i:s', $certInfo['validTo_time_t']) . " ⏰");
        $this->logger->info("🔍  Serial Number: {$certInfo['serialNumber']} 🔢");
        $this->logger->info("🔍  Version: {$certInfo['version']} 📊");
        
        if (isset($certInfo['extensions'])) {
            if (isset($certInfo['extensions']['keyUsage'])) {
                $this->logger->info("🔍  Key Usage: {$certInfo['extensions']['keyUsage']} 🔑");
            }
            if (isset($certInfo['extensions']['extendedKeyUsage'])) {
                $this->logger->info("🔍  Extended Key Usage: {$certInfo['extensions']['extendedKeyUsage']} 🔐");
            }
            if (isset($certInfo['extensions']['subjectAltName'])) {
                $this->logger->info("🔍  Subject Alt Name: {$certInfo['extensions']['subjectAltName']} 🌐");
            }
        }
    }

    private function formatDN(array $dn): string {
        $parts = [];
        foreach ($dn as $key => $value) {
            $parts[] = "$key=$value";
        }
        return implode(', ', $parts);
    }
}

class GrpcClient {
    private Logger $logger;
    private CertificateLogger $certLogger;
    private string $clientCert;
    private string $clientKey;
    private string $serverCert;

    public function __construct() {
        $this->logger = new Logger('grpc-client');
        $this->logger->pushHandler(new StreamHandler('php://stdout', Logger::DEBUG));
        $this->certLogger = new CertificateLogger($this->logger);
        
        $this->logger->info("🚀 Starting gRPC client... 🌟");
        
        $this->loadCertificates();
    }

    private function loadCertificates(): void {
        $this->logger->info("📂 Checking environment variables... 🔍");
        
        $this->clientCert = getenv('PLUGIN_CLIENT_CERT');
        $this->clientKey = getenv('PLUGIN_CLIENT_KEY');
        $this->serverCert = getenv('PLUGIN_SERVER_CERT');

        if (!$this->clientCert || !$this->clientKey) {
            throw new RuntimeException("❌ Missing client certificates");
        }

        $this->logger->info(sprintf(
            "📦 Certificate sizes - Client Cert: %d bytes, Client Key: %d bytes, Server Cert: %d bytes 📊",
            strlen($this->clientCert),
            strlen($this->clientKey),
            strlen($this->serverCert)
        ));

        // Log certificate details
        $certResource = openssl_x509_read($this->clientCert);
        if ($certResource) {
            $this->certLogger->logCertInfo($certResource, "Client");
        }
    }

    public function run(): void {
        $this->logger->info("🔌 Creating gRPC connection... 🔄");

        $channelCredentials = ChannelCredentials::createSsl(
            $this->serverCert ? $this->serverCert : null,
            $this->clientKey,
            $this->clientCert
        );

        $opts = [
            'grpc.ssl_target_name_override' => 'localhost',
            'grpc.default_authority' => 'localhost',
            'grpc.max_send_message_length' => 100 * 1024 * 1024,
            'grpc.max_receive_message_length' => 100 * 1024 * 1024,
            'grpc.keepalive_time_ms' => 10000,
            'grpc.keepalive_timeout_ms' => 5000,
            'grpc.keepalive_permit_without_calls' => 1,
            'grpc.http2.min_time_between_pings_ms' => 10000,
            'grpc.ssl_handshake_timeout_ms' => 5000
        ];

        try {
            $client = new KVClient('localhost:50051', [
                'credentials' => $channelCredentials,
                'grpc_options' => $opts
            ]);

            $this->logger->info("👥 Created gRPC client");
            $this->logger->info("📡 Sending Get request... 🔄");

            $request = new GetRequest();
            $request->setKey('test');

            $deadline = new DateTime('now +5 seconds');
            [$response, $status] = $client->Get($request)->wait();

            if ($status->code === Grpc\STATUS_OK) {
                echo "✨ Response: " . $response->getValue() . " 📄\n";
                $this->logger->info("✅ Request completed successfully 🎉");
            } else {
                throw new RuntimeException(
                    sprintf("❌ gRPC error: %d - %s 🚫", $status->code, $status->details)
                );
            }
        } catch (Exception $e) {
            $this->logger->error("❌ Error: {$e->getMessage()} 🚫");
            $this->logger->error("❌ Trace: {$e->getTraceAsString()} 🚫");
            throw $e;
        }
    }
}

// Run the client
try {
    $client = new GrpcClient();
    $client->run();
} catch (Exception $e) {
    exit(1);
}
