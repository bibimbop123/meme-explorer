# Auth Service - Handles authentication and OAuth operations
class AuthService
  # ✅ SECURITY: Account lockout configuration
  MAX_FAILED_ATTEMPTS = 5
  LOCKOUT_DURATION = 900  # 15 minutes in seconds
  
  def self.verify_reddit_oauth(code, reddit_oauth_client_id, reddit_oauth_client_secret, reddit_redirect_uri)
    begin
      # Exchange authorization code for access token using HTTParty
      # Reddit requires Basic Auth with client credentials
      auth_string = Base64.strict_encode64("#{reddit_oauth_client_id}:#{reddit_oauth_client_secret}")
      
      token_response = HTTParty.post(
        "https://www.reddit.com/api/v1/access_token",
        body: {
          grant_type: "authorization_code",
          code: code,
          redirect_uri: reddit_redirect_uri
        },
        headers: {
          "Authorization" => "Basic #{auth_string}",
          "User-Agent" => "MemeExplorer/1.0",
          "Content-Type" => "application/x-www-form-urlencoded"
        },
        timeout: 10
      )

      unless token_response.success?
        puts "❌ Reddit token exchange failed:"
        puts "Status: #{token_response.code}"
        puts "Body: #{token_response.body}"
        puts "Headers sent: Authorization=Basic [REDACTED], User-Agent=MemeExplorer/1.0"
        raise "Token exchange failed: #{token_response.code} - #{token_response.body}"
      end
      
      puts "✅ Token exchange successful!"

      token_data = token_response.parsed_response
      access_token = token_data["access_token"]

      # Get user info
      me_response = HTTParty.get(
        "https://oauth.reddit.com/api/v1/me",
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "User-Agent" => "MemeExplorer/1.0"
        },
        timeout: 10
      )

      raise "OAuth API failed: #{me_response.code}" unless me_response.success?

      user_data = me_response.parsed_response
      {
        success: true,
        username: user_data["name"],
        id: user_data["id"],
        token: access_token
      }
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end

  def self.authenticate_email(email, password)
    user = UserService.find_by_email(email)
    return nil unless user

    verified = UserService.verify_password(password, user["password_hash"])
    verified ? user["id"] : nil
  end

  def self.generate_oauth_url(reddit_oauth_client_id, reddit_redirect_uri, state)
    client = OAuth2::Client.new(
      reddit_oauth_client_id,
      nil,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )

    client.auth_code.authorize_url(
      redirect_uri: reddit_redirect_uri,
      response_type: "code",
      state: state,
      scope: "identity read",
      duration: "permanent"
    )
  end

  def self.store_oauth_token(redis, token)
    return unless redis && token
    begin
      redis.setex("reddit:access_token", 3600, token)
      redis.setex("reddit:token_expires_at", 3600, (Time.now + 3600).to_i.to_s)
      puts "✅ [AUTH] Reddit token stored in Redis cache"
    rescue => e
      AppLogger.warn("Redis token storage failed", error: e.message) rescue nil
      puts "⚠️  [AUTH] Redis token storage failed (non-critical): #{e.message}"
      # Non-critical - OAuth still works without token caching
    end
  end
  
  # ✅ SECURITY FIX: Account lockout methods to prevent brute force
  def self.record_failed_login(email, redis = nil)
    return unless email
    
    key = "failed_login:#{email.downcase}"
    
    if redis
      # Use Redis for distributed tracking
      begin
        current = redis.get(key).to_i
        redis.setex(key, LOCKOUT_DURATION, current + 1)
        AppLogger.warn("Failed login attempt", {
          email: email,
          attempts: current + 1,
          max_attempts: MAX_FAILED_ATTEMPTS
        })
      rescue => e
        AppLogger.error("Failed to record failed login in Redis", error: e.message)
      end
    else
      # Fallback to in-memory tracking (less secure but better than nothing)
      @failed_logins ||= {}
      @failed_logins[email] ||= { count: 0, locked_until: nil }
      @failed_logins[email][:count] += 1
      @failed_logins[email][:locked_until] = Time.now + LOCKOUT_DURATION if @failed_logins[email][:count] >= MAX_FAILED_ATTEMPTS
    end
  end
  
  def self.account_locked?(email, redis = nil)
    return false unless email
    
    key = "failed_login:#{email.downcase}"
    
    if redis
      begin
        attempts = redis.get(key).to_i
        locked = attempts >= MAX_FAILED_ATTEMPTS
        
        if locked
          ttl = redis.ttl(key)
          AppLogger.warn("Account locked", {
            email: email,
            attempts: attempts,
            ttl_seconds: ttl
          })
        end
        
        return locked
      rescue => e
        AppLogger.error("Failed to check account lock status in Redis", error: e.message)
        return false  # Fail open to not lock out users if Redis is down
      end
    else
      # Fallback to in-memory
      @failed_logins ||= {}
      data = @failed_logins[email]
      return false unless data
      
      if data[:locked_until] && Time.now < data[:locked_until]
        return true
      elsif data[:locked_until] && Time.now >= data[:locked_until]
        # Lockout expired, reset
        @failed_logins.delete(email)
        return false
      end
      
      data[:count] >= MAX_FAILED_ATTEMPTS
    end
  end
  
  def self.clear_failed_logins(email, redis = nil)
    return unless email
    
    key = "failed_login:#{email.downcase}"
    
    if redis
      begin
        redis.del(key)
        AppLogger.info("Cleared failed login attempts", { email: email })
      rescue => e
        AppLogger.error("Failed to clear failed logins in Redis", error: e.message)
      end
    else
      @failed_logins ||= {}
      @failed_logins.delete(email)
    end
  end
  
  def self.remaining_attempts(email, redis = nil)
    return MAX_FAILED_ATTEMPTS unless email
    
    key = "failed_login:#{email.downcase}"
    
    if redis
      begin
        attempts = redis.get(key).to_i
        return [MAX_FAILED_ATTEMPTS - attempts, 0].max
      rescue
        return MAX_FAILED_ATTEMPTS
      end
    else
      @failed_logins ||= {}
      data = @failed_logins[email]
      return MAX_FAILED_ATTEMPTS unless data
      [MAX_FAILED_ATTEMPTS - data[:count], 0].max
    end
  end
  
  def self.lockout_time_remaining(email, redis = nil)
    return 0 unless email
    
    key = "failed_login:#{email.downcase}"
    
    if redis
      begin
        return redis.ttl(key) if account_locked?(email, redis)
        return 0
      rescue
        return 0
      end
    else
      @failed_logins ||= {}
      data = @failed_logins[email]
      return 0 unless data && data[:locked_until]
      
      remaining = (data[:locked_until] - Time.now).to_i
      [remaining, 0].max
    end
  end
end
