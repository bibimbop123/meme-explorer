# frozen_string_literal: true

# Advanced Rate Limiter
# Multi-tier rate limiting with dynamic throttling
class AdvancedRateLimiter
  LIMITS = {
    anonymous: { requests: 100, period: 60 },
    authenticated: { requests: 300, period: 60 },
    premium: { requests: 1000, period: 60 },
    admin: { requests: 10_000, period: 60 },
    search: { requests: 20, period: 60 },
    cache_refresh: { requests: 5, period: 3600 }
  }.freeze

  def initialize(app)
    @app = app
    @redis = RedisService.connection
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Determine rate limit tier
    tier = determine_tier(request)
    limit_key = "#{tier}:#{request.path}"
    
    # Check rate limit
    unless check_rate_limit(request.ip, limit_key, tier)
      return rate_limit_response(tier)
    end
    
    @app.call(env)
  end

  private

  def determine_tier(request)
    # Check endpoint type
    return :cache_refresh if request.path == '/force_refresh'
    return :search if request.path.start_with?('/search')
    
    # Check user tier
    session = request.session
    return :anonymous unless session[:user_id]
    
    user = get_user(session[:user_id])
    return :admin if user&.admin?
    return :premium if user&.premium?
    
    :authenticated
  end

  def check_rate_limit(ip, key, tier)
    limits = LIMITS[tier]
    redis_key = "rate_limit:#{key}:#{ip}"
    
    current = @redis.get(redis_key).to_i
    
    if current >= limits[:requests]
      # Increment violation counter
      @redis.incr("rate_limit:violations:#{ip}")
      false
    else
      @redis.multi do |multi|
        multi.incr(redis_key)
        multi.expire(redis_key, limits[:period])
      end
      true
    end
  rescue => e
    # Fail open on Redis errors
    warn "Rate limit check failed: #{e.message}"
    true
  end

  def rate_limit_response(tier)
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => LIMITS[tier][:period].to_s
      },
      [{
        error: 'Rate limit exceeded',
        limit: LIMITS[tier][:requests],
        period: LIMITS[tier][:period],
        retry_after: LIMITS[tier][:period]
      }.to_json]
    ]
  end

  def get_user(user_id)
    UserService.find_by_id(user_id)
  end
end
