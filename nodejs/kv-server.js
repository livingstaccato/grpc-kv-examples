#!/usr/bin/env node

/**
 * Node.js gRPC KV Server with mTLS
 *
 * Implements a simple key-value store service with mutual TLS authentication.
 * Matches the interface defined in proto/kv.proto
 */

const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Load the protobuf definition
const PROTO_PATH = path.join(__dirname, '..', 'proto', 'kv.proto');
const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true
});
const kvProto = grpc.loadPackageDefinition(packageDefinition).proto;

// Logger with structured output
function log(level, domain, action, status, message) {
    const timestamp = new Date().toISOString();
    console.log(`${timestamp} [${level}] ${domain} ${action} ${status} ${message}`);
}

// Certificate info logging
function logCertificateInfo(cert, prefix) {
    try {
        const x509 = new crypto.X509Certificate(cert);
        log('INFO', '  ', '  ', '  ', `${prefix} Certificate Details:`);
        log('INFO', '  ', '  ', '  ', `  Subject: ${x509.subject}`);
        log('INFO', '  ', '  ', '  ', `  Issuer: ${x509.issuer}`);
        log('INFO', '  ', '  ', '  ', `  Valid From: ${x509.validFrom}`);
        log('INFO', '  ', '  ', '  ', `  Valid To: ${x509.validTo}`);
        log('INFO', '  ', '  ', '  ', `  Serial: ${x509.serialNumber}`);
        log('INFO', '  ', '  ', '  ', `  Fingerprint: ${x509.fingerprint256}`);

        // Log key info
        const keyType = x509.publicKey.asymmetricKeyType;
        if (keyType === 'ec') {
            const details = x509.publicKey.asymmetricKeyDetails;
            log('INFO', '  ', '  ', '  ', `  Public Key: EC ${details.namedCurve}`);
        } else if (keyType === 'rsa') {
            const details = x509.publicKey.asymmetricKeyDetails;
            log('INFO', '  ', '  ', '  ', `  Public Key: RSA ${details.modulusLength} bits`);
        }
    } catch (err) {
        log('WARN', '  ', '  ', '  ', `Failed to parse certificate: ${err.message}`);
    }
}

// KV Service implementation
const kvService = {
    Get: (call, callback) => {
        const key = call.request.key;
        log('INFO', '  ', '  ', '  ', `Get request - Key: ${key}`);

        // Log peer information if available
        const peer = call.getPeer();
        log('DEBUG', '  ', '  ', '  ', `Peer: ${peer}`);

        // Validate request
        if (!key || key.trim() === '') {
            log('ERROR', '  ', '  ', '  ', 'Get request rejected: empty key');
            return callback({
                code: grpc.status.INVALID_ARGUMENT,
                message: 'key cannot be empty'
            });
        }

        log('INFO', '  ', '  ', '  ', `Get request completed successfully`);
        callback(null, { value: Buffer.from('OK') });
    },

    Put: (call, callback) => {
        const key = call.request.key;
        const value = call.request.value;
        log('INFO', '  ', '  ', '  ', `Put request - Key: ${key}`);

        // Log peer information
        const peer = call.getPeer();
        log('DEBUG', '  ', '  ', '  ', `Peer: ${peer}`);

        // Validate request
        if (!key || key.trim() === '') {
            log('ERROR', '  ', '  ', '  ', 'Put request rejected: empty key');
            return callback({
                code: grpc.status.INVALID_ARGUMENT,
                message: 'key cannot be empty'
            });
        }
        if (!value || value.length === 0) {
            log('ERROR', '  ', '  ', '  ', 'Put request rejected: empty value');
            return callback({
                code: grpc.status.INVALID_ARGUMENT,
                message: 'value cannot be empty'
            });
        }

        log('INFO', '  ', '  ', '  ', `Put request completed successfully`);
        callback(null, {});
    }
};

function main() {
    log('INFO', '  ', '  ', '  ', 'Starting gRPC KV Server (Node.js)');

    // Load certificates from environment variables
    const serverCert = process.env.PLUGIN_SERVER_CERT;
    const serverKey = process.env.PLUGIN_SERVER_KEY;
    const clientCert = process.env.PLUGIN_CLIENT_CERT;

    if (!serverCert || !serverKey) {
        log('ERROR', '  ', '  ', '  ', 'Missing required environment variables: PLUGIN_SERVER_CERT, PLUGIN_SERVER_KEY');
        process.exit(1);
    }

    log('INFO', '  ', '  ', '  ', 'Loading certificates...');
    log('INFO', '  ', '  ', '  ', `Server cert length: ${serverCert.length} bytes`);
    log('INFO', '  ', '  ', '  ', `Server key length: ${serverKey.length} bytes`);
    log('INFO', '  ', '  ', '  ', `Client cert length: ${clientCert ? clientCert.length : 0} bytes`);

    // Log certificate details
    logCertificateInfo(serverCert, 'Server');
    if (clientCert) {
        logCertificateInfo(clientCert, 'Client CA');
    }

    // Create server credentials with mTLS
    let credentials;
    try {
        if (clientCert) {
            // mTLS - require client certificate
            credentials = grpc.ServerCredentials.createSsl(
                Buffer.from(clientCert),  // Root CA for client verification
                [{
                    private_key: Buffer.from(serverKey),
                    cert_chain: Buffer.from(serverCert)
                }],
                true  // checkClientCertificate
            );
            log('INFO', '  ', '  ', '  ', 'mTLS credentials configured (client auth required)');
        } else {
            // TLS only - no client verification
            credentials = grpc.ServerCredentials.createSsl(
                null,
                [{
                    private_key: Buffer.from(serverKey),
                    cert_chain: Buffer.from(serverCert)
                }],
                false
            );
            log('INFO', '  ', '  ', '  ', 'TLS credentials configured (no client auth)');
        }
    } catch (err) {
        log('ERROR', '  ', '  ', '  ', `Failed to create credentials: ${err.message}`);
        process.exit(1);
    }

    // Create and start server
    const server = new grpc.Server({
        'grpc.max_receive_message_length': 100 * 1024 * 1024,
        'grpc.max_send_message_length': 100 * 1024 * 1024,
        'grpc.keepalive_time_ms': 10000,
        'grpc.keepalive_timeout_ms': 5000,
        'grpc.keepalive_permit_without_calls': 1
    });

    server.addService(kvProto.KV.service, kvService);

    const port = process.env.PLUGIN_PORT || '50051';
    const address = `0.0.0.0:${port}`;

    server.bindAsync(address, credentials, (err, boundPort) => {
        if (err) {
            log('ERROR', '  ', '  ', '  ', `Failed to bind server: ${err.message}`);
            process.exit(1);
        }

        log('INFO', '  ', '  ', '  ', `gRPC KV Server listening on ${address}`);
        log('INFO', '  ', '  ', '  ', 'Server ready to accept connections');
    });

    // Handle shutdown
    process.on('SIGINT', () => {
        log('INFO', '  ', '  ', '  ', 'Received SIGINT, shutting down...');
        server.tryShutdown(() => {
            log('INFO', '  ', '  ', '  ', 'Server shutdown complete');
            process.exit(0);
        });
    });

    process.on('SIGTERM', () => {
        log('INFO', '  ', '  ', '  ', 'Received SIGTERM, shutting down...');
        server.tryShutdown(() => {
            log('INFO', '  ', '  ', '  ', 'Server shutdown complete');
            process.exit(0);
        });
    });
}

main();
