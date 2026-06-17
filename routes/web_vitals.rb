# frozen_string_literal: true

# Web Vitals tracking endpoint
# Receives Core Web Vitals metrics from clients

app.post '/api/vitals' do
  content_type :json
  
  begin
    data = JSON.parse(request.body.read)
    
    metric = data['metric']
    value = data['value']
    url = data['url']
    
    # Log to application logger
    AppLogger.info("Web Vital - #{metric.upcase}: #{value}ms on #{url}")
    
    # Store in Redis for aggregation
    redis_key = "web_vitals:#{Date.today}:#{metric}"
    RedisService.rpush(redis_key, value.to_s)
    RedisService.expire(redis_key, 604800) # Keep for 7 days
    
    # Alert if critical thresholds exceeded
    if (metric == 'lcp' && value > 4000) ||
       (metric == 'fid' && value > 300) ||
       (metric == 'cls' && value > 0.25)
      AppLogger.warn("⚠️ Critical Web Vital: #{metric.upcase} = #{value}")
    end
    
    { success: true }.to_json
  rescue => e
    AppLogger.error("Web Vitals tracking error: #{e.message}")
    status 500
    { error: 'Internal server error' }.to_json
  end
end

# Get Web Vitals dashboard data
app.get '/admin/web-vitals' do
  protected!
  
  @vitals_data = {}
  %w[lcp fid cls].each do |metric|
    redis_key = "web_vitals:#{Date.today}:#{metric}"
    values = RedisService.lrange(redis_key, 0, -1).map(&:to_f)
    
    next if values.empty?
    
    @vitals_data[metric] = {
      count: values.size,
      avg: (values.sum / values.size).round(2),
      p50: percentile(values, 50).round(2),
      p75: percentile(values, 75).round(2),
      p95: percentile(values, 95).round(2)
    }
  end
  
  erb :'admin/web_vitals'
end

def percentile(values, p)
  sorted = values.sort
  index = (p / 100.0 * sorted.length).ceil - 1
  sorted[[index, 0].max]
end
