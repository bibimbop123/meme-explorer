class OAuthTokenService
  CACHE_KEY = "reddit_oauth_token".freeze
  TOKEN_BUFFER = 300 # refresh 5 min before expiry
  MAX_TOKEN_AGE = 3600 # 1 hour max

  def initialize(cache_manager, redis = nil)
    @cache = cache_manager
    @redis = redis
    @mutex = Mutex.new
  end

  def get_token(client_id, client_secret)
    @mutex.synchronize do
      # Check Redis first (shared across processes)
      if @redis
        cached = @redis.get(CACHE_KEY)
        parsed = JSON.parse(cached) rescue nil
        return parsed if cached && valid?(parsed)
      end

      # Fall back to in-memory cache
      token_data = @cache.get(CACHE_KEY)
      return token_data if token_data && valid?(token_data)

      # Fetch new token
      refresh_token(client_id, client_secret)
    end
  end

  private

  def refresh_token(client_id, client_secret)
    client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )

    token = client.client_credentials.get_token(scope: "read")
    token_data = {
      access_token: token.token,
      expires_at: (Time.now + token.expires_in).to_i
    }

    # Cache in both systems
    @cache.set(CACHE_KEY, token_data, expires_in: token.expires_in)
    @redis.setex(CACHE_KEY, token.expires_in, token_data.to_json) if @redis

    token_data
  end

  def valid?(token_data)
    return false unless token_data&.dig(:expires_at)

    token_data[:expires_at] > (Time.now.to_i + TOKEN_BUFFER)
  end
end
