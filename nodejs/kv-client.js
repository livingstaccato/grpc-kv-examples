#!/usr/bin/env node

/**
 * Node.js gRPC KV Client with mTLS
 *
 * Connects to a KV server using mutual TLS authentication.
 * Matches the interface defined in proto/kv.proto
 */

const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
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

async function main() {
    log('INFO', '  ', '  ', '  ', 'Starting gRPC KV Client (Node.js)');

    // Load certificates from environment variables
    const clientCert = process.env.PLUGIN_CLIENT_CERT;
    const clientKey = process.env.PLUGIN_CLIENT_KEY;
    const serverCert = process.env.PLUGIN_SERVER_CERT;

    if (!clientCert || !clientKey) {
        log('ERROR', '  ', '  ', '  ', 'Missing required environment variables: PLUGIN_CLIENT_CERT, PLUGIN_CLIENT_KEY');
        process.exit(1);
    }

    log('INFO', '  ', '  ', '  ', 'Loading certificates...');
    log('INFO', '  ', '  ', '  ', `Client cert length: ${clientCert.length} bytes`);
    log('INFO', '  ', '  ', '  ', `Client key length: ${clientKey.length} bytes`);
    log('INFO', '  ', '  ', '  ', `Server cert length: ${serverCert ? serverCert.length : 0} bytes`);

    // Log certificate details
    logCertificateInfo(clientCert, 'Client');
    if (serverCert) {
        logCertificateInfo(serverCert, 'Server');
    }

    // Create client credentials with mTLS
    let credentials;
    try {
        if (serverCert) {
            // mTLS with known server certificate
            credentials = grpc.credentials.createSsl(
                Buffer.from(serverCert),  // Root CA for server verification
                Buffer.from(clientKey),    // Client private key
                Buffer.from(clientCert)    // Client certificate chain
            );
            log('INFO', '  ', '  ', '  ', 'mTLS credentials configured');
        } else {
            log('ERROR', '  ', '  ', '  ', 'Server certificate required for mTLS');
            process.exit(1);
        }
    } catch (err) {
        log('ERROR', '  ', '  ', '  ', `Failed to create credentials: ${err.message}`);
        process.exit(1);
    }

    // Channel options
    const options = {
        'grpc.ssl_target_name_override': 'localhost',
        'grpc.default_authority': 'localhost',
        'grpc.max_receive_message_length': 100 * 1024 * 1024,
        'grpc.max_send_message_length': 100 * 1024 * 1024,
        'grpc.keepalive_time_ms': 10000,
        'grpc.keepalive_timeout_ms': 5000,
        'grpc.keepalive_permit_without_calls': 1
    };

    // Connect to server
    const host = process.env.PLUGIN_HOST || 'localhost';
    const port = process.env.PLUGIN_PORT || '50051';
    const address = `${host}:${port}`;

    log('INFO', '  ', '  ', '  ', `Connecting to server at ${address}...`);

    const client = new kvProto.KV(address, credentials, options);

    // Wait for connection
    const deadline = new Date();
    deadline.setSeconds(deadline.getSeconds() + 10);

    await new Promise((resolve, reject) => {
        client.waitForReady(deadline, (err) => {
            if (err) {
                log('ERROR', '  ', '  ', '  ', `Failed to connect: ${err.message}`);
                reject(err);
            } else {
                log('INFO', '  ', '  ', '  ', 'Connected successfully');
                resolve();
            }
        });
    });

    // Send Get request
    log('INFO', '  ', '  ', '  ', 'Sending Get request...');

    const response = await new Promise((resolve, reject) => {
        client.Get({ key: 'test' }, (err, response) => {
            if (err) {
                log('ERROR', '  ', '  ', '  ', `Get request failed: ${err.message}`);
                log('ERROR', '  ', '  ', '  ', `  Code: ${err.code}`);
                log('ERROR', '  ', '  ', '  ', `  Details: ${err.details}`);
                reject(err);
            } else {
                resolve(response);
            }
        });
    });

    const value = response.value ? response.value.toString() : '';
    console.log(`Response: ${value}`);
    log('INFO', '  ', '  ', '  ', 'Request completed successfully');

    // Clean up
    client.close();
}

main().catch(err => {
    log('ERROR', '  ', '  ', '  ', `Fatal error: ${err.message}`);
    process.exit(1);
});
