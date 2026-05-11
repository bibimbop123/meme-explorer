class CacheRefreshWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 3, backtrace: true
  
  def perform
    puts "🔄 [CACHE WORKER] Starting cache refresh at #{Time.now}"
    
    # Load local memes as fallback
    local_memes = load_local_memes
    puts "✅ [CACHE WORKER] Loaded #{local_memes.size} local memes"
    
    # Try OAuth2 first, fallback to unauthenticated
    api_memes = fetch_with_oauth || fetch_without_auth
    puts "✅ [CACHE WORKER] Fetched #{api_memes.size} API memes"
    
    # Update cache with validated memes
    validated = api_memes.select { |m| m["url"] && m["url"].to_s.strip.length > 0 }
    
    if validated.empty?
      MEME_CACHE.set(:memes, local_memes.shuffle)
      puts "⚠️ [CACHE WORKER] No API memes - using local only"
    else
      all_memes = (validated + local_memes).uniq { |m| m["url"] }
      MEME_CACHE.set(:memes, all_memes.shuffle)
      puts "✅ [CACHE WORKER] Cache updated: #{validated.size} API + #{local_memes.size} local = #{all_memes.size} total"
    end
    
    MEME_CACHE.set(:last_refresh, Time.now)
    puts "✅ [CACHE WORKER] Cache refresh complete"
    
  rescue => e
    puts "❌ [CACHE WORKER] Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry mechanism
  end
  
  private
  
  def load_local_memes
    yaml_data = YAML.load_file("data/memes.yml")
    if yaml_data.is_a?(Hash)
      yaml_data.values.flatten.compact
    else
      yaml_data || []
    end
  rescue => e
    puts "❌ Failed to load local memes: #{e.message}"
    []
  end
  
  def fetch_with_oauth
    client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
    client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
    
    return nil if client_id.empty? || client_secret.empty?
    
    require 'oauth2'
    
    client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )
    
    token = client.client_credentials.get_token(scope: "read")
    subreddits = YAML.load_file("data/subreddits.yml")["popular"].sample(8)
    
    MemeExplorer.fetch_reddit_memes_authenticated(token.token, subreddits, 30)
  rescue => e
    puts "⚠️ OAuth fetch failed: #{e.message}"
    nil
  end
  
  def fetch_without_auth
    subreddits = YAML.load_file("data/subreddits.yml")["popular"].sample(8)
    MemeExplorer.fetch_reddit_memes_static(subreddits, 30)
  rescue => e
    puts "⚠️ Unauthenticated fetch failed: #{e.message}"
    []
  end
end
