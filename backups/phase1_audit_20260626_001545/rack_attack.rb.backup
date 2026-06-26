require "rack/attack"

class Rack::Attack
  # Allow all local requests
  safelist("allow-localhost") do |req|
    ["127.0.0.1", "::1"].include?(req.ip)
  end

  # Limit requests per IP to 60 per minute (exclude /random for smooth navigation)
  throttle("req/ip", limit: 60, period: 60) do |req|
    req.ip unless req.path.start_with?("/assets") || req.path.start_with?("/random")
  end

  # Custom response for throttling
  self.throttled_response = lambda do |env|
    [429, { "Content-Type" => "application/json" }, [{ error: "Too many requests. Slow down!" }.to_json]]
  end
end
