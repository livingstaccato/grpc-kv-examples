#!/usr/bin/env ruby
# frozen_string_literal: true

require 'grpc'
require 'logger'
require 'openssl'
require_relative 'proto/kv_pb'
require_relative 'proto/kv_services_pb'

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
  end

  def put(request, call)
    @logger.info "📝 📥 Put request - Key: #{request.key}"
    log_request_details(call)
    Proto::Empty.new
  end

  private

  def log_request_details(call)
    @logger.debug "🔎 🌐 Peer: #{call.peer}"
    call.metadata.each do |key, value|
      @logger.debug "🔎 🔒 Auth #{key}: #{value}"
    end
  rescue StandardError => e
    @logger.error "🔎 ❌ Logging error: #{e.message}"
  end
end

class Server
  GRPC_OPTIONS = {
    'grpc.max_receive_message_length' => 100 * 1024 * 1024,
    'grpc.keepalive_time_ms' => 5000,
    'grpc.keepalive_timeout_ms' => 1000,
    'grpc.keepalive_permit_without_calls' => 1,
    'grpc.http2.min_time_between_pings_ms' => 5000,
    'grpc.ssl_handshake_timeout_ms' => 5000,
    'grpc.http2.max_pings_without_data' => 0
  }.freeze

  def initialize
    @logger = Logger.new($stdout, level: :debug)
    @logger.formatter = ->(_, time, _, msg) { "#{time.strftime('%Y-%m-%d %H:%M:%S.%3N')} - #{msg}\n" }
  end

  def start
    @logger.info '🚀 🔄 Server starting'
    setup_credentials
    setup_server
    bind_port
    run_server
  rescue StandardError => e
    @logger.fatal "🔒 ❌ Server setup failed: #{e.message}"
    @logger.fatal "   #{e.backtrace.join("\n   ")}"
    raise
  end

  private

  def inspect_certificate(pem_data, name)
    cert = OpenSSL::X509::Certificate.new(pem_data)
    @logger.info "🔍 #{name} Certificate Details:"
    @logger.info "    Subject: #{cert.subject}"
    @logger.info "    Issuer: #{cert.issuer}"
    @logger.info "    Valid From: #{cert.not_before}"
    @logger.info "    Valid Until: #{cert.not_after}"
    @logger.info "    Serial Number: #{cert.serial}"
    @logger.info "    Version: #{cert.version}"
    
    cert.extensions.each do |ext|
      case ext.oid
      when 'keyUsage'
        @logger.info "    Key Usage: #{ext.value}"
      when 'extendedKeyUsage'
        @logger.info "    Extended Key Usage: #{ext.value}"
      when 'subjectAltName'
        @logger.info "    Subject Alt Names: #{ext.value}"
      end
    end

    key = cert.public_key
    case key
    when OpenSSL::PKey::RSA
      @logger.info "    Public Key: RSA #{key.n.num_bits} bits"
    when OpenSSL::PKey::EC
      @logger.info "    Public Key: EC #{key.group.curve_name}"
    end
    @logger.info "    Signature Algorithm: #{cert.signature_algorithm}"
  rescue StandardError => e
    @logger.error "    Error inspecting certificate: #{e.message}"
  end

  def inspect_private_key(pem_data, name)
    key = OpenSSL::PKey.read(pem_data)
    @logger.info "🔑 #{name} Key Details:"
    case key
    when OpenSSL::PKey::RSA
      @logger.info "    Type: RSA"
      @logger.info "    Size: #{key.n.num_bits} bits"
    when OpenSSL::PKey::EC
      @logger.info "    Type: EC"
      @logger.info "    Curve: #{key.group.curve_name}"
    end
  rescue StandardError => e
    @logger.error "    Error inspecting key: #{e.message}"
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
    @creds = GRPC::Core::ServerCredentials.new(
      nil,
      [key_cert_pair],
      true
    )
    @logger.info '🔒 ✅ Credentials created'
  rescue StandardError => e
    @logger.error "🔒 ❌ Credentials setup failed: #{e.message}"
    @logger.error "   #{e.backtrace.join("\n   ")}"
    raise
  end

  def setup_server
    @server = GRPC::RpcServer.new(pool_size: 10, max_waiting_requests: 100, **GRPC_OPTIONS)
    @server.handle(KVService.new(logger: @logger))
    @logger.info '✅ Server configured'
  end

  def bind_port
    port = '[::]:50051'
    @server.add_http2_port(port, @creds)
    @logger.info "🌐 ✅ Port bound to #{port}"
  rescue StandardError => e
    @logger.error "🌐 ❌ Port binding failed: #{e.message}"
    raise
  end

  def run_server
    @server.run
    @logger.info '🚀 ✅ Server started'
    sleep
  rescue Interrupt
    shutdown
  rescue StandardError => e
    @logger.error "⚡ ❌ Error: #{e.message}"
    shutdown
    raise
  end

  def shutdown
    @server.stop
    @logger.info '⏹️ Server stopped'
  end
end

Server.new.start if __FILE__ == $PROGRAM_NAME
