# Similar Meme Cache - Phase 1
# Instant "More Like This" with pre-fetched similar memes
# Created: June 3, 2026

require_relative 'redis_service'
require_relative 'meme_service'
require 'yaml'

class SimilarMemeCache
  CACHE_TTL = 600  # 10 minutes
  
  class << self
    # Get similar memes from cache or fetch
    def get_similar(subreddit)
      return [] unless subreddit
      
      key = "similar:#{subreddit.downcase}"
      cached = RedisService.get(key)
      return JSON.parse(cached) if cached
      
      # Cache miss - fetch and cache
      fetch_and_cache(subreddit)
    rescue => e
      log_error("Get similar memes error for r/#{subreddit}", e)
      []
    end
    
    # Prefetch all popular subreddits for instant response
    def prefetch_all_popular!
      AppLogger.info("🔄 [SimilarMemeCache] Starting prefetch for popular subreddits...")
      
      subreddit_data = YAML.load_file('data/subreddits.yml', aliases: true)
      popular = subreddit_data['tier_1'] || []
      
      prefetched = 0
      failed = 0
      
      popular.each do |subreddit|
        begin
          memes = fetch_and_cache(subreddit)
          if memes && memes.any?
            prefetched += 1
            AppLogger.info("  ✅ Cached #{memes.size} memes for r/#{subreddit}")
          else
            failed += 1
            AppLogger.warn("  ⚠️  No memes found for r/#{subreddit}")
          end
          
          sleep 0.5 # Rate limiting
        rescue => e
          failed += 1
          log_error("Prefetch error for r/#{subreddit}", e)
        end
      end
      
      AppLogger.error("✅ [SimilarMemeCache] Prefetch complete: #{prefetched} success, #{failed} failed")
      { prefetched: prefetched, failed: failed }
    rescue => e
      log_error("Prefetch all error", e)
      { prefetched: 0, failed: 0, error: e.message }
    end
    
    # Clear all similar meme caches
    def clear_all!
      pattern = "similar:*"
      keys = RedisService.keys(pattern)
      
      return 0 if keys.empty?
      
      keys.each { |key| RedisService.del(key) }
      keys.size
    rescue => e
      log_error("Clear all error", e)
      0
    end
    
    private
    
    # Fetch similar memes and cache them
    def fetch_and_cache(subreddit)
      # Get memes from the subreddit
      memes = fetch_from_subreddit(subreddit)
      
      return [] if memes.empty?
      
      # Filter with quality pipeline if available
      if defined?(QualityPipelineService)
        memes = memes.select { |m| QualityPipelineService.passes_all_gates?(m) }
      end
      
      # Cache the results
      key = "similar:#{subreddit.downcase}"
      RedisService.setex(key, CACHE_TTL, memes.to_json)
      
      memes
    rescue => e
      log_error("Fetch and cache error for r/#{subreddit}", e)
      []
    end
    
    # Fetch memes from a specific subreddit
    def fetch_from_subreddit(subreddit)
      # Try to get from main meme pool first
      if defined?(MemeService)
        pool_memes = MemeService.random_memes_pool(subreddit: subreddit, limit: 50)
        return pool_memes if pool_memes && pool_memes.any?
      end
      
      # Fallback: fetch directly from Reddit
      fetch_from_reddit(subreddit)
    rescue => e
      log_error("Fetch from subreddit error for r/#{subreddit}", e)
      []
    end
    
    # Direct fetch from Reddit API
    def fetch_from_reddit(subreddit)
      require_relative 'reddit_fetcher_service'
      
      # Try OAuth first
      client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
      client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
      
      if !client_id.empty? && !client_secret.empty?
        require 'oauth2'
        
        client = OAuth2::Client.new(
          client_id,
          client_secret,
          site: "https://www.reddit.com",
          authorize_url: "/api/v1/authorize",
          token_url: "/api/v1/access_token"
        )
        
        token = client.client_credentials.get_token(scope: "read")
        fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: token.token)
        return fetcher.fetch_memes([subreddit], limit: 50)
      end
      
      # Fallback to static
      fetcher = RedditFetcherService.new(auth_strategy: :static)
      fetcher.fetch_memes([subreddit], limit: 50)
    rescue => e
      log_error("Fetch from Reddit error for r/#{subreddit}", e)
      []
    end
    
    # Centralized error logging
    def log_error(context, error)
      message = error.is_a?(String) ? error : error.message
      AppLogger.warn("⚠️  [SimilarMemeCache] #{context}: #{message}")
      
      if defined?(Sentry) && error.is_a?(Exception)
        Sentry.capture_exception(error, extra: { context: context })
      end
    end
  end
end
