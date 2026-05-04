require 'redis'
require 'json'
require 'oauth2'
require 'httparty'
require 'timeout'
require 'net/http'
require 'uri'

class ApiCacheService
  CACHE_TTL = 1800
  LOCK_TTL = 30
  FETCH_TIMEOUT = 45
  
  # QUALITY FILTERS - Higher quality memes only
  MIN_UPVOTES = 50          # Minimum upvotes to be considered
  MIN_UPVOTE_RATIO = 0.7    # Upvote ratio threshold (70%+)
  MIN_COMMENTS = 5          # Minimum engagement
  PREFERRED_MIN_UPVOTES = 200  # Bonus for high-quality memes

  # Thread-safe in-memory cache
  @@memory_cache = {}
  @@memory_lock = Mutex.new

  class << self
    def redis
      @redis ||= begin
        begin
          url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
          return nil if url.empty?
          r = Redis.new(url: url)
          r.ping
          r
        rescue
          nil
        end
      end
    end

    def memory_cache
      @@memory_cache
    end

    def memory_lock
      @@memory_lock
    end

    # Get cached memes from Redis or memory
    def get_cached_memes
      # Try Redis first
      if redis
        begin
          cached = redis.get('cache:api_memes:latest')
          if cached
            memes = JSON.parse(cached)
            return memes if memes.is_a?(Array) && !memes.empty?
          end
        rescue
          # Fall through to memory cache
        end
      end

      # Fall back to memory cache
      memory_lock.synchronize do
        cached = memory_cache['api_memes:latest']
        return cached if cached.is_a?(Array) && !cached.empty?
      end

      nil
    end

    # Set cached memes in both Redis and memory
    def set_cached_memes(memes)
      return false unless memes.is_a?(Array) && !memes.empty?

      success = false

      # Try Redis first
      if redis
        begin
          redis.setex('cache:api_memes:latest', CACHE_TTL, memes.to_json)
          redis.setex('cache:api_memes:timestamp', CACHE_TTL, Time.now.to_i.to_s)
          success = true
        rescue
          # Continue to memory cache
        end
      end

      # Always store in memory cache as backup
      memory_lock.synchronize do
        memory_cache['api_memes:latest'] = memes
        memory_cache['api_memes:timestamp'] = Time.now.to_i
      end

      true
    end

    def cache_age
      if redis
        begin
          timestamp_str = redis.get('cache:api_memes:timestamp')
          return Time.now.to_i - timestamp_str.to_i if timestamp_str
        rescue
          # Fall through
        end
      end

      memory_lock.synchronize do
        timestamp = memory_cache['api_memes:timestamp']
        return Time.now.to_i - timestamp if timestamp
      end

      nil
    end

    def cache_fresh?
      age = cache_age
      age && age < 1500
    end

    def acquire_lock
      if redis
        begin
          return redis.set('cache:api_memes:lock', Time.now.to_i.to_s, nx: true, ex: LOCK_TTL).present?
        rescue
          # Fall through to memory lock
        end
      end

      memory_lock.synchronize do
        lock_time = memory_cache['api_memes:lock']
        if lock_time.nil? || (Time.now.to_i - lock_time.to_i) > LOCK_TTL
          memory_cache['api_memes:lock'] = Time.now.to_i
          return true
        end
      end

      false
    end

    def release_lock
      redis&.del('cache:api_memes:lock')
      memory_lock.synchronize do
        memory_cache.delete('api_memes:lock')
      end
    end

    def fetch_and_cache_memes(popular_subreddits)
      # Check if cache is fresh
      if cache_fresh?
        cached = get_cached_memes
        return cached if cached && !cached.empty?
      end

      # Another process is fetching, return cached
      return get_cached_memes || [] unless acquire_lock

      begin
        api_memes = []

        # IMPROVED: Fetch from MORE subreddits with HIGHER quality
        # Try unauthenticated fetch first (faster)
        begin
          Timeout.timeout(FETCH_TIMEOUT) do
            # IMPROVEMENT 1: Fetch from 15 subreddits instead of 8 for more variety
            subreddits_sample = popular_subreddits.sample([15, popular_subreddits.size].min)
            # IMPROVEMENT 2: Fetch 100 posts per subreddit to get better selection after filtering
            api_memes = fetch_reddit_memes_unauthenticated(subreddits_sample, 100)
            puts "[CACHE] Unauthenticated fetch: #{api_memes.size} memes"
          end
        rescue Timeout::Error
          puts "[CACHE] Timeout on unauthenticated fetch"
        rescue => e
          puts "[CACHE] Error on unauthenticated fetch: #{e.message}"
        end

        # If unauthenticated failed, try authenticated
        if api_memes.empty?
          client_id = ENV.fetch('REDDIT_CLIENT_ID', '').to_s.strip
          client_secret = ENV.fetch('REDDIT_CLIENT_SECRET', '').to_s.strip

          if !client_id.empty? && !client_secret.empty?
            begin
              Timeout.timeout(FETCH_TIMEOUT) do
                client = OAuth2::Client.new(
                  client_id,
                  client_secret,
                  site: 'https://www.reddit.com',
                  authorize_url: '/api/v1/authorize',
                  token_url: '/api/v1/access_token'
                )
                token = client.client_credentials.get_token(scope: 'read')
                subreddits_sample = popular_subreddits.sample([15, popular_subreddits.size].min)
                api_memes = fetch_reddit_memes_authenticated(token.token, subreddits_sample, 100)
                puts "[CACHE] Authenticated fetch: #{api_memes.size} memes"
              end
            rescue Timeout::Error
              puts "[CACHE] Timeout on authenticated fetch"
            rescue => e
              puts "[CACHE] Error on authenticated fetch: #{e.message}"
            end
          end
        end

        # IMPROVEMENT 3: Validate, filter quality, and sort by engagement
        if api_memes && !api_memes.empty?
          validated = validate_and_filter_quality_memes(api_memes)
          if !validated.empty?
            set_cached_memes(validated)
            puts "[CACHE] Cached #{validated.size} high-quality memes"
            return validated
          end
        end

        puts "[CACHE] No API memes fetched, using existing cache"
        get_cached_memes || []
      ensure
        release_lock
      end
    end

    private

    def fetch_reddit_memes_authenticated(token, subreddits, limit)
      memes = []
      subreddits.each do |subreddit|
        begin
          # IMPROVEMENT 4: Fetch from both HOT and TOP for variety
          ['hot', 'top'].each do |sort_type|
            url = if sort_type == 'top'
                    "https://oauth.reddit.com/r/#{subreddit}/top?t=week&limit=#{limit / 2}"
                  else
                    "https://oauth.reddit.com/r/#{subreddit}/hot?limit=#{limit / 2}"
                  end
                  
            response = HTTParty.get(
              url,
              headers: {
                'Authorization' => "Bearer #{token}",
                'User-Agent' => 'MemeExplorer/1.0'
              },
              timeout: 15
            )
            
            if response.success?
              (response.parsed_response.dig('data', 'children') || []).each do |post|
                post_data = post['data']
                
                # IMPROVEMENT 5: Quality filtering - skip low-quality posts
                upvotes = post_data['ups'] || 0
                next if upvotes < MIN_UPVOTES
                
                # Check upvote ratio
                upvote_ratio = post_data['upvote_ratio'] || 0
                next if upvote_ratio < MIN_UPVOTE_RATIO
                
                # Check engagement (comments)
                num_comments = post_data['num_comments'] || 0
                next if num_comments < MIN_COMMENTS

                # IMPROVEMENT 6: Support videos (reddit hosted only, no external)
                is_reddit_video = post_data['is_video'] && post_data.dig('media', 'reddit_video')
                
                image_url = if is_reddit_video
                              post_data.dig('media', 'reddit_video', 'fallback_url') # Video thumbnail/fallback
                            else
                              extract_image_url(post_data)
                            end
                            
                next unless image_url

                memes << {
                  'title' => post_data['title'],
                  'url' => image_url,
                  'subreddit' => post_data['subreddit'],
                  'likes' => upvotes,
                  'comments' => num_comments,
                  'upvote_ratio' => upvote_ratio,
                  'is_video' => is_reddit_video ? true : false,
                  'quality_score' => calculate_quality_score(upvotes, num_comments, upvote_ratio)
                }
              end
            end
            sleep 0.3 # Reduced sleep for faster fetching
          end
        rescue => e
          puts "[FETCH] Error from r/#{subreddit}: #{e.class}"
        end
      end
      memes
    end

    def fetch_reddit_memes_unauthenticated(subreddits, limit)
      memes = []
      user_agents = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
      ]

      subreddits.each do |subreddit|
        begin
          # IMPROVEMENT 7: Fetch from both HOT and TOP
          ['hot', 'top'].each do |sort_type|
            url = if sort_type == 'top'
                    "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit / 2}"
                  else
                    "https://www.reddit.com/r/#{subreddit}/hot.json?limit=#{limit / 2}"
                  end
                  
            uri = URI(url)

            response = Net::HTTP.start(
              uri.host,
              uri.port,
              use_ssl: true,
              read_timeout: 10,
              open_timeout: 10
            ) do |http|
              request = Net::HTTP::Get.new(uri.request_uri)
              request['User-Agent'] = user_agents.sample
              http.request(request)
            end

            if response.code == '200'
              data = JSON.parse(response.body)
              (data.dig('data', 'children') || []).each do |post|
                post_data = post['data']
                
                # QUALITY FILTERING
                upvotes = post_data['ups'] || 0
                next if upvotes < MIN_UPVOTES
                
                upvote_ratio = post_data['upvote_ratio'] || 0
                next if upvote_ratio < MIN_UPVOTE_RATIO
                
                num_comments = post_data['num_comments'] || 0
                next if num_comments < MIN_COMMENTS

                # Support reddit videos
                is_reddit_video = post_data['is_video'] && post_data.dig('media', 'reddit_video')
                
                image_url = if is_reddit_video
                              post_data.dig('media', 'reddit_video', 'fallback_url')
                            else
                              extract_image_url(post_data)
                            end
                            
                next unless image_url

                memes << {
                  'title' => post_data['title'],
                  'url' => image_url,
                  'subreddit' => post_data['subreddit'],
                  'likes' => upvotes,
                  'comments' => num_comments,
                  'upvote_ratio' => upvote_ratio,
                  'is_video' => is_reddit_video ? true : false,
                  'quality_score' => calculate_quality_score(upvotes, num_comments, upvote_ratio)
                }
              end
            end
            sleep 0.3
          end
        rescue => e
          puts "[FETCH] Error from r/#{subreddit}: #{e.class}"
        end
      end
      memes
    end

    def extract_image_url(post_data)
      # Try direct image URL
      if post_data['url']
        url = post_data['url']
        
        # CRITICAL: Reject subreddit URLs (e.g., /r/SubredditName/)
        return nil if url.match?(/^\/r\/[^\/]+\/?$/)
        return nil if url.match?(/reddit\.com\/r\/[^\/]+\/?$/)
        
        # Accept only actual image URLs
        if url.match?(/\.(jpg|jpeg|png|gif|webp)(\?|$)/i)
          return url
        end
        
        # Accept known image hosting domains even without extension
        if url.match?(/^https?:\/\/(i\.redd\.it|i\.imgur\.com|preview\.redd\.it)/i)
          return url
        end
      end

      # Try preview image
      preview = post_data.dig('preview', 'images', 0, 'source', 'url')
      if preview
        cleaned = preview.gsub('&amp;', '&')
        # Validate preview URL is not a subreddit path
        return nil if cleaned.match?(/^\/r\/[^\/]+\/?$/)
        return cleaned
      end

      nil
    end

    # IMPROVEMENT 8: Calculate quality score for sorting
    def calculate_quality_score(upvotes, comments, upvote_ratio)
      # Weighted formula: upvotes are king, but engagement matters
      score = (upvotes * 1.0) + (comments * 0.5) + (upvote_ratio * 100)
      
      # Bonus for very popular posts
      score *= 1.5 if upvotes >= PREFERRED_MIN_UPVOTES
      
      score
    end

    # IMPROVEMENT 9: Strict validation AND quality filtering
    def validate_and_filter_quality_memes(memes)
      validated = memes.select do |m|
        url = m['url'].to_s.strip
        
        # Must have valid URL
        next false unless url.match?(/^https?:\/\//)
        
        # CRITICAL: Reject subreddit paths (these cause fallback errors)
        next false if url.match?(/^\/r\/[^\/]+\/?$/)
        next false if url.match?(/reddit\.com\/r\/[^\/]+\/?$/)
        next false if url.include?('/r/') && url.include?('/comments/')
        
        # Must be actual media URL
        is_media = url.match?(/\.(jpg|jpeg|png|gif|webp|mp4|webm)(\?|$)/i) ||
                   url.match?(/^https?:\/\/(i\.redd\.it|i\.imgur\.com|preview\.redd\.it|v\.redd\.it)/)
        next false unless is_media
        
        # Must have minimum quality metrics
        next false unless m['likes'].to_i >= MIN_UPVOTES
        next false unless m['upvote_ratio'].to_f >= MIN_UPVOTE_RATIO
        
        true
      end
      
      # Sort by quality score (highest first)
      sorted = validated.sort_by { |m| -(m['quality_score'] || 0) }
      
      # IMPROVEMENT 10: Return top 200 highest quality memes
      sorted.first(200)
    end
  end
end
