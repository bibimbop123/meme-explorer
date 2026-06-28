# frozen_string_literal: true
# lib/services/inline_reddit_fetcher.rb
#
# Extracted from app.rb (Sprint 5 cleanup) — was MemeExplorer::App class methods.
# These are the lightweight fallback fetchers used when RedditFetcherService is
# unavailable. RedditFetcherService is the primary path.

module InlineRedditFetcher
  # Fetch memes using client_credentials OAuth (no user login required).
  # Works for reading public subreddits. Preferred over fetch_static which
  # Reddit blocks with 403 on unauthenticated requests.
  def self.fetch(subreddits, limit: 25)
    token = get_app_token
    return fetch_static(subreddits, limit: limit) unless token

    fetch_authenticated(token, subreddits, limit: limit)
  end

  # Get a Reddit app-level OAuth token (client_credentials grant).
  # Does not require a user to log in — just the app credentials.
  def self.get_app_token
    client_id     = ENV['REDDIT_CLIENT_ID'].to_s.strip
    client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
    return nil if client_id.empty? || client_secret.empty?

    require 'base64'
    auth = Base64.strict_encode64("#{client_id}:#{client_secret}")
    response = HTTParty.post(
      'https://www.reddit.com/api/v1/access_token',
      body:    { grant_type: 'client_credentials' },
      headers: {
        'Authorization' => "Basic #{auth}",
        'User-Agent'    => "MemeExplorer/1.0 (by #{ENV.fetch('REDDIT_USERNAME', 'meme-explorer-bot')})"
      },
      timeout: 10
    )
    return nil unless response.success?

    response.parsed_response['access_token']
  rescue => e
    AppLogger.warn("InlineRedditFetcher: failed to get app token", error: e.message)
    nil
  end

  # Authenticated fetch using an existing OAuth access token.
  def self.fetch_authenticated(access_token, subreddits, limit: 15)
    require 'httparty'
    memes = []
    subreddits = subreddits.sample(8) if subreddits.size > 8

    subreddits.each do |subreddit|
      url = "https://oauth.reddit.com/r/#{subreddit}/top?t=week&limit=#{limit}"
      response = HTTParty.get(url,
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'User-Agent' => "MemeExplorer/1.0 (by #{ENV.fetch('REDDIT_USERNAME', 'meme-explorer-bot')})"
        },
        timeout: 15
      )
      next unless response.success?

      response.parsed_response.dig('data', 'children')&.each do |post|
        meme = extract_meme(post['data'])
        memes << meme if meme
      end
      sleep 1
    rescue => e
      AppLogger.error("InlineRedditFetcher authenticated error", subreddit: subreddit, error: e.message)
    end
    memes
  end

  # Unauthenticated fetch via public JSON API.
  def self.fetch_static(subreddits, limit: 100)
    memes = []
    subreddits = subreddits.sample(40) if subreddits.size > 40
    user_agents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
    ]

    subreddits.each do |subreddit|
      uri = URI("https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Get.new(uri)
        req['User-Agent'] = user_agents.sample
        http.request(req)
      end
      next unless response.code == '200'

      JSON.parse(response.body).dig('data', 'children')&.each do |post|
        meme = extract_meme(post['data'])
        memes << meme if meme
      end
      sleep 0.5
    rescue => e
      AppLogger.warn("InlineRedditFetcher static error", subreddit: subreddit, error: e.message)
    end
    memes
  end

  # ── private helpers ──────────────────────────────────────────────────────

  def self.extract_meme(post_data)
    return nil if post_data['is_self'] || (post_data['is_video'] && !post_data['is_gallery'])

    gallery_images = extract_gallery_images(post_data) if post_data['is_gallery']
    image_url      = gallery_images&.first&.dig('url') || post_data['url']
    return nil unless image_url

    meme = {
      'title'     => post_data['title'],
      'url'       => image_url,
      'subreddit' => post_data['subreddit'],
      'likes'     => post_data['ups'] || 0,
      'permalink' => post_data['permalink']
    }

    if gallery_images&.any?
      meme['is_gallery']     = true
      meme['gallery_images'] = gallery_images
    end
    meme
  end
  private_class_method :extract_meme

  def self.extract_image_url(post_data)
    return post_data['url'] if post_data['url']&.match?(%r{^https://i\.redd\.it/})
    return post_data['url'] if post_data['url']&.match?(%r{^https://(i\.)?imgur\.com/})

    url = post_data.dig('preview', 'images', 0, 'source', 'url')
    url&.gsub('&amp;', '&')
  end
  private_class_method :extract_image_url

  def self.extract_gallery_images(post_data)
    return nil unless post_data['is_gallery'] &&
                      post_data['gallery_data'] &&
                      post_data['media_metadata']

    items    = post_data.dig('gallery_data', 'items') || []
    metadata = post_data['media_metadata'] || {}

    images = items.filter_map do |item|
      media_id   = item['media_id']
      next unless media_id
      media_info = metadata[media_id]
      next unless media_info

      url = media_info.dig('s', 'u') || media_info.dig('s', 'gif') || media_info.dig('s', 'mp4')
      next unless url

      { 'url' => url.gsub('&amp;', '&'), 'caption' => item['caption'] || '', 'media_id' => media_id }
    end

    images.any? ? images : nil
  end
  private_class_method :extract_gallery_images
end
