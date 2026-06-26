# frozen_string_literal: true

# SLO Monitor Service
# Monitors Service Level Objectives and alerts on violations
class SLOMonitorService
  # Define SLOs
  SLOS = {
    availability: {
      target: 99.9,  # 99.9% uptime
      window: 30.days
    },
    latency_p95: {
      target: 150,  # 150ms P95 latency
      window: 1.hour
    },
    latency_p99: {
      target: 500,  # 500ms P99 latency
      window: 1.hour
    },
    error_rate: {
      target: 1.0,  # <1% error rate
      window: 1.hour
    },
    cache_hit_rate: {
      target: 80.0,  # >80% cache hit rate
      window: 1.hour
    }
  }.freeze

  class << self
    # Check all SLOs
    def check_slos
      results = {}
      
      SLOS.each do |slo_name, config|
        results[slo_name] = check_slo(slo_name, config)
      end
      
      # Alert on violations
      violations = results.select { |_k, v| v[:violated] }
      alert_violations(violations) if violations.any?
      
      results
    end

    # Check specific SLO
    def check_slo(name, config)
      current_value = send("measure_#{name}")
      target = config[:target]
      
      violated = case name
                when :availability, :cache_hit_rate
                  current_value < target
                when :latency_p95, :latency_p99, :error_rate
                  current_value > target
                else
                  false
                end
      
      {
        name: name,
        current: current_value,
        target: target,
        window: config[:window],
        violated: violated,
        severity: calculate_severity(name, current_value, target)
      }
    end

    # Get SLO dashboard
    def dashboard
      {
        slos: check_slos,
        error_budget: calculate_error_budget,
        incident_history: get_incident_history,
        current_status: overall_status
      }
    end

    private

    def measure_availability
      redis = RedisService.connection
      uptime_seconds = redis.get('slo:uptime:seconds').to_i
      total_seconds = redis.get('slo:total:seconds').to_i
      
      return 100.0 if total_seconds.zero?
      (uptime_seconds.to_f / total_seconds * 100).round(2)
    end

    def measure_latency_p95
      redis = RedisService.connection
      latencies = redis.lrange('metrics:latency:last_hour', 0, -1).map(&:to_f).sort
      return 0 if latencies.empty?
      
      percentile_index = (latencies.size * 0.95).ceil - 1
      (latencies[percentile_index] * 1000).round(2)  # Convert to ms
    end

    def measure_latency_p99
      redis = RedisService.connection
      latencies = redis.lrange('metrics:latency:last_hour', 0, -1).map(&:to_f).sort
      return 0 if latencies.empty?
      
      percentile_index = (latencies.size * 0.99).ceil - 1
      (latencies[percentile_index] * 1000).round(2)  # Convert to ms
    end

    def measure_error_rate
      redis = RedisService.connection
      errors = redis.get('metrics:errors:last_hour').to_i
      requests = redis.get('metrics:requests:last_hour').to_i
      
      return 0 if requests.zero?
      (errors.to_f / requests * 100).round(2)
    end

    def measure_cache_hit_rate
      redis = RedisService.connection
      hits = redis.get('metrics:cache:hits:last_hour').to_i
      total = redis.get('metrics:cache:total:last_hour').to_i
      
      return 0 if total.zero?
      (hits.to_f / total * 100).round(2)
    end

    def calculate_severity(name, current, target)
      deviation = case name
                 when :availability, :cache_hit_rate
                   ((target - current) / target * 100).abs
                 else
                   ((current - target) / target * 100).abs
                 end
      
      if deviation > 50
        :critical
      elsif deviation > 20
        :high
      elsif deviation > 10
        :medium
      else
        :low
      end
    end

    def calculate_error_budget
      availability_slo = SLOS[:availability][:target]
      allowed_downtime = (100 - availability_slo) / 100
      
      window_seconds = 30.days.to_i
      budget_seconds = window_seconds * allowed_downtime
      
      redis = RedisService.connection
      used_downtime = redis.get('slo:downtime:30days').to_i
      
      {
        total: budget_seconds,
        used: used_downtime,
        remaining: budget_seconds - used_downtime,
        percentage_remaining: ((budget_seconds - used_downtime) / budget_seconds * 100).round(2)
      }
    end

    def get_incident_history
      db = get_db_connection
      db.execute(
        'SELECT * FROM slo_incidents 
         WHERE created_at > datetime("now", "-30 days") 
         ORDER BY created_at DESC 
         LIMIT 10'
      )
    end

    def overall_status
      results = check_slos
      violations = results.count { |_k, v| v[:violated] }
      
      if violations.zero?
        :healthy
      elsif violations <= 2
        :degraded
      else
        :critical
      end
    end

    def alert_violations(violations)
      violations.each do |name, data|
        message = "SLO Violation: #{name} - Current: #{data[:current]}, Target: #{data[:target]}"
        
        # Send to Slack
        send_slack_alert(message, data[:severity]) if ENV['SLACK_WEBHOOK_URL']
        
        # Send email
        send_email_alert(message, data[:severity]) if ENV['ALERT_EMAIL']
        
        # Log incident
        log_incident(name, data)
      end
    end

    def send_slack_alert(message, severity)
      # Implementation for Slack webhook
      require 'net/http'
      require 'json'
      
      uri = URI(ENV['SLACK_WEBHOOK_URL'])
      payload = {
        text: message,
        channel: '#alerts',
        username: 'SLO Monitor',
        icon_emoji: severity == :critical ? ':rotating_light:' : ':warning:'
      }
      
      Net::HTTP.post(uri, payload.to_json, 'Content-Type' => 'application/json')
    rescue => e
      warn "Failed to send Slack alert: #{e.message}"
    end

    def send_email_alert(message, severity)
      # Implementation for email alerts
      # Using SendGrid, SES, or similar service
    end

    def log_incident(name, data)
      db = get_db_connection
      db.execute(
        'INSERT INTO slo_incidents (slo_name, current_value, target_value, severity, created_at) 
         VALUES (?, ?, ?, ?, ?)',
        [name, data[:current], data[:target], data[:severity], Time.now]
      )
    rescue => e
      warn "Failed to log SLO incident: #{e.message}"
    end

    def get_db_connection
      require_relative '../db_helpers'
      get_db_connection
    end
  end
end
