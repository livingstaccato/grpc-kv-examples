#!/usr/bin/env dart
/// Dart gRPC KV Server with mTLS
///
/// Implements a simple key-value store service with mutual TLS authentication.

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
    // Extract subject from certificate (basic parsing)
    final lines = certPem.split('\n');
    log('INFO', '$prefix Certificate loaded (${certPem.length} bytes)');
  } catch (e) {
    log('WARN', 'Failed to parse certificate: $e');
  }
}

/// KV Service implementation
class KVService extends KVServiceBase {
  final Map<String, List<int>> _store = {};

  @override
  Future<GetResponse> get(ServiceCall call, GetRequest request) async {
    final key = request.key;
    log('INFO', 'Get request - Key: $key');

    // Log peer info
    final peer = call.clientCertificate;
    if (peer != null) {
      log('DEBUG', 'Client certificate subject: ${peer.subject}');
    }

    if (key.isEmpty) {
      log('ERROR', 'Get request rejected: empty key');
      throw GrpcError.invalidArgument('key cannot be empty');
    }

    log('INFO', 'Get request completed successfully');
    return GetResponse()..value = utf8.encode('OK');
  }

  @override
  Future<Empty> put(ServiceCall call, PutRequest request) async {
    final key = request.key;
    final value = request.value;
    log('INFO', 'Put request - Key: $key');

    if (key.isEmpty) {
      log('ERROR', 'Put request rejected: empty key');
      throw GrpcError.invalidArgument('key cannot be empty');
    }
    if (value.isEmpty) {
      log('ERROR', 'Put request rejected: empty value');
      throw GrpcError.invalidArgument('value cannot be empty');
    }

    _store[key] = value;
    log('INFO', 'Put request completed successfully');
    return Empty();
  }
}

Future<void> main(List<String> args) async {
  log('INFO', 'Starting gRPC KV Server (Dart)');

  // Load certificates from environment
  final serverCert = Platform.environment['PLUGIN_SERVER_CERT'];
  final serverKey = Platform.environment['PLUGIN_SERVER_KEY'];
  final clientCert = Platform.environment['PLUGIN_CLIENT_CERT'];

  if (serverCert == null || serverKey == null) {
    log('ERROR',
        'Missing required environment variables: PLUGIN_SERVER_CERT, PLUGIN_SERVER_KEY');
    exit(1);
  }

  log('INFO', 'Loading certificates...');
  log('INFO', 'Server cert length: ${serverCert.length} bytes');
  log('INFO', 'Server key length: ${serverKey.length} bytes');
  log('INFO', 'Client cert length: ${clientCert?.length ?? 0} bytes');

  logCertificateInfo(serverCert, 'Server');
  if (clientCert != null) {
    logCertificateInfo(clientCert, 'Client CA');
  }

  final port = int.tryParse(Platform.environment['PLUGIN_PORT'] ?? '50051') ?? 50051;

  try {
    // Create security context
    final securityContext = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(serverCert))
      ..usePrivateKeyBytes(utf8.encode(serverKey));

    if (clientCert != null) {
      securityContext.setTrustedCertificatesBytes(utf8.encode(clientCert));
    }

    // Create server with TLS
    final server = Server.create(
      services: [KVService()],
      codecRegistry: CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
    );

    await server.serve(
      address: InternetAddress.anyIPv4,
      port: port,
      security: ServerTlsCredentials(
        certificate: utf8.encode(serverCert),
        privateKey: utf8.encode(serverKey),
        clientCertificateAuthority: clientCert != null ? utf8.encode(clientCert) : null,
        requireClientCertificate: clientCert != null,
      ),
    );

    log('INFO', 'gRPC KV Server listening on 0.0.0.0:$port');
    log('INFO', 'Server ready to accept connections');

    // Handle shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      log('INFO', 'Received SIGINT, shutting down...');
      await server.shutdown();
      log('INFO', 'Server shutdown complete');
      exit(0);
    });

    ProcessSignal.sigterm.watch().listen((_) async {
      log('INFO', 'Received SIGTERM, shutting down...');
      await server.shutdown();
      log('INFO', 'Server shutdown complete');
      exit(0);
    });
  } catch (e, stackTrace) {
    log('ERROR', 'Failed to start server: $e');
    log('DEBUG', 'Stack trace: $stackTrace');
    exit(1);
  }
}
