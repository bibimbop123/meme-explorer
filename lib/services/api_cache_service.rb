require 'redis'
require 'json'
require 'oauth2'
require 'httparty'
require 'timeout'
require 'net/http'
require 'uri'
require 'net/http'
class ApiCacheService
  CACHE_TTL = 1800
  LOCK_TTL = 30
  FETCH_TIMEOUT = 45

  class << self
    def redis
      @redis ||= begin
        begin
          r = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
          r.ping
          r
        rescue
          nil
        end
      end
    end

    def get_cached_memes
      return nil unless redis
      begin
        cached = redis.get('cache:api_memes:latest')
        return nil unless cached
        memes = JSON.parse(cached)
        return memes if memes.is_a?(Array) && !memes.empty?
      rescue
        nil
      end
    end

    def set_cached_memes(memes)
      return false unless redis
      return false unless memes.is_a?(Array) && !memes.empty?
      begin
        redis.setex('cache:api_memes:latest', CACHE_TTL, memes.to_json)
        redis.setex('cache:api_memes:timestamp', CACHE_TTL, Time.now.to_i.to_s)
        true
      rescue
        false
      end
    end

    def cache_age
      return nil unless redis
      begin
        timestamp_str = redis.get('cache:api_memes:timestamp')
        return nil unless timestamp_str
        Time.now.to_i - timestamp_str.to_i
      rescue
        nil
      end
    end

    def cache_fresh?
      age = cache_age
      age && age < 1500
    end

    def acquire_lock
      return true unless redis
      begin
        redis.set('cache:api_memes:lock', Time.now.to_i.to_s, nx: true, ex: LOCK_TTL).present?
      rescue
        false
      end
    end

    def release_lock
      redis&.del('cache:api_memes:lock')
    end

    def fetch_and_cache_memes(popular_subreddits)
      if cache_fresh?
        cached = get_cached_memes
        return cached if cached && !cached.empty?
      end

      return get_cached_memes || [] unless acquire_lock

      begin
        api_memes = []
        client_id = ENV.fetch('REDDIT_CLIENT_ID', '').to_s.strip
        client_secret = ENV.fetch('REDDIT_CLIENT_SECRET', '').to_s.strip

        if !client_id.empty? && !client_secret.empty?
          begin
            Timeout.timeout(FETCH_TIMEOUT) do
              client = OAuth2::Client.new(client_id, client_secret, site: 'https://www.reddit.com', authorize_url: '/api/v1/authorize', token_url: '/api/v1/access_token')
              token = client.client_credentials.get_token(scope: 'read')
              subreddits_sample = popular_subreddits.sample([8, popular_subreddits.size].min)
              api_memes = fetch_reddit_memes_authenticated(token.token, subreddits_sample, 40)
            end
          rescue
            nil
          end
        end

        if api_memes.empty?
          begin
            Timeout.timeout(FETCH_TIMEOUT) do
              subreddits_sample = popular_subreddits.sample([8, popular_subreddits.size].min)
              api_memes = fetch_reddit_memes_unauthenticated(subreddits_sample, 40)
            end
          rescue
            nil
          end
        end

        if api_memes && !api_memes.empty?
          validated = validate_memes(api_memes)
          set_cached_memes(validated) if !validated.empty?
          return validated unless validated.empty?
        end

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
          response = HTTParty.get("https://oauth.reddit.com/r/#{subreddit}/top?t=week&limit=#{limit}", headers: { 'Authorization' => "Bearer #{token}", 'User-Agent' => 'MemeExplorer/1.0' }, timeout: 15)
          if response.success?
            (response.parsed_response.dig('data', 'children') || []).each do |post|
              post_data = post['data']
              next if post_data['is_video'] || post_data['is_self'] || !post_data['url']
              memes << { 'title' => post_data['title'], 'url' => post_data['url'], 'subreddit' => post_data['subreddit'], 'likes' => post_data['ups'] || 0, 'permalink' => post_data['permalink'] }
            end
          end
          sleep 0.5
        rescue
          nil
        end
      end
      memes
    end

    def fetch_reddit_memes_unauthenticated(subreddits, limit)
      memes = []
      user_agents = ['Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36']
      subreddits.each do |subreddit|
        begin
          url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
          uri = URI(url)
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10, open_timeout: 10) do |http|
            request = Net::HTTP::Get.new(uri.request_uri)
            request['User-Agent'] = user_agents.sample
            http.request(request)
          end
          if response.code == '200'
            (JSON.parse(response.body).dig('data', 'children') || []).each do |post|
              post_data = post['data']
              next if post_data['is_video'] || post_data['is_self'] || !post_data['url']
              memes << { 'title' => post_data['title'], 'url' => post_data['url'], 'subreddit' => post_data['subreddit'], 'likes' => post_data['ups'] || 0 }
            end
          end
          sleep 0.5
        rescue
          nil
        end
      end
      memes
    end

    def validate_memes(memes)
      memes.select { |m| m['url'].to_s.strip.match?(/^https?:\/\//) }
    end
  end
end
