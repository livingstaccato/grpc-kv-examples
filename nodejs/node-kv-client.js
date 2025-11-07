#!/usr/bin/env node

const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');

// Load proto file
const PROTO_PATH = path.join(__dirname, '../proto/kv.proto');
const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true
});
const protoDescriptor = grpc.loadPackageDefinition(packageDefinition);
const kv = protoDescriptor.proto;

// Load certificates from environment variables
function loadCertificates() {
    console.log('📂 Loading certificates from environment... 🔍');

    const clientCert = process.env.PLUGIN_CLIENT_CERT;
    const clientKey = process.env.PLUGIN_CLIENT_KEY;
    const serverCert = process.env.PLUGIN_SERVER_CERT;

    if (!clientCert || !clientKey || !serverCert) {
        throw new Error('❌ Missing certificate environment variables. Run: source env.sh');
    }

    console.log(`📦 Certificate sizes - Client Cert: ${clientCert.length} bytes, Client Key: ${clientKey.length} bytes, Server Cert: ${serverCert.length} bytes 📊`);

    return {
        clientCert: Buffer.from(clientCert),
        clientKey: Buffer.from(clientKey),
        serverCert: Buffer.from(serverCert)
    };
}

function main() {
    console.log('🚀 Starting Node.js gRPC client... 🌟');
    console.log('🟢 Node.js version:', process.version);

    const host = process.env.PLUGIN_HOST || 'localhost';
    const port = process.env.PLUGIN_PORT || '50051';
    const endpoint = `${host}:${port}`;

    console.log(`🌐 Target endpoint: ${endpoint}`);

    // Load certificates
    const certs = loadCertificates();

    // Create channel credentials with mTLS
    console.log('🔑 Creating client identity...');
    console.log('🔐 Creating server CA certificate...');
    console.log('🔒 Configuring TLS with mTLS...');

    const channelCredentials = grpc.credentials.createSsl(
        certs.serverCert,     // CA cert for server verification
        certs.clientKey,      // Client private key
        certs.clientCert      // Client certificate
    );

    console.log('✅ TLS configuration complete');

    // Create client
    console.log('🔌 Creating gRPC client...');
    const client = new kv.KV(endpoint, channelCredentials, {
        'grpc.ssl_target_name_override': 'localhost',
        'grpc.default_authority': 'localhost'
    });

    console.log('👥 gRPC client created');
    console.log('📡 Sending Get request for key: \'test-key\'...');

    // Make Get request
    client.Get({ key: 'test-key' }, (error, response) => {
        if (error) {
            console.error('❌ Request failed:', error.message);
            process.exit(1);
        }

        const value = response.value.toString();
        console.log(`📥 Response received - Value length: ${response.value.length} bytes`);
        console.log(`✨ Response: ${value} 📄`);
        console.log('✅ Request completed successfully 🎉');

        process.exit(0);
    });
}

main();
