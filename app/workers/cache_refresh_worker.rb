require_relative '../../lib/concerns/distributed_lock'

class CacheRefreshWorker
  include Sidekiq::Worker
  include DistributedLock
  
  sidekiq_options queue: :default, retry: 3, backtrace: true
  
  def perform
    AppLogger.info("🔄 [CACHE WORKER] Starting cache refresh at #{Time.now}")
    
    # Use distributed lock to prevent concurrent cache updates (RACE CONDITION FIX)
    acquired = with_redis_lock("cache_refresh", ttl: 300) do
      # Get MEME_CACHE from MemeExplorer namespace
      cache = get_cache
      return unless cache
      
      # Load local memes as fallback
      local_memes = load_local_memes
    AppLogger.info("✅ [CACHE WORKER] Loaded #{local_memes.size} local memes")
      
      # Use RedditFetcherService for fetching
      api_memes = fetch_with_reddit_service
    AppLogger.info("✅ [CACHE WORKER] Fetched #{api_memes.size} API memes")
      
      # PREVENTION: Filter out blacklisted URLs and validate before caching
      validated = api_memes.select { |m| m["url"] && m["url"].to_s.strip.length > 0 }
      
      # Remove blacklisted memes (instant check)
      if defined?(ImageHealthService)
        before_blacklist = validated.size
        validated = ImageHealthService.filter_blacklisted(validated)
        blacklisted_count = before_blacklist - validated.size
    AppLogger.info("🚫 [CACHE WORKER] Filtered #{blacklisted_count} blacklisted memes") if blacklisted_count > 0
      end
      
      # Validate remaining memes (prevent broken content from entering cache)
      if defined?(ImageValidationService) && validated.size > 0
    AppLogger.info("🔍 [CACHE WORKER] Validating #{validated.size} memes...")
        validation_start = Time.now
        
        validated_memes = validated.select.with_index do |meme, index|
          url = meme["url"]
          is_valid = ImageValidationService.validate(url)
          
          # Log progress every 20 memes
          if (index + 1) % 20 == 0
    AppLogger.info("   Progress: #{index + 1}/#{validated.size} validated")
          end
          
          is_valid
        end
        
        validation_duration = (Time.now - validation_start).round(2)
        rejected = validated.size - validated_memes.size
        validated = validated_memes
    AppLogger.info("✅ [CACHE WORKER] Validation complete in #{validation_duration}s: #{validated.size} valid, #{rejected} rejected")
      end
      
      if validated.empty?
        cache.set(:memes, local_memes.shuffle)
    AppLogger.info("⚠️ [CACHE WORKER] No valid API memes - using local only")
      else
        all_memes = (validated + local_memes).uniq { |m| m["url"] || m["file"] }
        cache.set(:memes, all_memes.shuffle)
    AppLogger.info("✅ [CACHE WORKER] Cache updated: #{validated.size} API + #{local_memes.size} local = #{all_memes.size} total")
      end
      
      cache.set(:last_refresh, Time.now)
    AppLogger.info("✅ [CACHE WORKER] Cache refresh complete")
    end
    
    unless acquired
    AppLogger.info("⚠️ [CACHE WORKER] Could not acquire lock - another worker is already refreshing cache")
    end
    
  rescue => e
    AppLogger.info("❌ [CACHE WORKER] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry mechanism
  end
  
  private
  
  def get_cache
    # Access MEME_CACHE from MemeExplorer::App class
    if defined?(MemeExplorer::App::MEME_CACHE)
      MemeExplorer::App::MEME_CACHE
    else
    AppLogger.info("❌ [CACHE WORKER] MEME_CACHE not available")
      nil
    end
  end
  
  def fetch_with_reddit_service
    # OPTIMIZED: Fetch MORE memes by using all popular subreddits
    client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
    client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
    
    # Load ALL popular subreddits (don't sample yet - let RedditFetcherService handle it)
    all_subreddits = YAML.load_file("data/subreddits.yml", aliases: true)["popular"]
    
    if !client_id.empty? && !client_secret.empty?
      # Use RedditFetcherService with OAuth - HIGHER LIMIT for more memes
      require 'oauth2'
      begin
        client = OAuth2::Client.new(
          client_id,
          client_secret,
          site: "https://www.reddit.com",
          authorize_url: "/api/v1/authorize",
          token_url: "/api/v1/access_token"
        )
        
        token = client.client_credentials.get_token(scope: "read")
    AppLogger.info("   Using OAuth authentication (fetching from #{all_subreddits.size} subreddits)")
        
        # OPTIMIZATION: Increase limit to 50 per subreddit (from 30)
        # With 12 subreddits = up to 600 memes!
        fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: token.token)
        return fetcher.fetch_memes(all_subreddits, limit: 50)
      rescue => e
    AppLogger.info("⚠️ OAuth failed: #{e.message}, falling back to static")
      end
    end
    
    # Fallback to static (unauthenticated)
    AppLogger.info("   Using unauthenticated fetching (fetching from #{all_subreddits.size} subreddits)")
    
    # OPTIMIZATION: Increase limit to 50 per subreddit
    # With 25 subreddits = up to 1,250 memes!
    fetcher = RedditFetcherService.new(auth_strategy: :static)
    fetcher.fetch_memes(all_subreddits, limit: 50)
  rescue => e
    AppLogger.info("❌ Reddit fetch error: #{e.message}")
    []
  end
  
  def load_local_memes
    yaml_data = YAML.load_file("data/memes.yml", aliases: true)
    if yaml_data.is_a?(Hash)
      yaml_data.values.flatten.compact
    else
      yaml_data || []
    end
  rescue => e
    AppLogger.info("❌ Failed to load local memes: #{e.message}")
    []
  end
end
