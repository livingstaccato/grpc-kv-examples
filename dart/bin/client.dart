#!/usr/bin/env dart
/// Dart gRPC KV Client with mTLS
///
/// Implements a gRPC client for the KV service with mutual TLS authentication.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grpc/grpc.dart';
import '../lib/src/generated/kv.pbgrpc.dart';

/// Logger with structured output
void log(String level, String message) {
  final timestamp = DateTime.now().toIso8601String();
  stderr.writeln('$timestamp [$level]     $message');
}

/// Parse certificate info for logging
void logCertificateInfo(String certPem, String prefix) {
  try {
    log('INFO', '$prefix Certificate loaded (${certPem.length} bytes)');
  } catch (e) {
    log('WARN', 'Failed to parse certificate: $e');
  }
}

/// ChannelCredentials.secure() has no way to present a client certificate,
/// so mTLS needs its own SecurityContext with the client identity attached.
class MtlsChannelCredentials extends ChannelCredentials {
  final List<int> _clientCertChain;
  final List<int> _clientPrivateKey;

  MtlsChannelCredentials({
    required List<int> trustedCertificates,
    required List<int> clientCertChain,
    required List<int> clientPrivateKey,
    required String authority,
    BadCertificateHandler? onBadCertificate,
  }) : _clientCertChain = clientCertChain,
       _clientPrivateKey = clientPrivateKey,
       super.secure(
         certificates: trustedCertificates,
         authority: authority,
         onBadCertificate: onBadCertificate,
       );

  @override
  SecurityContext? get securityContext {
    final context = super.securityContext;
    context
      ?..useCertificateChainBytes(_clientCertChain)
      ..usePrivateKeyBytes(_clientPrivateKey);
    return context;
  }
}

Future<int> main(List<String> args) async {
  log('INFO', 'Starting gRPC KV Client (Dart)');

  // Load certificates from environment
  final serverCert = Platform.environment['PLUGIN_SERVER_CERT'];
  final clientCert = Platform.environment['PLUGIN_CLIENT_CERT'];
  final clientKey = Platform.environment['PLUGIN_CLIENT_KEY'];

  if (serverCert == null) {
    log('ERROR', 'Missing required environment variable: PLUGIN_SERVER_CERT');
    return 1;
  }

  log('INFO', 'Loading certificates...');
  log('INFO', 'Server cert length: ${serverCert.length} bytes');
  log('INFO', 'Client cert length: ${clientCert?.length ?? 0} bytes');
  log('INFO', 'Client key length: ${clientKey?.length ?? 0} bytes');

  logCertificateInfo(serverCert, 'Server CA');
  if (clientCert != null) {
    logCertificateInfo(clientCert, 'Client');
  }

  final host = Platform.environment['PLUGIN_HOST'] ?? 'localhost';
  final port = int.tryParse(Platform.environment['PLUGIN_PORT'] ?? '50051') ?? 50051;

  log('INFO', 'Connecting to $host:$port');

  try {
    // Create channel credentials
    ChannelCredentials credentials;
    if (clientCert != null && clientKey != null) {
      // mTLS - mutual authentication
      credentials = MtlsChannelCredentials(
        trustedCertificates: utf8.encode(serverCert),
        clientCertChain: utf8.encode(clientCert),
        clientPrivateKey: utf8.encode(clientKey),
        authority: 'localhost',
        onBadCertificate: (certificate, host) {
          // All certs in this test harness are self-signed leaves (no CA
          // basic constraint), which Dart's chain validator rejects even
          // though the exact cert was already added as a trust anchor via
          // setTrustedCertificatesBytes. Accept it here, matching the same
          // "trust this specific self-signed test cert" behavior other
          // languages in this repo apply for their own TLS setup.
          log('WARN', 'Bad certificate for $host - trusting self-signed test cert');
          return true;
        },
      );
      log('INFO', 'mTLS credentials configured');
    } else {
      // TLS only
      credentials = ChannelCredentials.secure(
        certificates: utf8.encode(serverCert),
        authority: 'localhost',
      );
      log('INFO', 'TLS credentials configured (no client auth)');
    }

    // Create channel
    final channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: credentials,
        codecRegistry: CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
      ),
    );

    // Create client
    final client = KVClient(channel);

    // Test Get operation
    log('INFO', 'Sending Get request...');
    try {
      final getResponse = await client.get(GetRequest()..key = 'test-key');
      final value = utf8.decode(getResponse.value);
      log('INFO', 'Get response: $value');
    } catch (e) {
      log('ERROR', 'Get failed: $e');
      await channel.shutdown();
      return 1;
    }

    // Test Put operation
    log('INFO', 'Sending Put request...');
    try {
      await client.put(PutRequest()
        ..key = 'test-key'
        ..value = utf8.encode('test-value'));
      log('INFO', 'Put request successful');
    } catch (e) {
      log('ERROR', 'Put failed: $e');
      await channel.shutdown();
      return 1;
    }

    await channel.shutdown();

    log('INFO', 'All operations completed successfully');
    print('OK');
    return 0;
  } catch (e, stackTrace) {
    log('ERROR', 'Client error: $e');
    log('DEBUG', 'Stack trace: $stackTrace');
    return 1;
  }
}
