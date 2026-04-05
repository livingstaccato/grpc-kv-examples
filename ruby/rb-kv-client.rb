#!/usr/bin/env ruby

require 'grpc'
require 'logger'
require 'openssl'
require_relative 'proto/kv_pb'
require_relative 'proto/kv_services_pb'

LOGGER = Logger.new($stdout).tap do |log|
  log.formatter = proc do |severity, datetime, _, msg|
    "#{datetime.strftime('%Y-%m-%d %H:%M:%S.%L')} #{severity}: #{msg}\n"
  end
end

class CertificateLogger
  def self.log_cert_info(cert, prefix)
    LOGGER.info "🔍 #{prefix} Certificate Details: 📋"
    LOGGER.info "🔍  Subject: #{cert.subject} 📝"
    LOGGER.info "🔍  Issuer: #{cert.issuer} 📝"
    LOGGER.info "🔍  Valid From: #{cert.not_before} ⏰"
    LOGGER.info "🔍  Valid Until: #{cert.not_after} ⏰"
    LOGGER.info "🔍  Serial Number: #{cert.serial} 🔢"
    LOGGER.info "🔍  Version: #{cert.version} 📊"
    LOGGER.info "🔍  Key Usage: #{cert.extensions.find { |ext| ext.oid == 'keyUsage' }&.value} 🔑"
    LOGGER.info "🔍  Extended Key Usage: #{cert.extensions.find { |ext| ext.oid == 'extendedKeyUsage' }&.value} 🔐"
    
    san_ext = cert.extensions.find { |ext| ext.oid == 'subjectAltName' }
    LOGGER.info "🔍  DNS Names: #{san_ext&.value} 🌐" if san_ext
  end
end

class GrpcClient
  def self.get_trusted_server_cert(addr)
    LOGGER.info "🌐 Dialing server to fetch certificate 🔄"
    
    tcp_socket = TCPSocket.new(*addr.split(':'))
    ssl_context = OpenSSL::SSL::SSLContext.new

    ssl_context.ciphers = [
      'ECDHE-ECDSA-AES128-GCM-SHA256',
      'ECDHE-ECDSA-AES256-GCM-SHA384',
      'ECDHE-ECDSA-CHACHA20-POLY1305'
    ]
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
    ssl_socket.connect
    
    cert = ssl_socket.peer_cert
    CertificateLogger.log_cert_info(cert, "Server Certificate")
    
    cert.to_pem
  rescue => e
    raise "Failed to get server certificate: #{e.message}"
  ensure
    ssl_socket&.close
    tcp_socket&.close
  end

  def initialize
    LOGGER.info "🚀 Starting gRPC client... 🌟"
    
    @client_cert = ENV['PLUGIN_CLIENT_CERT']
    @client_key = ENV['PLUGIN_CLIENT_KEY']
    @server_cert = ENV['PLUGIN_SERVER_CERT']
    
    validate_certificates!
    setup_credentials
  end

  def validate_certificates!
    LOGGER.info "📂 Checking environment variables... 🔍"
    raise "Missing client certificates" unless @client_cert && @client_key
    
    LOGGER.info "📦 Certificate sizes - Client Cert: #{@client_cert.size} bytes, " \
                "Client Key: #{@client_key.size} bytes, " \
                "Server Cert: #{@server_cert&.size || 0} bytes 📊"
  end

  def setup_credentials
    server_address = 'localhost:50051'
    
    unless @server_cert
      LOGGER.info "🔒 No server certificate provided, fetching from server... 🔄"
      @server_cert = self.class.get_trusted_server_cert(server_address)
    end

    LOGGER.info "🔐 Creating certificate objects... 🔄"
    begin
      client_key = OpenSSL::PKey.read(@client_key)
      client_cert = OpenSSL::X509::Certificate.new(@client_cert)
      server_cert = OpenSSL::X509::Certificate.new(@server_cert)
    rescue => e
      LOGGER.error "Failed to load certificates: #{e.message}"
      raise
    end
    
    CertificateLogger.log_cert_info(client_cert, "Client")
    
    @creds = GRPC::Core::ChannelCredentials.new(
      @server_cert,
      client_key.to_pem,
      client_cert.to_pem
    )

    @channel_args = {
      'grpc.ssl_target_name_override' => 'localhost',
      'grpc.max_send_message_length' => 100 * 1024 * 1024,
      'grpc.max_receive_message_length' => 100 * 1024 * 1024,
      'grpc.keepalive_time_ms' => 10_000,
      'grpc.keepalive_timeout_ms' => 5_000,
      'grpc.keepalive_permit_without_calls' => 1,
      'grpc.http2.min_time_between_pings_ms' => 10_000,
      'grpc.ssl_handshake_timeout_ms' => 5_000
    }
  end

  def run
    LOGGER.info "🔌 Creating gRPC connection... 🔄"
    
    stub = Proto::KV::Stub.new(
      'localhost:50051',
      @creds,
      channel_args: @channel_args,
      timeout: 10
    )
    
    LOGGER.info "👥 Created gRPC client"
    LOGGER.info "📡 Sending Get request... 🔄"
    
    begin
      deadline = Time.now + 5 # 5 second timeout
      response = stub.get(Proto::GetRequest.new(key: 'test'), deadline: deadline)
      puts "✨ Response: #{response.value} 📄"
      LOGGER.info "✅ Request completed successfully 🎉"
    rescue GRPC::BadStatus => e
      LOGGER.error "❌ gRPC error: #{e.code} - #{e.details} 🚫"
      LOGGER.error "❌ Metadata: #{e.metadata} 🚫"
      raise
    rescue => e
      LOGGER.error "❌ Error: #{e.message} 🚫"
      LOGGER.error "❌ Backtrace: #{e.backtrace.join("\n")} 🚫"
      raise
    end
  end
end

if __FILE__ == $0
  begin
    client = GrpcClient.new
    client.run
  rescue => e
    LOGGER.error "❌ Fatal error: #{e.message} ⛔"
    exit 1
  end
end
