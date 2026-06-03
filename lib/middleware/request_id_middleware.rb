# frozen_string_literal: true

require 'securerandom'
require_relative '../app_logger'

# Request ID Middleware
# Assigns a unique ID to each request for tracing and correlation
# Week 2 Implementation - June 3, 2026

class RequestIdMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    # Generate or extract request ID
    request_id = env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid
    
    # Store in thread for AppLogger to use
    Thread.current[:request_id] = request_id
    
    # Store in env for request context
    env['REQUEST_ID'] = request_id
    
    # Call the app
    status, headers, body = @app.call(env)
    
    # Add request ID to response headers
    headers['X-Request-ID'] = request_id
    
    [status, headers, body]
  ensure
    # Clean up thread variable
    Thread.current[:request_id] = nil
  end
end
