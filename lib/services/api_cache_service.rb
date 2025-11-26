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

        # Try unauthenticated fetch first (faster)
        begin
          Timeout.timeout(FETCH_TIMEOUT) do
            subreddits_sample = popular_subreddits.sample([8, popular_subreddits.size].min)
            api_memes = fetch_reddit_memes_unauthenticated(subreddits_sample, 40)
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
                subreddits_sample = popular_subreddits.sample([8, popular_subreddits.size].min)
                api_memes = fetch_reddit_memes_authenticated(token.token, subreddits_sample, 40)
                puts "[CACHE] Authenticated fetch: #{api_memes.size} memes"
              end
            rescue Timeout::Error
              puts "[CACHE] Timeout on authenticated fetch"
            rescue => e
              puts "[CACHE] Error on authenticated fetch: #{e.message}"
            end
          end
        end

        # Validate and cache
        if api_memes && !api_memes.empty?
          validated = validate_memes(api_memes)
          if !validated.empty?
            set_cached_memes(validated)
            puts "[CACHE] Cached #{validated.size} valid memes"
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
          response = HTTParty.get(
            "https://oauth.reddit.com/r/#{subreddit}/top?t=week&limit=#{limit}",
            headers: {
              'Authorization' => "Bearer #{token}",
              'User-Agent' => 'MemeExplorer/1.0'
            },
            timeout: 15
          )
          if response.success?
            (response.parsed_response.dig('data', 'children') || []).each do |post|
              post_data = post['data']
              next if post_data['is_video']

              image_url = extract_image_url(post_data)
              next unless image_url

              memes << {
                'title' => post_data['title'],
                'url' => image_url,
                'subreddit' => post_data['subreddit'],
                'likes' => post_data['ups'] || 0
              }
            end
          end
          sleep 0.5
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
          url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
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
              next if post_data['is_video']

              image_url = extract_image_url(post_data)
              next unless image_url

              memes << {
                'title' => post_data['title'],
                'url' => image_url,
                'subreddit' => post_data['subreddit'],
                'likes' => post_data['ups'] || 0
              }
            end
          end
          sleep 0.5
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
        if url.match?(/\.(jpg|jpeg|png|gif|webp)(\?|$)/i)
          return url
        end
      end

      # Try preview image
      preview = post_data.dig('preview', 'images', 0, 'source', 'url')
      if preview
        return preview.gsub('&amp;', '&')
      end

      nil
    end

    def validate_memes(memes)
      memes.select do |m|
        url = m['url'].to_s.strip
        url.match?(/^https?:\/\//)
      end
    end
  end
end
