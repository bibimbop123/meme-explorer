class CacheRefreshWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 3, backtrace: true
  
  def perform
    puts "🔄 [CACHE WORKER] Starting cache refresh at #{Time.now}"
    
    # Get MEME_CACHE from MemeExplorer namespace
    cache = get_cache
    return unless cache
    
    # Load local memes as fallback
    local_memes = load_local_memes
    puts "✅ [CACHE WORKER] Loaded #{local_memes.size} local memes"
    
    # Use RedditFetcherService for fetching
    api_memes = fetch_with_reddit_service
    puts "✅ [CACHE WORKER] Fetched #{api_memes.size} API memes"
    
    # PREVENTION: Filter out blacklisted URLs and validate before caching
    validated = api_memes.select { |m| m["url"] && m["url"].to_s.strip.length > 0 }
    
    # Remove blacklisted memes (instant check)
    if defined?(ImageHealthService)
      before_blacklist = validated.size
      validated = ImageHealthService.filter_blacklisted(validated)
      blacklisted_count = before_blacklist - validated.size
      puts "🚫 [CACHE WORKER] Filtered #{blacklisted_count} blacklisted memes" if blacklisted_count > 0
    end
    
    # Validate remaining memes (prevent broken content from entering cache)
    if defined?(ImageValidationService) && validated.size > 0
      puts "🔍 [CACHE WORKER] Validating #{validated.size} memes..."
      validation_start = Time.now
      
      validated_memes = validated.select.with_index do |meme, index|
        url = meme["url"]
        is_valid = ImageValidationService.validate(url)
        
        # Log progress every 20 memes
        if (index + 1) % 20 == 0
          puts "   Progress: #{index + 1}/#{validated.size} validated"
        end
        
        is_valid
      end
      
      validation_duration = (Time.now - validation_start).round(2)
      rejected = validated.size - validated_memes.size
      validated = validated_memes
      
      puts "✅ [CACHE WORKER] Validation complete in #{validation_duration}s: #{validated.size} valid, #{rejected} rejected"
    end
    
    if validated.empty?
      cache.set(:memes, local_memes.shuffle)
      puts "⚠️ [CACHE WORKER] No valid API memes - using local only"
    else
      all_memes = (validated + local_memes).uniq { |m| m["url"] || m["file"] }
      cache.set(:memes, all_memes.shuffle)
      puts "✅ [CACHE WORKER] Cache updated: #{validated.size} API + #{local_memes.size} local = #{all_memes.size} total"
    end
    
    cache.set(:last_refresh, Time.now)
    puts "✅ [CACHE WORKER] Cache refresh complete"
    
  rescue => e
    puts "❌ [CACHE WORKER] Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry mechanism
  end
  
  private
  
  def get_cache
    # Access MEME_CACHE from MemeExplorer::App class
    if defined?(MemeExplorer::App::MEME_CACHE)
      MemeExplorer::App::MEME_CACHE
    else
      puts "❌ [CACHE WORKER] MEME_CACHE not available"
      nil
    end
  end
  
  def fetch_with_reddit_service
    # OPTIMIZED: Fetch MORE memes by using all popular subreddits
    client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
    client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
    
    # Load ALL popular subreddits (don't sample yet - let RedditFetcherService handle it)
    all_subreddits = YAML.load_file("data/subreddits.yml")["popular"]
    
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
        puts "   Using OAuth authentication (fetching from #{all_subreddits.size} subreddits)"
        
        # OPTIMIZATION: Increase limit to 50 per subreddit (from 30)
        # With 12 subreddits = up to 600 memes!
        fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: token.token)
        return fetcher.fetch_memes(all_subreddits, limit: 50)
      rescue => e
        puts "⚠️ OAuth failed: #{e.message}, falling back to static"
      end
    end
    
    # Fallback to static (unauthenticated)
    puts "   Using unauthenticated fetching (fetching from #{all_subreddits.size} subreddits)"
    
    # OPTIMIZATION: Increase limit to 50 per subreddit
    # With 25 subreddits = up to 1,250 memes!
    fetcher = RedditFetcherService.new(auth_strategy: :static)
    fetcher.fetch_memes(all_subreddits, limit: 50)
  rescue => e
    puts "❌ Reddit fetch error: #{e.message}"
    []
  end
  
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
end
