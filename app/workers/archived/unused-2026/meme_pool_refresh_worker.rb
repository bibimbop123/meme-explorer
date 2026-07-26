# Meme Pool Refresh Worker
# Replaces inline Thread.new with proper background job
# Generated: May 19, 2026

class MemePoolRefreshWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 3
  
  def perform(force_refresh = false)
    logger.info "🔄 Starting meme pool refresh (force: #{force_refresh})"
    
    start_time = Time.now
    
    begin
      # Check if refresh is needed
      unless force_refresh || refresh_needed?
        logger.info "✅ Pool refresh not needed"
        return
      end
      
      # FIXED July 13, 2026: Use MemePoolManager.maintain_pool! instead of manual fetching
      # This ensures proper tier categorization and dual-format storage
      logger.info "📊 Delegating to MemePoolManager for proper pool maintenance..."
      
      result = MemePoolManager.maintain_pool!
      
      if result[:success]
        duration = (Time.now - start_time).round(2)
        logger.info "✅ Pool refreshed successfully: #{result[:pool_size]} memes in #{duration}s"
        
        # Update old cache for backward compatibility
        pool = MemePoolManager.get_pool
        if pool[:success]
          MEME_CACHE.set(:memes, pool[:memes])
          MEME_CACHE.set(:last_refresh, Time.now)
        end
        MEME_CACHE.set(:refreshing, false)
        
        # Track metrics
        track_refresh_metrics(result[:pool_size], duration)
      else
        logger.error "❌ Pool maintenance failed: #{result[:error]}"
        MEME_CACHE.set(:refreshing, false)
        raise StandardError, "Pool maintenance failed: #{result[:error]}"
      end
      
    rescue => e
      logger.error "❌ Pool refresh failed: #{e.message}"
      logger.error e.backtrace.first(5).join("\n")
      
      MEME_CACHE.set(:refreshing, false)
      
      # Report to Sentry
      Sentry.capture_exception(e) if defined?(Sentry)
      
      raise # Re-raise for Sidekiq retry
    end
  end
  
  private
  
  def refresh_needed?
    last_refresh = MEME_CACHE.get(:last_refresh)
    return true unless last_refresh
    
    pool = MEME_CACHE.get(:memes)
    return true unless pool
    return true if pool.size < 10
    
    age_minutes = (Time.now - last_refresh) / 60
    age_minutes > 60 # Refresh if older than 1 hour
  end
  
  def get_reddit_token
    # Try to get OAuth token
    token_data = MEME_CACHE.get(:reddit_token)
    return token_data["access_token"] if token_data && token_data["access_token"]
    
    # Try to fetch new token
    begin
      response = HTTParty.post(
        "https://www.reddit.com/api/v1/access_token",
        basic_auth: {
          username: ENV['REDDIT_CLIENT_ID'],
          password: ENV['REDDIT_CLIENT_SECRET']
        },
        body: { grant_type: 'client_credentials' },
        headers: { 'User-Agent' => 'MemeExplorer/1.0' }
      )
      
      if response.success?
        MEME_CACHE.set(:reddit_token, response.parsed_response)
        return response.parsed_response["access_token"]
      end
    rescue => e
      logger.warn "Could not get OAuth token: #{e.message}"
    end
    
    nil # Fall back to static fetch
  end
  
  def load_subreddits
    # Load from YAML or use defaults
    if File.exist?('data/subreddits.yml')
      YAML.load_file('data/subreddits.yml', aliases: true)['subreddits'] || []
    else
      %w[memes dankmemes me_irl funny wholesomememes]
    end
  end
  
  def fetch_db_memes(limit)
    query = "
      SELECT url, title, subreddit, likes, views
      FROM meme_stats
      WHERE (failure_count IS NULL OR failure_count < 3)
        AND updated_at >= datetime('now', '-7 days')
      ORDER BY likes DESC, views DESC
      LIMIT ?
    "
    
    DB.execute(query, [limit])
  end
  
  def track_refresh_metrics(meme_count, duration)
    # Store metrics for monitoring
    metrics = {
      timestamp: Time.now.to_i,
      meme_count: meme_count,
      duration_seconds: duration,
      success: true
    }
    
    MEME_CACHE.set(:last_refresh_metrics, metrics)
  end
end
