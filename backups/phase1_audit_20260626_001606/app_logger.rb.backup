# frozen_string_literal: true

require 'logger'
require 'json'

# AppLogger - Structured logging for MemeExplorer
# 
# Provides:
# - Structured JSON logging in production
# - Human-readable logs in development
# - Request context tracking
# - Log level control via ENV
#
# Usage:
#   AppLogger.info("User logged in", user_id: 123)
#   AppLogger.error("DB query failed", query: sql, error: e.message)
#   AppLogger.warn("Cache miss", key: cache_key)
#
class AppLogger
  class << self
    def logger
      @logger ||= create_logger
    end
    
    # Log at INFO level
    def info(message, **context)
      log(:info, message, context)
    end
    
    # Log at ERROR level
    def error(message, **context)
      log(:error, message, context)
    end
    
    # Log at WARN level
    def warn(message, **context)
      log(:warn, message, context)
    end
    
    # Log at DEBUG level
    def debug(message, **context)
      log(:debug, message, context)
    end
    
    # Set request context (call from middleware)
    def set_request_context(request_id:, user_id: nil, path: nil)
      Thread.current[:request_id] = request_id
      Thread.current[:user_id] = user_id
      Thread.current[:path] = path
    end
    
    # Clear request context (call after request)
    def clear_request_context
      Thread.current[:request_id] = nil
      Thread.current[:user_id] = nil
      Thread.current[:path] = nil
    end
    
    private
    
    def log(level, message, context)
      log_entry = {
        message: message.to_s
      }.merge(context)
      
      # Add request context if available
      if Thread.current[:request_id]
        log_entry[:request_id] = Thread.current[:request_id]
        log_entry[:user_id] = Thread.current[:user_id] if Thread.current[:user_id]
        log_entry[:path] = Thread.current[:path] if Thread.current[:path]
      end
      
      logger.send(level, log_entry)
    end
    
    def create_logger
      output = if ENV['RACK_ENV'] == 'production'
        STDOUT
      else
        FileUtils.mkdir_p('log') unless Dir.exist?('log')
        'log/app.log'
      end
      
      logger = Logger.new(output)
      logger.level = log_level
      logger.formatter = log_formatter
      logger
    end
    
    def log_level
      case ENV.fetch('LOG_LEVEL', 'INFO').upcase
      when 'DEBUG' then Logger::DEBUG
      when 'INFO' then Logger::INFO
      when 'WARN' then Logger::WARN
      when 'ERROR' then Logger::ERROR
      when 'FATAL' then Logger::FATAL
      else Logger::INFO
      end
    end
    
    def log_formatter
      if ENV['RACK_ENV'] == 'production'
        # JSON format for log aggregation (Datadog, Splunk, etc.)
        proc do |severity, datetime, progname, msg|
          entry = if msg.is_a?(Hash)
            msg.merge(
              timestamp: datetime.iso8601,
              severity: severity,
              environment: ENV['RACK_ENV']
            )
          else
            {
              timestamp: datetime.iso8601,
              severity: severity,
              message: msg.to_s,
              environment: ENV['RACK_ENV']
            }
          end
          
          entry.to_json + "\n"
        end
      else
        # Human-readable format for development
        proc do |severity, datetime, progname, msg|
          timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
          
          if msg.is_a?(Hash)
            message = msg.delete(:message) || 'No message'
            context = msg.empty? ? '' : " | #{msg.inspect}"
            "[#{timestamp}] #{severity.ljust(5)} #{message}#{context}\n"
          else
            "[#{timestamp}] #{severity.ljust(5)} #{msg}\n"
          end
        end
      end
    end
  end
end
