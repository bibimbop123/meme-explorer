# frozen_string_literal: true

require 'net/http'
require 'json'

# Alerting service for production monitoring
class AlertService
  ALERT_THRESHOLDS = {
    error_rate: 0.05,      # 5% error rate
    slow_request: 3.0,     # 3 seconds
    memory_usage: 0.90,    # 90% memory
    disk_usage: 0.85       # 85% disk
  }.freeze
  
  class << self
    def check_health
      alerts = []
      
      alerts << check_error_rate
      alerts << check_slow_requests
      alerts << check_memory
      alerts << check_disk
      
      alerts.compact
    end
    
    def send_alert(message, level: :warning)
      AppLogger.send(level, "[ALERT] #{message}")
      
      # Send to Slack if configured
      send_to_slack(message, level) if slack_configured?
      
      # Send to Sentry if available
      send_to_sentry(message, level) if sentry_configured?
    end
    
    private
    
    def check_error_rate
      cutoff = Time.now - 3600
      total = DB.get_first_value(
        "SELECT COUNT(*) FROM performance_metrics WHERE created_at > ?", [cutoff]
      ).to_i
      errors = DB.get_first_value(
        "SELECT COUNT(*) FROM error_metrics WHERE created_at > ?", [cutoff]
      ).to_i
      return nil if total.zero?
      error_rate = errors.to_f / total
      if error_rate > ALERT_THRESHOLDS[:error_rate]
        "High error rate: #{(error_rate * 100).round(2)}% (#{errors}/#{total} requests)"
      end
    rescue => e
      nil
    end

    def check_slow_requests
      cutoff = Time.now - 3600
      threshold_ms = ALERT_THRESHOLDS[:slow_request] * 1000
      slow_count = DB.get_first_value(
        "SELECT COUNT(*) FROM performance_metrics WHERE created_at > ? AND duration_ms > ?",
        [cutoff, threshold_ms]
      ).to_i
      if slow_count > 10
        "#{slow_count} slow requests (>#{ALERT_THRESHOLDS[:slow_request]}s) in the last hour"
      end
    rescue => e
      nil
    end
    
    def check_memory
      # Would need actual memory monitoring integration
      # Placeholder for future implementation
      nil
    end
    
    def check_disk
      # Would need actual disk monitoring integration
      # Placeholder for future implementation
      nil
    end
    
    def send_to_slack(message, level)
      webhook_url = ENV['SLACK_WEBHOOK_URL']
      return unless webhook_url
      
      payload = {
        text: "[#{level.upcase}] #{message}",
        username: 'Meme Explorer Alerts',
        icon_emoji: level == :error ? ':rotating_light:' : ':warning:'
      }
      
      uri = URI(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
      request.body = payload.to_json
      
      http.request(request)
    rescue => e
      AppLogger.error("Failed to send Slack alert: #{e.message}")
    end
    
    def send_to_sentry(message, level)
      return unless defined?(Sentry)
      
      Sentry.capture_message(message, level: level)
    rescue => e
      AppLogger.error("Failed to send Sentry alert: #{e.message}")
    end
    
    def slack_configured?
      ENV['SLACK_WEBHOOK_URL'].to_s.length > 0
    end

    def sentry_configured?
      defined?(Sentry) && ENV['SENTRY_DSN'].to_s.length > 0
    end
  end
end
