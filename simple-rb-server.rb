# frozen_string_literal: true

require 'grpc'
require 'logger'
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
    'grpc.max_send_message_length' => 100 * 1024 * 1024,
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
    raise
  end

  private

  def setup_credentials
    @server_cert = ENV.fetch('PLUGIN_SERVER_CERT') { raise '🔐 ❌ Missing server certificate' }
    @server_key = ENV.fetch('PLUGIN_SERVER_KEY') { raise '🔐 ❌ Missing server key' }
    @client_cert = ENV.fetch('PLUGIN_CLIENT_CERT', nil)

    cert_lengths = {
      server: @server_cert.length,
      key: @server_key.length,
      client: @client_cert&.length || 0
    }

    @logger.debug "🔐 📊 Cert lengths - Server: #{cert_lengths[:server]}, " \
                 "Key: #{cert_lengths[:key]}, Client: #{cert_lengths[:client]}"

    @creds = GRPC::Core::ServerCredentials.new(
      [[@server_key.encode('ASCII'), @server_cert.encode('ASCII')]],
      @client_cert&.encode('ASCII'),
      true
    )

    @logger.info '🔒 ✅ Credentials created'
  end

  def setup_server
    @server = GRPC::RpcServer.new(pool_size: 10, max_waiting_requests: 100, **GRPC_OPTIONS)
    @server.handle(KVService.new(logger: @logger))
    @logger.info '✅ Server configured'
  end

  def bind_port
    @server.add_http2_port('[::]:50051', @creds)
    @logger.info '🌐 ✅ Port bound'
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
