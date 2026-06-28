# frozen_string_literal: true

# Traffic Analysis Service
# Monitors and analyzes traffic patterns for anomaly detection
class TrafficAnalysisService
  class << self
    # Analyze traffic for anomalies
    def analyze_traffic
      {
        suspicious_ips: detect_suspicious_ips,
        attack_patterns: detect_attack_patterns,
        anomalies: detect_anomalies
      }
    end

    # Detect suspicious IP addresses
    def detect_suspicious_ips(threshold: 1000)
      redis = RedisService.connection
      
      # Get IPs with high request rates
      suspicious = []
      redis.keys('rate_limit:*').each do |key|
        ip = key.split(':').last
        count = redis.get(key).to_i
        
        if count > threshold
          suspicious << {
            ip: ip,
            requests: count,
            severity: calculate_severity(count, threshold)
          }
        end
      end
      
      suspicious
    end

    # Detect common attack patterns
    def detect_attack_patterns
      patterns = {
        sql_injection: detect_sql_injection_attempts,
        xss_attempts: detect_xss_attempts,
        path_traversal: detect_path_traversal,
        brute_force: detect_brute_force_attempts
      }
      
      patterns.select { |_k, v| v.any? }
    end

    # Detect traffic anomalies
    def detect_anomalies
      current_rate = calculate_current_request_rate
      baseline_rate = calculate_baseline_rate
      
      anomaly_score = (current_rate - baseline_rate) / baseline_rate.to_f
      
      {
        current_rate: current_rate,
        baseline_rate: baseline_rate,
        anomaly_score: anomaly_score,
        is_anomaly: anomaly_score > 2.0  # 200% above baseline
      }
    end

    # Block suspicious IP
    def block_ip(ip, duration: 3600, reason: 'Suspicious activity')
      redis = RedisService.connection
      redis.setex("blocked_ip:#{ip}", duration, reason)
      
      log_block_action(ip, duration, reason)
    end

    # Check if IP is blocked
    def blocked?(ip)
      redis = RedisService.connection
      redis.exists("blocked_ip:#{ip}")
    end

    private

    def calculate_severity(count, threshold)
      ratio = count.to_f / threshold
      if ratio > 10
        :critical
      elsif ratio > 5
        :high
      elsif ratio > 2
        :medium
      else
        :low
      end
    end

    def detect_sql_injection_attempts
      db = get_db_connection
      db.execute(
        "SELECT ip_address, COUNT(*) as count 
         FROM security_audit_log 
         WHERE event_type = 'sql_injection_attempt' 
         AND created_at > datetime('now', '-1 hour')
         GROUP BY ip_address 
         HAVING COUNT(*) > 5"
      )
    end

    def detect_xss_attempts
      db = get_db_connection
      db.execute(
        "SELECT ip_address, COUNT(*) as count 
         FROM security_audit_log 
         WHERE event_type = 'xss_attempt' 
         AND created_at > datetime('now', '-1 hour')
         GROUP BY ip_address 
         HAVING COUNT(*) > 5"
      )
    end

    def detect_path_traversal
      db = get_db_connection
      db.execute(
        "SELECT ip_address, COUNT(*) as count 
         FROM security_audit_log 
         WHERE event_type = 'path_traversal_attempt' 
         AND created_at > datetime('now', '-1 hour')
         GROUP BY ip_address 
         HAVING COUNT(*) > 3"
      )
    end

    def detect_brute_force_attempts
      db = get_db_connection
      db.execute(
        "SELECT ip_address, COUNT(*) as count 
         FROM security_audit_log 
         WHERE event_type = 'failed_login' 
         AND created_at > datetime('now', '-15 minutes')
         GROUP BY ip_address 
         HAVING COUNT(*) > 10"
      )
    end

    def calculate_current_request_rate
      redis = RedisService.connection
      redis.get('metrics:request_rate:current').to_i
    end

    def calculate_baseline_rate
      redis = RedisService.connection
      redis.get('metrics:request_rate:baseline').to_i
    end

    def log_block_action(ip, duration, reason)
      db = get_db_connection
      db.execute(
        'INSERT INTO security_audit_log 
         (event_type, ip_address, details, created_at) 
         VALUES (?, ?, ?, ?)',
        ['ip_blocked', ip, { duration: duration, reason: reason }.to_json, Time.now]
      )
    end

    def get_db_connection
      DB
    end
  end
end
