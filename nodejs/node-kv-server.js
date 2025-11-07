#!/usr/bin/env node

const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const fs = require('fs');
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

    const serverCert = process.env.PLUGIN_SERVER_CERT;
    const serverKey = process.env.PLUGIN_SERVER_KEY;
    const clientCert = process.env.PLUGIN_CLIENT_CERT;

    if (!serverCert || !serverKey || !clientCert) {
        throw new Error('❌ Missing certificate environment variables. Run: source env.sh');
    }

    console.log(`📦 Certificate sizes:`);
    console.log(`📦   Server Cert: ${serverCert.length} bytes`);
    console.log(`📦   Server Key: ${serverKey.length} bytes`);
    console.log(`📦   Client CA Cert: ${clientCert.length} bytes`);

    return {
        serverCert: Buffer.from(serverCert),
        serverKey: Buffer.from(serverKey),
        clientCert: Buffer.from(clientCert)
    };
}

// Implement KV service
const kvService = {
    Get: (call, callback) => {
        const key = call.request.key;
        console.log(`🔍 📥 Get request - Key: ${key}`);

        // Log request metadata
        console.log('🔎 Request metadata:');
        const metadata = call.metadata.getMap();
        for (const [k, v] of Object.entries(metadata)) {
            console.log(`🔎   ${k}: ${v}`);
        }

        callback(null, { value: Buffer.from('OK') });
        console.log('✅ Get request completed successfully 🎉');
    },

    Put: (call, callback) => {
        const key = call.request.key;
        const value = call.request.value;
        console.log(`📝 📥 Put request - Key: ${key}, Value length: ${value.length} bytes`);
        console.log(`📝 Value: ${value.toString()}`);

        callback(null, {});
        console.log('✅ Put request completed successfully 🎉');
    }
};

function main() {
    console.log('🚀 🔄 Starting Node.js gRPC server... 🌟');
    console.log('🟢 Node.js version:', process.version);

    // Load certificates
    const certs = loadCertificates();

    // Create server credentials with mTLS
    console.log('🔒 Creating TLS configuration with mTLS...');
    const serverCredentials = grpc.ServerCredentials.createSsl(
        certs.clientCert,  // CA cert for client verification
        [{
            cert_chain: certs.serverCert,
            private_key: certs.serverKey
        }],
        true  // require client certificate (mTLS)
    );

    console.log('✅ 🔒 TLS configuration complete - mTLS enabled 🎉');

    // Create and start server
    const server = new grpc.Server();
    server.addService(kv.KV.service, kvService);

    const host = process.env.PLUGIN_HOST || 'localhost';
    const port = process.env.PLUGIN_PORT || '50051';
    const address = `${host}:${port}`;

    server.bindAsync(address, serverCredentials, (error, port) => {
        if (error) {
            console.error('❌ Failed to bind server:', error);
            process.exit(1);
        }

        console.log(`🌐 Server bound to ${address}`);
        console.log(`✅ Server configured successfully`);
        console.log(`🎧 Listening on ${address} - Ready to accept connections! 🚀`);
        server.start();
    });

    // Handle shutdown gracefully
    process.on('SIGINT', () => {
        console.log('\n⏹️  Server stopping gracefully');
        server.tryShutdown(() => {
            console.log('✅ Server stopped');
            process.exit(0);
        });
    });
}

main();
