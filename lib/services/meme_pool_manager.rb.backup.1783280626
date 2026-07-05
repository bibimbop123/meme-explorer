# Meme Pool Manager - Phase 2
# Intelligent 5,000-meme pool management with tier-based distribution
# Created: June 3, 2026

require 'concurrent'
require_relative 'reddit_fetcher_service'
require_relative 'turbocharged_reddit_fetcher'
require_relative 'quality_pipeline_service'
require_relative 'redis_service'
require 'yaml'

class MemePoolManager
  TARGET_POOL_SIZE = 5000
  MIN_POOL_SIZE = 1000
  
  # Tier distribution for balanced variety
  TIER_DISTRIBUTION = {
    tier_1: 0.60,  # 3,000 memes - Peak Humor & Relationships
    tier_2: 0.20,  # 1,000 memes - Viral Humor
    tier_3: 0.10,  # 500 memes - Specific Niches
    tier_4: 0.05,  # 250 memes - Visual Comedy
    tier_5: 0.05   # 250 memes - Wholesome
  }.freeze
  
  class << self
    # Main entry point - maintains pool at target size
    def maintain_pool!
      AppLogger.info("🔄 [PoolManager] Starting pool maintenance...")
      current_size = get_pool_size
      
      if current_size < MIN_POOL_SIZE
        AppLogger.warn("⚠️  [PoolManager] Pool below minimum (#{current_size} < #{MIN_POOL_SIZE})")
        fetch_batch(size: 1000, priority: :high)
      elsif current_size < TARGET_POOL_SIZE
        needed = TARGET_POOL_SIZE - current_size
        AppLogger.info("📊 [PoolManager] Pool at #{current_size}/#{TARGET_POOL_SIZE}, fetching #{needed} memes")
        fetch_batch(size: needed)
      else
        AppLogger.info("✅ [PoolManager] Pool at target size (#{current_size}), replacing stale content")
        replace_stale(percentage: 0.2)
      end
      
      final_size = get_pool_size
      AppLogger.info("✅ [PoolManager] Maintenance complete: #{final_size} memes in pool")
      { success: true, pool_size: final_size }
    rescue => e
      log_error("Pool maintenance error", e)
      { success: false, error: e.message }
    end
    
    # Get current pool (main entry point for app.rb)
    # HYBRID: Quick bootstrap on first call, then scale via Sidekiq
    # Check pool capacity and trigger proactive refresh if below threshold
def check_and_refresh_if_low(current_size)
  return if current_size >= 300 # Above comfortable level (50% = 250 memes)

  capacity_percent = (current_size.to_f / 500) * 100
  
  if capacity_percent <= LOW_THRESHOLD_PERCENT # Triggers at 250 memes (50%)
    AppLogger.info("📊 [PoolManager] Pool at #{capacity_percent.round}% capacity (#{current_size} memes) - triggering proactive refresh")
    trigger_background_expansion
  end
rescue => e
  AppLogger.error("⚠️  [PoolManager] Proactive refresh check failed: #{e.message}")
end

    def get_pool
      pool = get_current_pool
      size = pool.size
      
      # If pool exists, return it
      if size > 0
        return {
          success: true,
          memes: pool,
          pool_size: size,
          error: nil
        }
      end
      
      # Pool empty - bootstrap with small quick fetch
      AppLogger.warn("⚠️  [PoolManager] Pool empty, bootstrapping with 500 memes...")
      bootstrap_result = bootstrap_pool
      
      if bootstrap_result[:success]
        AppLogger.info("✅ [Pool] Using MemePoolManager: #{bootstrap_result[:size]} memes (tier-distributed)")
        # Trigger background expansion to 5K (non-blocking)
        trigger_background_expansion
        
        # Return memes directly from bootstrap (avoid Redis re-fetch)
        return {
          success: true,
          memes: bootstrap_result[:memes],
          pool_size: bootstrap_result[:size],
          error: nil
        }
      else
        AppLogger.error("⚠️  [PoolManager] Bootstrap failed: #{bootstrap_result[:error]}")
        return {
          success: false,
          memes: [],
          pool_size: 0,
          error: "Bootstrap failed, using local fallback"
        }
      end
    rescue => e
      log_error("Get pool error", e)
      { success: false, memes: [], pool_size: 0, error: e.message }
    end
    
    # Bootstrap pool with quick 500-meme fetch (20-30 seconds)
    def bootstrap_pool
  AppLogger.info("🚀 [Bootstrap] AGGRESSIVE fetch from ALL 5 tiers for variety...")
  
  # CRITICAL FIX: Fetch from ALL tiers, not just 1-2 (July 5, 2026)
  # This increases pool from 40 → 400-600 memes
  tier_1_subs = load_tier_subreddits(:tier_1).first(30)  # 30 tier 1
  tier_2_subs = load_tier_subreddits(:tier_2).first(20)  # 20 tier 2
  tier_3_subs = load_tier_subreddits(:tier_3).first(15)  # 15 tier 3
  tier_4_subs = load_tier_subreddits(:tier_4).first(10)  # 10 tier 4
  tier_5_subs = load_tier_subreddits(:tier_5).first(5)   # 5 tier 5
  
  all_subs = tier_1_subs + tier_2_subs + tier_3_subs + tier_4_subs + tier_5_subs
  # Now 80 subreddits * 25 per sub = 2,000 potential memes
  
  fetcher = create_fetcher
  memes = fetcher.fetch_memes(all_subs, limit: 20)  # 240 subs * 20 = 4,800 potential
  # 20 per subreddit = ~600 total
      
      # SKIP quality filter on bootstrap for speed (basic validation only)
      validated = memes.select { |m| m["url"] && m["title"] && m["subreddit"] }
      stored = store_in_pool(validated)
      
      AppLogger.info("📊 [Bootstrap] Fetched: #{memes.size}, Validated: #{validated.size}, Stored: #{stored}")
      
      # Return memes directly (don't re-fetch from Redis)
      { success: stored > 0, size: stored, memes: validated, error: stored == 0 ? "No memes passed validation" : nil }
    rescue => e
      log_error("Bootstrap error", e)
      { success: false, size: 0, memes: [], error: e.message }
    end
    
    # Trigger background expansion to full 5K pool
    def trigger_background_expansion
      if defined?(MemePoolMaintenanceWorker)
        MemePoolMaintenanceWorker.perform_async
        AppLogger.info("✅ [PoolManager] Triggered background expansion to 5,000 memes")
      else
        AppLogger.debug("ℹ️  [PoolManager] Sidekiq unavailable, pool will stay at bootstrap size")
      end
    end
    
    # Build pool from scratch
    def build_pool!
      AppLogger.info("🔨 [PoolManager] Building pool from scratch...")
      fetch_batch(size: TARGET_POOL_SIZE, priority: :high)
    end
    
    # Fetch a batch of memes with tier-based distribution
    def fetch_batch(size:, priority: :normal)
      AppLogger.info("📥 [PoolManager] Fetching batch of #{size} memes (priority: #{priority})")
      
      # Calculate tier distribution
      tier_counts = TIER_DISTRIBUTION.map do |tier, percentage|
        [tier, (size * percentage).to_i]
      end.to_h
      
      # Parallel fetch from all tiers using Concurrent::Future (bounded, no raw Thread.new)
      futures = tier_counts.map do |tier, count|
        Concurrent::Future.execute { fetch_from_tier(tier, count) }
      end

      # Collect results with a per-tier timeout — never blocks forever
      all_memes = futures.flat_map { |f| f.value(30) || [] }
      AppLogger.info("📦 [PoolManager] Fetched #{all_memes.size} memes total")
      
      # Apply quality pipeline
      validated_memes = quality_filter(all_memes)
      AppLogger.info("✅ [PoolManager] #{validated_memes.size} memes passed quality filter")
      
      # Store in pool
      stored_count = store_in_pool(validated_memes)
      AppLogger.info("💾 [PoolManager] Stored #{stored_count} memes in pool")
      
      { fetched: all_memes.size, validated: validated_memes.size, stored: stored_count }
    rescue => e
      log_error("Fetch batch error", e)
      { fetched: 0, validated: 0, stored: 0, error: e.message }
    end
    
    # Replace stale memes with fresh content
    def replace_stale(percentage: 0.2)
      current_pool = get_current_pool
      stale_count = (current_pool.size * percentage).to_i
      
      AppLogger.info("🔄 [PoolManager] Replacing #{stale_count} stale memes (#{(percentage * 100).to_i}%)")
      
      # Find oldest memes
      stale_urls = find_stale_memes(current_pool, stale_count)
      
      # Remove stale memes
      remove_from_pool(stale_urls)
      
      # Fetch fresh replacements
      fetch_batch(size: stale_count)
      
      { replaced: stale_count }
    rescue => e
      log_error("Replace stale error", e)
      { replaced: 0, error: e.message }
    end
    
    private
    
    # Fetch memes from a specific tier
    def fetch_from_tier(tier, count)
      AppLogger.info("  📍 [PoolManager] Fetching #{count} memes from #{tier}")
      
      subreddits = load_tier_subreddits(tier)
      return [] if subreddits.empty?
      
      # Calculate memes per subreddit
      memes_per_sub = [count / subreddits.size, 1].max
      
      # Use Reddit Fetcher Service
      fetcher = create_fetcher
      memes = fetcher.fetch_memes(subreddits, limit: memes_per_sub)
      
      AppLogger.info("  ✅ [PoolManager] Got #{memes.size} memes from #{tier}")
      memes
    rescue => e
      log_error("Fetch from tier #{tier} error", e)
      []
    end
    
    # Apply quality pipeline to filter memes
    def quality_filter(memes)
      return [] if memes.empty?
      
      if defined?(QualityPipelineService)
        memes.select { |meme| QualityPipelineService.passes_all_gates?(meme) }
      else
        # Basic filtering if pipeline not available
        memes.select do |meme|
          meme["url"] && meme["title"] && meme["subreddit"]
        end
      end
    rescue => e
      log_error("Quality filter error", e)
      memes # Return unfiltered on error
    end
    
    # Store memes in Redis pool
    def store_in_pool(memes)
      return 0 if memes.empty?
      
      # Get current pool
      current_pool = get_current_pool
      
      # Add new memes (avoid duplicates by URL)
      existing_urls = current_pool.map { |m| m["url"] }.to_set
      new_memes = memes.reject { |m| existing_urls.include?(m["url"]) }
      
      # Update pool
      updated_pool = current_pool + new_memes
      
      # Store in Redis
      RedisService.set('meme_pool', updated_pool.to_json)
      RedisService.set('meme_pool:count', updated_pool.size)
      RedisService.set('meme_pool:updated_at', Time.now.to_s)
      
      new_memes.size
    rescue => e
      log_error("Store in pool error", e)
      0
    end
    
    # Get current pool size
    # Check pool capacity and trigger proactive refresh if below threshold
def check_and_refresh_if_low(current_size)
  return if current_size >= 300 # Above comfortable level (50% = 250 memes)

  capacity_percent = (current_size.to_f / 500) * 100
  
  if capacity_percent <= LOW_THRESHOLD_PERCENT # Triggers at 250 memes (50%)
    AppLogger.info("📊 [PoolManager] Pool at #{capacity_percent.round}% capacity (#{current_size} memes) - triggering proactive refresh")
    trigger_background_expansion
  end
rescue => e
  AppLogger.error("⚠️  [PoolManager] Proactive refresh check failed: #{e.message}")
end

    def get_pool_size
      cached_count = RedisService.get('meme_pool:count')
      return cached_count.to_i if cached_count
      
      pool = get_current_pool
      pool.size
    rescue => e
      log_error("Get pool size error", e)
      0
    end
    
    # Get current pool from Redis
    def get_current_pool
      cached = RedisService.get('meme_pool')
      return JSON.parse(cached) if cached
      
      []
    rescue => e
      log_error("Get current pool error", e)
      []
    end
    
    # Find stale memes (oldest by timestamp)
    def find_stale_memes(pool, count)
      return [] if pool.empty?
      
      # Sort by created_at or fetched_at (oldest first)
      sorted = pool.sort_by do |meme|
        timestamp = meme["fetched_at"] || meme["created_at"] || Time.now.to_s
        Time.parse(timestamp) rescue Time.now
      end
      
      # Take oldest N memes
      sorted.first(count).map { |m| m["url"] }
    rescue => e
      log_error("Find stale memes error", e)
      []
    end
    
    # Remove memes from pool by URL
    def remove_from_pool(urls)
      return 0 if urls.empty?
      
      pool = get_current_pool
      original_size = pool.size
      
      # Filter out URLs to remove
      updated_pool = pool.reject { |m| urls.include?(m["url"]) }
      
      # Update Redis
      RedisService.set('meme_pool', updated_pool.to_json)
      RedisService.set('meme_pool:count', updated_pool.size)
      
      original_size - updated_pool.size
    rescue => e
      log_error("Remove from pool error", e)
      0
    end
    
    # Load subreddits for a specific tier
    def load_tier_subreddits(tier)
      data = YAML.load_file('data/subreddits.yml', aliases: true)
      data[tier.to_s] || []
    rescue => e
      log_error("Load tier subreddits error for #{tier}", e)
      []
    end
    
    # Create Reddit fetcher with appropriate auth
    # USE TURBOCHARGED FETCHER FOR 5-10x PERFORMANCE BOOST
    def create_fetcher(use_turbo: true)
      client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
      client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
      
      fetcher_class = use_turbo ? TurbochargedRedditFetcher : RedditFetcherService
      
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
        fetcher_class.new(auth_strategy: :oauth, access_token: token.token)
      else
        fetcher_class.new(auth_strategy: :static)
      end
    rescue => e
      log_error("Create fetcher error", e)
      fetcher_class.new(auth_strategy: :static)
    end
    
    # Centralized error logging
    def log_error(context, error)
      message = error.is_a?(String) ? error : error.message
      AppLogger.warn("⚠️  [PoolManager] #{context}: #{message}")
      
      if defined?(Sentry) && error.is_a?(Exception)
        Sentry.capture_exception(error, extra: { context: context })
      end
    end
  end
end
