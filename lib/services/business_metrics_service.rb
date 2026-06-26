# frozen_string_literal: true

# Business Metrics Service
# Custom business metrics for monitoring
class BusinessMetricsService
  class << self
    # Record user engagement
    def record_engagement(user_id, action, value = 1)
      metric_name = "user.engagement.#{action}"
      record_metric(metric_name, value, { user_id: user_id })
    end

    # Record meme performance
    def record_meme_performance(meme_id, metric_type, value)
      metric_name = "meme.performance.#{metric_type}"
      record_metric(metric_name, value, { meme_id: meme_id })
    end

    # Record revenue metrics
    def record_revenue(amount, source)
      record_metric('revenue.total', amount, { source: source })
    end

    # Record conversion metrics
    def record_conversion(funnel_stage, user_id)
      metric_name = "conversion.#{funnel_stage}"
      record_metric(metric_name, 1, { user_id: user_id })
    end

    # Get metric summary
    def get_metric_summary(metric_name, time_range: 3600)
      redis = RedisService.connection
      key = "metrics:#{metric_name}:last_hour"
      
      data = redis.lrange(key, 0, -1).map { |v| JSON.parse(v) }
      
      {
        count: data.size,
        sum: data.sum { |d| d['value'] },
        avg: data.empty? ? 0 : data.sum { |d| d['value'] } / data.size.to_f,
        min: data.map { |d| d['value'] }.min,
        max: data.map { |d| d['value'] }.max
      }
    end

    # Get real-time dashboard data
    def dashboard_metrics
      {
        active_users: count_active_users,
        requests_per_second: calculate_rps,
        cache_hit_rate: calculate_cache_hit_rate,
        error_rate: calculate_error_rate,
        avg_response_time: calculate_avg_response_time,
        top_memes: get_top_memes,
        revenue_today: get_revenue_today
      }
    end

    private

    def record_metric(name, value, tags = {})
      redis = RedisService.connection
      
      data = {
        timestamp: Time.now.to_i,
        value: value,
        tags: tags
      }
      
      # Store in time-series list
      key = "metrics:#{name}:last_hour"
      redis.lpush(key, data.to_json)
      redis.ltrim(key, 0, 1000)  # Keep last 1000 data points
      redis.expire(key, 3600)
      
      # Update counters
      redis.incr("metrics:#{name}:count")
      redis.incrby("metrics:#{name}:sum", value)
    end

    def count_active_users
      redis = RedisService.connection
      redis.pfcount('active_users:last_hour')
    rescue
      0
    end

    def calculate_rps
      redis = RedisService.connection
      count = redis.get('metrics:requests:last_minute').to_i
      count / 60.0
    rescue
      0
    end

    def calculate_cache_hit_rate
      redis = RedisService.connection
      hits = redis.get('metrics:cache:hits').to_i
      misses = redis.get('metrics:cache:misses').to_i
      total = hits + misses
      
      total.zero? ? 0 : (hits.to_f / total * 100).round(2)
    rescue
      0
    end

    def calculate_error_rate
      redis = RedisService.connection
      errors = redis.get('metrics:errors:last_hour').to_i
      requests = redis.get('metrics:requests:last_hour').to_i
      
      requests.zero? ? 0 : (errors.to_f / requests * 100).round(2)
    rescue
      0
    end

    def calculate_avg_response_time
      redis = RedisService.connection
      sum = redis.get('metrics:response_time:sum').to_f
      count = redis.get('metrics:response_time:count').to_i
      
      count.zero? ? 0 : (sum / count).round(2)
    rescue
      0
    end

    def get_top_memes
      redis = RedisService.connection
      redis.zrevrange('trending_memes:hourly', 0, 9, with_scores: true)
    rescue
      []
    end

    def get_revenue_today
      redis = RedisService.connection
      redis.get("revenue:day:#{Date.today}").to_f
    rescue
      0
    end
  end
end
