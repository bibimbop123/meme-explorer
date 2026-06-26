require "rack/attack"

class Rack::Attack
  ### SAFELISTS ###
  
  # 1. Allow localhost (development)
  safelist("allow-localhost") do |req|
    ["127.0.0.1", "::1"].include?(req.ip)
  end
  
  # 2. Don't rate limit static assets
  safelist("allow-assets") do |req|
    req.path.start_with?("/assets", "/images", "/css", "/js", "/favicon")
  end
  
  ### SMART RATE LIMITING ###
  
  # 3. General browsing: GENEROUS (normal users never hit this)
  throttle("general/ip", limit: 2000, period: 60) do |req|
    req.ip unless req.path.start_with?("/api", "/login", "/signup", "/admin")
  end
  
  # 4. API endpoints: MODERATE (allows rapid API usage)
  throttle("api/ip", limit: 600, period: 60) do |req|
    req.ip if req.path.start_with?("/api")
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
