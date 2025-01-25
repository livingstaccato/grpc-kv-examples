#!/usr/bin/env ruby

require 'grpc'
require 'logger'
require 'openssl'
require_relative '../proto/kv_pb'
require_relative '../proto/kv_services_pb'

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
  def initialize
    LOGGER.info "🚀 Starting gRPC client... 🌟"
    @server_address = 'localhost:50051'
    setup_credentials
  end

  def setup_credentials
    @client_cert = ENV['PLUGIN_CLIENT_CERT']
    @client_key = ENV['PLUGIN_CLIENT_KEY']
    @server_cert = ENV['PLUGIN_SERVER_CERT']

    raise "❌ Missing client or server certificates" unless @client_cert && @client_key && @server_cert

    LOGGER.info "🔐 Creating gRPC credentials..."
    @creds = GRPC::Core::ChannelCredentials.new(
      @server_cert,
      @client_key,
      @client_cert
    )
  rescue => e
    LOGGER.error "❌ Failed to set up credentials: #{e.message}"
    raise
  end

  def run
    LOGGER.info "🔌 Connecting to #{@server_address}... 🔄"
    begin
      stub = Proto::KV::Stub.new(@server_address, @creds)

      LOGGER.info "📡 Sending Get request..."
      response = stub.get(Proto::GetRequest.new(key: 'test'))
      LOGGER.info "✨ Response: #{response.value} 📄"
      LOGGER.info "✅ Request completed successfully 🎉"
    rescue GRPC::BadStatus => e
      LOGGER.error "❌ gRPC error: #{e.code} - #{e.details} 🚫"
    rescue => e
      LOGGER.error "❌ Error: #{e.message} 🚫"
    ensure
      LOGGER.info "🔒 Shutting down client..."
      GRPC.stop
      LOGGER.info "✅ Client shutdown complete."
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
