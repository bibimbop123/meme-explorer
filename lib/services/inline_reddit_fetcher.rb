# InlineRedditFetcher - Lightweight alias to RedditFetcherService
# Restored after audit with rate limiting protection

require_relative 'reddit_fetcher_service'

class InlineRedditFetcher
  class << self
    # Rate limiting state
    @last_request_time = Time.now
    @min_delay = 1.0  # Start with 1 second between requests
    
    # Fetch memes with authentication + rate limiting
    def fetch_authenticated(access_token, subreddits, limit: 25)
      enforce_rate_limit
      fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: access_token)
      fetcher.fetch_memes(subreddits, limit: limit)
    rescue => e
      handle_error(e)
    end
    
    # Fetch memes without authentication (static) + rate limiting  
    def fetch_static(subreddits, limit: 100)
      enforce_rate_limit
      fetcher = RedditFetcherService.new(auth_strategy: :static)
      fetcher.fetch_memes(subreddits, limit: limit)
    rescue => e
      handle_error(e)
    end
    
    # Generic fetch (detects auth automatically) + rate limiting
    #
    # BUG FIX (Aug 25, 2026): this previously always called fetch_static,
    # meaning every on-demand "Cache empty — fetching from Reddit via OAuth..."
    # fallback (see lib/helpers/meme_pool_helpers.rb#random_memes_pool) was
    # actually hitting Reddit's unauthenticated public JSON endpoint
    # (www.reddit.com/r/.../top.json) despite the log message claiming OAuth.
    # The static endpoint is rate-limited far more aggressively than OAuth,
    # so this fallback path almost always returned zero memes even when a
    # valid REDDIT_CLIENT_ID/REDDIT_CLIENT_SECRET were configured and OAuth
    # would have succeeded. Now actually uses OAuth when credentials exist.
    def fetch(subreddits, limit: 25)
      token = fetch_oauth_token
      if token
        fetch_authenticated(token, subreddits, limit: limit)
      else
        fetch_static(subreddits, limit: limit)
      end
    end
    
    private

    # Fetch a short-lived OAuth token via client-credentials grant.
    # Returns nil (triggering static fallback) if credentials aren't
    # configured or the token request fails for any reason.
    def fetch_oauth_token
      client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
      client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
      return nil if client_id.empty? || client_secret.empty?

      require 'net/http'
      require 'json'

      uri = URI('https://www.reddit.com/api/v1/access_token')
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(client_id, client_secret)
      request['User-Agent'] = ENV['REDDIT_USER_AGENT'] || 'MemeExplorer/1.0'
      request.set_form_data('grant_type' => 'client_credentials')

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                                  open_timeout: 5, read_timeout: 5) do |http|
        http.request(request)
      end

      return nil unless response.code == '200'

      JSON.parse(response.body)['access_token']
    rescue => e
      AppLogger.warn("⚠️  [InlineRedditFetcher] OAuth token fetch failed: #{e.message}") if defined?(AppLogger)
      nil
    end

    # Enforce exponential backoff rate limiting
    def enforce_rate_limit
      time_since_last = Time.now - @last_request_time
      if time_since_last < @min_delay
        sleep(@min_delay - time_since_last)
      end
      @last_request_time = Time.now
    end
    
    # Handle errors with exponential backoff
    def handle_error(error)
      if error.message.include?('429') || error.message.include?('rate')
        @min_delay = [@min_delay * 2, 60].min  # Max 60 seconds
        AppLogger.warn("⚠️  Rate limited - backing off to s")
      end
      []  # Return empty array on error
    end
    
    # Extract image URL from post data (delegated to helper)
    def extract_image_url(post_data)
      post_data['url']
    end
    
    # Extract gallery images (delegated to helper)  
    def extract_gallery_images(post_data)
      post_data['gallery_images'] || []
    end
  end
end
