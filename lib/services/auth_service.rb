# Auth Service - Handles authentication and OAuth operations
class AuthService
  def self.verify_reddit_oauth(code, reddit_oauth_client_id, reddit_oauth_client_secret, reddit_redirect_uri)
    begin
      client = OAuth2::Client.new(
        reddit_oauth_client_id,
        reddit_oauth_client_secret,
        site: "https://www.reddit.com",
        authorize_url: "/api/v1/authorize",
        token_url: "/api/v1/access_token"
      )

      token = client.auth_code.get_token(
        code,
        redirect_uri: reddit_redirect_uri,
        headers: { "User-Agent" => "MemeExplorer/1.0" }
      )

      me_response = HTTParty.get(
        "https://oauth.reddit.com/api/v1/me",
        headers: {
          "Authorization" => "Bearer #{token.token}",
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
        token: token.token
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

  def self.generate_oauth_url(reddit_oauth_client_id, reddit_redirect_uri)
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
      state: SecureRandom.hex(16),
      scope: "identity read",
      duration: "permanent"
    )
  end

  def self.store_oauth_token(redis, token)
    return unless redis
    redis.setex("reddit:access_token", 3600, token)
    redis.setex("reddit:token_expires_at", 3600, (Time.now + 3600).to_i.to_s)
  end
end
