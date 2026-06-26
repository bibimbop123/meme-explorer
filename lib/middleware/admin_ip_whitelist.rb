# frozen_string_literal: true

require 'ipaddr'

# Admin IP Whitelist Middleware
# Restricts admin access to whitelisted IP addresses
class AdminIPWhitelist
  ADMIN_PATHS = [
    '/admin',
    '/api/admin',
    '/clear_cache',
    '/force_refresh'
  ].freeze

  def initialize(app)
    @app = app
    load_whitelist
  end

  def call(env)
    request = Rack::Request.new(env)
    
    if admin_path?(request.path)
      unless whitelisted?(request.ip)
        log_blocked_attempt(request)
        return forbidden_response(request)
      end
    end
    
    @app.call(env)
  end

  private

  def admin_path?(path)
    ADMIN_PATHS.any? { |admin_path| path.start_with?(admin_path) }
  end

  def whitelisted?(ip)
    # Disabled in development
    return true if ENV['RACK_ENV'] == 'development'
    
    # Check if IP is in whitelist
    client_ip = IPAddr.new(ip)
    @whitelist.any? { |allowed_ip| allowed_ip.include?(client_ip) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def load_whitelist
    # Load from environment variable or config file
    whitelist_str = ENV['ADMIN_IP_WHITELIST'] || ''
    
    @whitelist = whitelist_str.split(',').map do |ip|
      IPAddr.new(ip.strip)
    rescue IPAddr::InvalidAddressError => e
      warn "Invalid IP in whitelist: #{ip} - #{e.message}"
      nil
    end.compact
    
    # Add localhost by default in development
    if ENV['RACK_ENV'] == 'development'
      @whitelist << IPAddr.new('127.0.0.1')
      @whitelist << IPAddr.new('::1')
    end
  end

  def log_blocked_attempt(request)
    warn "SECURITY: Blocked admin access attempt from #{request.ip} to #{request.path}"
    
    # Log to database if available
    begin
      db = get_db_connection
      db.execute(
        'INSERT INTO security_audit_log 
         (event_type, ip_address, user_agent, details, created_at) 
         VALUES (?, ?, ?, ?, ?)',
        ['admin_access_blocked', request.ip, request.user_agent, 
         { path: request.path, method: request.request_method }.to_json, 
         Time.now]
      )
    rescue => e
      warn "Failed to log blocked attempt: #{e.message}"
    end
  end

  def forbidden_response(request)
    [
      403,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Access denied', message: 'Your IP address is not authorized for admin access' }.to_json]
    ]
  end

  def get_db_connection
    require_relative '../db_helpers'
    get_db_connection
  end
end
