#!/usr/bin/env ruby
# frozen_string_literal: true

require 'grpc'
require 'logger'
require 'openssl'
require_relative '../proto/kv_pb'
require_relative '../proto/kv_services_pb'

# KVService implements the gRPC service definition for the key-value store.
class KVService < Proto::KV::Service
  def initialize(logger:)
    @logger = logger
    @logger.info '🔧 🚀 Initializing KVService'
    super()
  end

  def get(request, call)
    @logger.info "🔍 📥 Get request - Key: #{request.key}"
    log_request_details(call)
    Proto::GetResponse.new(value: 'OK'.b)
  rescue StandardError => e
    log_exception('Get request failed', e)
    raise GRPC::Unavailable, 'Internal error'
  end

  def put(request, call)
    @logger.info "📝 📥 Put request - Key: #{request.key}, Value: #{request.value.inspect}"
    log_request_details(call)
    Proto::Empty.new
  rescue StandardError => e
    log_exception('Put request failed', e)
    raise GRPC::Unavailable, 'Internal error'
  end

  private

  def log_request_details(call)
    @logger.debug "🔎 🌐 Peer: #{call.peer}"
    call.metadata.each do |key, value|
      @logger.debug "🔎 🔒 Metadata #{key}: #{value.inspect}"
    end
  rescue StandardError => e
    log_exception('Logging request details failed', e)
  end

  def log_exception(message, exception)
    @logger.error "❌ #{message}: #{exception.message}"
    @logger.error exception.backtrace.join("\n")
  end
end

# Server class encapsulates the gRPC server setup and lifecycle.
class Server
  # Default gRPC options can be configured here.
  GRPC_OPTIONS = {}.freeze

  def initialize
    @logger = Logger.new($stdout)
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S.%L')} #{severity} -- #{progname}: #{msg}\n"
    end
    @logger.level = Logger::DEBUG
  end

  def start
    @logger.info '🚀 🔄 Server starting'
    setup_credentials
    setup_server
    bind_port
    run_server
  rescue StandardError => e
    @logger.fatal "🔒 ❌ Server setup failed: #{e.message}"
    @logger.fatal e.backtrace.join("\n")
    exit(1)
  end

  private

  def load_certificate_chain(pem_data)
    pem_data.scan(/-----BEGIN CERTIFICATE-----(?:.|\n)*?-----END CERTIFICATE-----/).map do |cert|
      OpenSSL::X509::Certificate.new(cert)
    end
  end

  def inspect_certificate(pem_data, name)
    certificates = load_certificate_chain(pem_data)
    certificates.each_with_index do |cert, index|
      @logger.info "🔍 #{name} Certificate ##{index + 1} Details:"
      log_certificate_details(cert)
    end
  rescue StandardError => e
    log_exception("Error inspecting #{name} certificate", e)
  end

  def log_certificate_details(cert)
    @logger.info "   Subject: #{cert.subject}"
    @logger.info "   Issuer: #{cert.issuer}"
    @logger.info "   Valid From: #{cert.not_before}"
    @logger.info "   Valid Until: #{cert.not_after}"
    @logger.info "   Serial Number: #{cert.serial}"
    @logger.info "   Version: #{cert.version}"

    cert.extensions.each do |ext|
      case ext.oid
      when 'keyUsage'
        @logger.info "   Key Usage: #{ext.value}"
      when 'extendedKeyUsage'
        @logger.info "   Extended Key Usage: #{ext.value}"
      when 'subjectAltName'
        @logger.info "   Subject Alt Names: #{ext.value}"
      end
    end

    log_public_key_details(cert.public_key)
    @logger.info "   Signature Algorithm: #{cert.signature_algorithm}"
  end

  def log_public_key_details(key)
    case key
    when OpenSSL::PKey::RSA
      @logger.info "   Public Key: RSA #{key.n.num_bits} bits"
    when OpenSSL::PKey::EC
      @logger.info "   Public Key: EC #{key.group.curve_name}"
    else
      @logger.info "   Public Key: #{key.class} (details not parsed)"
    end
  end

  def inspect_private_key(pem_data, name)
    key = OpenSSL::PKey.read(pem_data)
    @logger.info "🔑 #{name} Key Details:"
    case key
    when OpenSSL::PKey::RSA
      @logger.info "   Type: RSA"
      @logger.info "   Size: #{key.n.num_bits} bits"
    when OpenSSL::PKey::EC
      @logger.info "   Type: EC"
      @logger.info "   Curve: #{key.group.curve_name}"
    else
      @logger.info "   Type: #{key.class} (details not parsed)"
    end
  rescue StandardError => e
    log_exception("Error inspecting #{name} key", e)
  end

  def setup_credentials
    @server_cert = ENV.fetch('PLUGIN_SERVER_CERT') { raise '🔐 ❌ Missing server certificate' }
    @server_key = ENV.fetch('PLUGIN_SERVER_KEY') { raise '🔐 ❌ Missing server key' }
    @client_cert = ENV.fetch('PLUGIN_CLIENT_CERT', nil)

    @logger.info '🔐 Loading certificates...'
    inspect_certificate(@server_cert, 'Server')
    inspect_private_key(@server_key, 'Server')
    inspect_certificate(@client_cert, 'Client') if @client_cert

    @logger.info '🔒 Creating gRPC credentials...'
    key_cert_pair = {
      private_key: @server_key,
      cert_chain: @server_cert
    }
    @logger.debug "🔑 Key Cert Pair: #{key_cert_pair.inspect}"

    @creds = GRPC::Core::ServerCredentials.new(
      @client_cert,
      [key_cert_pair],
      true
    )
    @logger.info '🔒 ✅ Credentials created'
  rescue StandardError => e
    log_exception('Credentials setup failed', e)
    raise
  end

  def setup_server
    @server = GRPC::RpcServer.new(pool_size: 10, max_waiting_requests: 100, **GRPC_OPTIONS)
    @server.handle(KVService.new(logger: @logger))
    @logger.info '✅ Server configured'
  rescue StandardError => e
    log_exception('Server setup failed', e)
    raise
  end

  def bind_port
    port = '[::]:50051'
    @server.add_http2_port(port, @creds)
    @logger.info "🌐 ✅ Port bound to #{port}"
  rescue StandardError => e
    log_exception('Port binding failed', e)
    raise
  end

  def run_server
    @server.run
    @logger.info '🚀 ✅ Server started'
    sleep
  rescue Interrupt
    @logger.info '⏹️ Server interrupted'
    shutdown
  rescue StandardError => e
    log_exception('Server encountered an error', e)
    shutdown
    raise
  end

  def shutdown
    @logger.info '🛑 Shutting down server...'
    @server.stop
    @logger.info '⏹️ Server stopped'
  end
end

Server.new.start if __FILE__ == $PROGRAM_NAME
