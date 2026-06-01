# frozen_string_literal: true

require 'sidekiq'

# Cache Preload Worker
# Replaces the manual thread in app.rb (lines 187-265)
# Runs on application startup to warm the cache with memes
class CachePreloadWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :critical, retry: 3
  
  def perform
    logger.info "🔥 [CACHE PRELOAD] Starting cache preload..."
    
    # Load local memes first (fast)
    local_memes = load_local_memes
    
    # Set local memes immediately so server can start serving
    cache_manager.set(:memes, local_memes.shuffle)
    logger.info "✅ [CACHE PRELOAD] Cache ready with #{local_memes.size} local memes"
    
    # Now fetch API memes in background
    logger.info "🔄 [CACHE PRELOAD] Fetching API memes..."
    api_memes = fetch_api_memes
    
    # Update cache with combined memes
    if api_memes.any?
      all_memes = (api_memes + local_memes).uniq { |m| m["url"] || m["file"] }
      cache_manager.set(:memes, all_memes.shuffle)
      cache_manager.set(:last_refresh, Time.now)
      logger.info "🎉 [CACHE PRELOAD] Cache updated: #{api_memes.size} API + #{local_memes.size} local = #{all_memes.size} total"
    else
      logger.warn "⚠️ [CACHE PRELOAD] No API memes fetched, using local memes only"
    end
    
  rescue => e
    logger.error "❌ [CACHE PRELOAD] Error: #{e.class}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
    raise # Let Sidekiq handle retries
  end
  
  private
  
  def load_local_memes
    yaml_data = YAML.load_file("data/memes.yml")
    memes = if yaml_data.is_a?(Hash)
      yaml_data.values.flatten.compact
    else
      yaml_data || []
    end
    
    logger.info "📁 Loaded #{memes.size} local memes from YAML"
    memes
  rescue => e
    logger.error "Failed to load local memes: #{e.message}"
    []
  end
  
  def fetch_api_memes
    client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
    client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
    
    return [] if client_id.empty? || client_secret.empty?
    
    # Try OAuth first
    memes = fetch_with_oauth(client_id, client_secret)
    
    # Fallback to unauthenticated if OAuth failed
    memes = fetch_unauthenticated if memes.empty?
    
    memes
  end
  
  def fetch_with_oauth(client_id, client_secret)
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
    
    RedditFetcherService.new(auth_strategy: :oauth, access_token: token.token)
      .fetch_memes(subreddits, limit: 30)
      
  rescue => e
    logger.warn "OAuth fetch failed: #{e.message}"
    []
  end
  
  def fetch_unauthenticated
    subreddits = YAML.load_file("data/subreddits.yml")["popular"].sample(8)
    
    RedditFetcherService.new(auth_strategy: :static)
      .fetch_memes(subreddits, limit: 30)
      
  rescue => e
    logger.warn "Unauthenticated fetch failed: #{e.message}"
    []
  end
  
  def cache_manager
    @cache_manager ||= CacheManager.new
  end
end
