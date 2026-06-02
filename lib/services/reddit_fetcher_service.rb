# Unified Reddit Fetcher Service
# Consolidates 3 duplicate fetcher methods from app.rb
# Generated: May 19, 2026

require 'httparty'
require 'net/http'
require 'uri'
require 'json'

class RedditFetcherService
  USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  ].freeze
  
  DEFAULT_TIMEOUT = 15
  DEFAULT_LIMIT = 50
  THROTTLE_DELAY = 1.0 # seconds between requests
  
  def initialize(auth_strategy: :oauth, access_token: nil)
    @auth_strategy = auth_strategy
    @access_token = access_token
  end
  
  # Main entry point - fetches memes using appropriate strategy
  # OPTIMIZED: Fetch from MORE subreddits for maximum meme collection
  def fetch_memes(subreddits, limit: DEFAULT_LIMIT)
    # For OAuth: sample 12 subreddits (increased from 8)
    # For Static: sample 25 subreddits (for better diversity without hitting rate limits)
    max_subreddits = @auth_strategy == :oauth ? 12 : 25
    subreddits = Array(subreddits).sample(max_subreddits) if subreddits&.size.to_i > max_subreddits
    
    case @auth_strategy
    when :oauth
      fetch_with_oauth(subreddits, limit)
    when :static
      fetch_static(subreddits, limit)
    else
      raise ArgumentError, "Unknown auth strategy: #{@auth_strategy}"
    end
  rescue => e
    log_error("Fetch memes failed", e)
    []
  end
  
  private
  
  # OAuth-authenticated fetch (preferred, higher rate limits)
  def fetch_with_oauth(subreddits, limit)
    return [] unless @access_token
    
    memes = []
    
    subreddits.each do |subreddit|
      begin
        url = "https://oauth.reddit.com/r/#{subreddit}/top?t=week&limit=#{limit}"
        
        response = HTTParty.get(url,
          headers: {
            "Authorization" => "Bearer #{@access_token}",
            "User-Agent" => "MemeExplorer/1.0"
          },
          timeout: DEFAULT_TIMEOUT
        )
        
        if response.success?
          memes.concat(parse_reddit_response(response.parsed_response))
        else
          log_error("OAuth fetch failed for r/#{subreddit}", "Status: #{response.code}")
        end
        
        sleep THROTTLE_DELAY
      rescue => e
        log_error("OAuth fetch error for r/#{subreddit}", e)
      end
    end
    
    memes
  end
  
  # Static/unauthenticated fetch (fallback, lower rate limits)
  def fetch_static(subreddits, limit)
    memes = []
    
    subreddits.each do |subreddit|
      begin
        url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
        uri = URI(url)
        
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, 
                                   read_timeout: DEFAULT_TIMEOUT, 
                                   open_timeout: DEFAULT_TIMEOUT) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request["User-Agent"] = USER_AGENTS.sample
          request["Accept"] = "application/json"
          http.request(request)
        end
        
        if response.code == "200"
          data = JSON.parse(response.body)
          memes.concat(parse_reddit_response(data))
        end
        
        sleep THROTTLE_DELAY / 2 # Faster throttle for static
      rescue => e
        log_error("Static fetch error for r/#{subreddit}", e)
      end
    end
    
    memes
  end
  
  # Parse Reddit API response into meme objects
  def parse_reddit_response(data)
    return [] unless data.is_a?(Hash) && data["data"]
    
    children = data.dig("data", "children") || []
    memes = []
    
    children.each do |post|
      post_data = post["data"]
      next unless post_data
      next if post_data["is_self"] # Skip text posts
      
      # Handle gallery posts
      is_gallery = post_data["is_gallery"] == true
      gallery_images = extract_gallery_images(post_data) if is_gallery
      
      # Skip videos unless they're galleries
      next if post_data["is_video"] && !is_gallery
      
      # Get image URL
      image_url = if gallery_images && gallery_images.any?
                    gallery_images.first["url"]
                  else
                    post_data["url"]
                  end
      
      next unless image_url
      
      # Build meme object
      meme = {
        "title" => post_data["title"],
        "url" => image_url,
        "subreddit" => post_data["subreddit"],
        "likes" => post_data["ups"] || 0,
        "permalink" => post_data["permalink"]
      }
      
      # Add gallery data if present
      if is_gallery && gallery_images && gallery_images.any?
        meme["is_gallery"] = true
        meme["gallery_images"] = gallery_images
      end
      
      memes << meme
    end
    
    memes
  end
  
  # Extract gallery images from Reddit post data
  def extract_gallery_images(post_data)
    return nil unless post_data["is_gallery"] && 
                      post_data["gallery_data"] && 
                      post_data["media_metadata"]
    
    gallery_items = post_data["gallery_data"]["items"] || []
    media_metadata = post_data["media_metadata"] || {}
    
    images = []
    gallery_items.each do |item|
      media_id = item["media_id"]
      next unless media_id
      
      media_info = media_metadata[media_id]
      next unless media_info
      
      # Get highest quality image
      image_url = media_info.dig("s", "u") || 
                  media_info.dig("s", "gif") || 
                  media_info.dig("s", "mp4")
      next unless image_url
      
      # Clean up URL encoding
      image_url = image_url.gsub('&amp;', '&')
      
      images << {
        "url" => image_url,
        "caption" => item["caption"] || "",
        "media_id" => media_id
      }
    end
    
    images.any? ? images : nil
  end
  
  # Centralized error logging
  def log_error(context, error)
    message = error.is_a?(String) ? error : error.message
    puts "⚠️  [RedditFetcher] #{context}: #{message}"
    
    # Send to Sentry if available
    if defined?(Sentry) && error.is_a?(Exception)
      Sentry.capture_exception(error, extra: { context: context })
    end
  end
end
