# Sidekiq Worker: Startup Cache Warming
# Replaces the background thread from app.rb
# Warms the meme cache on application startup

class StartupCacheWarmJob
  include Sidekiq::Worker
  
  sidekiq_options queue: :critical, retry: 2
  
  def perform
    logger.info "🔥 [CACHE WARM] Starting cache preload..."
    start_time = Time.now
    
    begin
      # Step 1: Load local memes first (fast fallback)
      local_memes = load_local_memes
      MEME_CACHE.set(:memes, local_memes.shuffle)
      logger.info "✅ [CACHE WARM] Loaded #{local_memes.size} local memes"
      
      # Step 2: Fetch API memes (can be slow)
      api_memes = fetch_api_memes
      
      if api_memes.any?
        # Combine and deduplicate
        all_memes = (api_memes + local_memes).uniq { |m| m["url"] || m["file"] }
        MEME_CACHE.set(:memes, all_memes.shuffle)
        MEME_CACHE.set(:last_refresh, Time.now)
        
        duration = ((Time.now - start_time) * 1000).round(0)
        logger.info "🎉 [CACHE WARM] Complete! #{api_memes.size} API + #{local_memes.size} local = #{all_memes.size} total (#{duration}ms)"
      else
        logger.warn "⚠️  [CACHE WARM] No API memes fetched, using local only"
      end
      
    rescue => e
      logger.error "❌ [CACHE WARM] Error: #{e.class}: #{e.message}"
      logger.error e.backtrace.first(5).join("\n")
      
      # Report to Sentry if available
      Sentry.capture_exception(e) if defined?(Sentry)
      
      # Don't fail the job - local memes are already loaded
    end
  end
  
  private
  
  def load_local_memes
    yaml_data = YAML.load_file("data/memes.yml")
    memes = if yaml_data.is_a?(Hash)
      yaml_data.values.flatten.compact
    else
      yaml_data || []
    end
    
    # Normalize file paths
    memes.map do |m|
      m_copy = m.dup
      if m_copy["file"] && m_copy["file"].start_with?("/")
        m_copy["file"] = m_copy["file"][1..-1]
      end
      m_copy
    end
  rescue => e
    logger.error "Failed to load local memes: #{e.message}"
    []
  end
  
  def fetch_api_memes
    client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
    client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
    
    return [] if client_id.empty? || client_secret.empty?
    
    # Try OAuth first
    begin
      token = get_oauth_token(client_id, client_secret)
      subreddits = YAML.load_file("data/subreddits.yml")["popular"].sample(8)
      memes = fetch_with_oauth(token, subreddits)
      return memes if memes.any?
    rescue => e
      logger.warn "OAuth fetch failed: #{e.message}, trying unauthenticated..."
    end
    
    # Fallback to unauthenticated
    begin
      subreddits = YAML.load_file("data/subreddits.yml")["popular"].sample(8)
      fetch_unauthenticated(subreddits)
    rescue => e
      logger.error "Unauthenticated fetch failed: #{e.message}"
      []
    end
  end
  
  def get_oauth_token(client_id, client_secret)
    require 'oauth2'
    client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )
    client.client_credentials.get_token(scope: "read").token
  end
  
  def fetch_with_oauth(token, subreddits, limit = 30)
    require 'httparty'
    memes = []
    
    subreddits.each do |subreddit|
      begin
        url = "https://oauth.reddit.com/r/#{subreddit}/top?t=week&limit=#{limit}"
        response = HTTParty.get(url,
          headers: {
            "Authorization" => "Bearer #{token}",
            "User-Agent" => "MemeExplorer/1.0"
          },
          timeout: 15
        )
        
        if response.success?
          data = response.parsed_response
          data["data"]["children"].each do |post|
            post_data = post["data"]
            next if post_data["is_video"] || post_data["is_self"] || !post_data["url"]
            
            memes << {
              "title" => post_data["title"],
              "url" => post_data["url"],
              "subreddit" => post_data["subreddit"],
              "likes" => post_data["ups"] || 0,
              "permalink" => post_data["permalink"]
            }
          end
        end
        sleep 1
      rescue => e
        logger.warn "Error fetching r/#{subreddit}: #{e.message}"
      end
    end
    
    memes
  end
  
  def fetch_unauthenticated(subreddits, limit = 100)
    memes = []
    user_agents = [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    ]
    
    subreddits.each do |subreddit|
      begin
        url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
        uri = URI(url)
        
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request["User-Agent"] = user_agents.sample
          request["Accept"] = "application/json"
          http.request(request)
        end
        
        if response.code == "200"
          data = JSON.parse(response.body)
          data["data"]["children"].each do |post|
            post_data = post["data"]
            next if post_data["is_video"] || post_data["is_self"] || !post_data["url"]
            
            memes << {
              "title" => post_data["title"],
              "url" => post_data["url"],
              "subreddit" => post_data["subreddit"],
              "likes" => post_data["ups"] || 0
            }
          end
        end
        sleep 0.5
      rescue => e
        logger.warn "Error fetching r/#{subreddit}: #{e.message}"
      end
    end
    
    memes
  end
end
