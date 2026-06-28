require "rack/attack"

# Configure Rack::Attack cache store.
# Without this, every request raises Rack::Attack::MissingStoreError.
# Use Redis in production (shared across Puma workers), memory in dev/test.
if ENV['REDIS_URL'] && ENV['RACK_ENV'] == 'production'
  require 'redis'
  Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(
    Redis.new(url: ENV['REDIS_URL'])
  )
else
  # ActiveSupport::Cache::MemoryStore works for single-process dev/test
  require 'active_support/cache'
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end

class Rack::Attack
  ### SAFELISTS ###

  # 1. Allow all local development IPs — covers every form localhost can appear as:
  #    127.0.0.1        (IPv4 loopback)
  #    ::1              (IPv6 loopback)
  #    ::ffff:127.0.0.1 (IPv4-mapped IPv6 — what browsers often send)
  LOCAL_IPS = %w[
    127.0.0.1
    ::1
    ::ffff:127.0.0.1
    0.0.0.0
  ].freeze

  safelist("allow-localhost") do |req|
    LOCAL_IPS.include?(req.ip) || req.ip.to_s.start_with?("127.", "::ffff:127.")
  end

  # 2. Don't rate limit static assets
  safelist("allow-assets") do |req|
    req.path.start_with?("/assets", "/images", "/css", "/js", "/favicon", "/fonts")
  end

  ### SMART RATE LIMITING ###

  # 3. General browsing: GENEROUS (normal users never hit this)
  throttle("general/ip", limit: 2000, period: 60) do |req|
    req.ip unless req.path.start_with?("/api", "/login", "/signup", "/admin")
  end

  # 4. API endpoints: generous in development, moderate in production
  # The page itself makes multiple /api calls per meme view (random.json, similar.json, track-behavior)
  # so this must be high enough for normal browsing sessions
  API_LIMIT = ENV["RACK_ENV"] == "production" ? 600 : 10_000

  throttle("api/ip", limit: API_LIMIT, period: 60) do |req|
    req.ip if req.path.start_with?("/api", "/random.json", "/similar.json")
  end

  # 5. Login attempts: STRICT (brute force protection)
  throttle("login/ip", limit: 10, period: 60) do |req|
    req.ip if req.path == "/login" && req.post?
  end

  # 6. Signup attempts: STRICT (prevent spam accounts)
  throttle("signup/ip", limit: 5, period: 300) do |req|
    req.ip if req.path == "/signup" && req.post?
  end

  # 7. Admin operations: VERY STRICT (protect admin endpoints)
  throttle("admin/ip", limit: 20, period: 60) do |req|
    req.ip if req.path.start_with?("/admin") && req.post?
  end
  
  ### CUSTOM RESPONSE ###
  
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = match_data[:epoch_time]
    
    headers = {
      'Content-Type' => 'application/json',
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s,
      'Retry-After' => match_data[:period].to_s
    }
    
    [429, headers, [{
      error: "Too many requests",
      message: "You've exceeded the rate limit. Please wait #{match_data[:period]} seconds.",
      retry_after: match_data[:period]
    }.to_json]]
  end
end
