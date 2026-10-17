# Unified Reddit Fetcher Service
# Consolidates 3 duplicate fetcher methods from app.rb
# Generated: May 19, 2026

require 'httparty'
require 'net/http'
require 'uri'
require 'json'
require 'time'
require_relative '../helpers/media_dimensions'
require_relative 'reddit_media_resolver'

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
    @outcomes = { requests: 0, successful_listings: 0, auth_failures: 0,
                  rate_limit_responses: 0, other_http_failures: 0, request_errors: 0,
                  missing_token_calls: 0 }
  end

  # Main entry point - fetches memes using appropriate strategy
  # PHASE 1 OPTIMIZATION: Doubled subreddit sampling for 5x variety increase
  def fetch_memes(subreddits, limit: DEFAULT_LIMIT, pages: 1)
    return [] if rate_limited?
    @page_limit = [[pages.to_i, 1].max, 2].min
    # PHASE 1: Doubled from 12→25 (OAuth) and 25→50 (Static)
    # Target: 2,000+ meme pool (up from 500)
    max_subreddits = @auth_strategy == :oauth ? 25 : 50
    subreddits = Array(subreddits).sample(max_subreddits) if subreddits&.size.to_i > max_subreddits

    case @auth_strategy
    when :oauth
      fetch_with_oauth(subreddits, limit).uniq { |m| m["url"] }
    when :static
      fetch_static(subreddits, limit).uniq { |m| m["url"] }
    else
      raise ArgumentError, "Unknown auth strategy: #{@auth_strategy}"
    end
  rescue => e
    log_error("Fetch memes failed", e)
    []
  ensure
    AppLogger.info('[RedditFetcher] Provider outcomes', **@outcomes) if defined?(AppLogger)
  end

  def rate_limited?
    @rate_limited == true
  end

  private

  # OAuth-authenticated fetch (preferred, higher rate limits)
  def fetch_with_oauth(subreddits, limit)
    unless @access_token.is_a?(String) && !@access_token.strip.empty?
      @outcomes[:missing_token_calls] += 1
      return []
    end

    memes = []

    subreddits.each do |subreddit|
      after = nil
      (@page_limit || 1).times do
        begin
          url = "https://oauth.reddit.com/r/#{subreddit}/top?t=week&limit=#{limit}"

          url += "&after=#{URI.encode_www_form_component(after)}" if after
          @outcomes[:requests] += 1
          response = HTTParty.get(url,
            headers: {
              "Authorization" => "Bearer #{@access_token}",
              "User-Agent" => "MemeExplorer/1.0"
            },
            timeout: DEFAULT_TIMEOUT
          )

          record_response(response.code.to_i)
          if response.code.to_i == 429
            @rate_limited = true
            return memes
          end
          if response.success?
            data = response.parsed_response
            memes.concat(parse_reddit_response(data))
            next_after = data.dig("data", "after")
          else
            log_error("OAuth fetch failed for r/#{subreddit}", "Status: #{response.code}")
            break
          end

          sleep THROTTLE_DELAY
          break unless next_after.is_a?(String) && next_after.match?(/\At3_[A-Za-z0-9]+\z/) && next_after != after
          after = next_after
        rescue => e
          @outcomes[:request_errors] += 1
          log_error("OAuth fetch error for r/#{subreddit}", e)
          break
        end
      end
    end

    memes
  end

  # Static/unauthenticated fetch (fallback, lower rate limits)
  def fetch_static(subreddits, limit)
    memes = []

    subreddits.each do |subreddit|
      after = nil
      (@page_limit || 1).times do
        begin
          url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
          url += "&after=#{URI.encode_www_form_component(after)}" if after
          uri = URI(url)
          @outcomes[:requests] += 1

          response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                     read_timeout: DEFAULT_TIMEOUT,
                                     open_timeout: DEFAULT_TIMEOUT) do |http|
            request = Net::HTTP::Get.new(uri.request_uri)
            request["User-Agent"] = USER_AGENTS.sample
            request["Accept"] = "application/json"
            http.request(request)
          end

          record_response(response.code.to_i)
          if response.code.to_i == 429
            @rate_limited = true
            return memes
          end
          if response.code == "200"
            data = JSON.parse(response.body)
            memes.concat(parse_reddit_response(data))
            next_after = data.dig("data", "after")
          else
            break
          end

          sleep THROTTLE_DELAY / 2 # Faster throttle for static
          break unless next_after.is_a?(String) && next_after.match?(/\At3_[A-Za-z0-9]+\z/) && next_after != after
          after = next_after
        rescue => e
          @outcomes[:request_errors] += 1
          log_error("Static fetch error for r/#{subreddit}", e)
          break
        end
      end
    end

    memes
  end

  # Parse Reddit API response into meme objects
  def record_response(code)
    key = case code
          when 200..299 then :successful_listings
          when 401, 403 then :auth_failures
          when 429 then :rate_limit_responses
          else :other_http_failures
          end
    @outcomes[key] += 1
  end

  def parse_reddit_response(data)
    return [] unless data.is_a?(Hash) && data["data"]

    children = data.dig("data", "children") || []
    memes = []

    children.each do |post|
      post_data = post["data"]
      next unless post_data
      next if post_data["is_self"] # Skip text posts
      resolved = RedditMediaResolver.resolve(post_data)
      next unless resolved
      post_data = post_data.merge(resolved)

      # Handle gallery posts
      is_gallery = post_data["is_gallery"] == true
      gallery_images = post_data['gallery_images'] if is_gallery

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
      meme.merge!(resolved)
      # Fetch time is not content freshness. Preserve source provenance so pool
      # audits/replacement can distinguish old weekly-top posts from new supply.
      source_time = post_data['created_utc']
      if source_time.is_a?(Numeric) && source_time.finite? && source_time > 0 && source_time <= Time.now.to_f
        meme['created_at'] = Time.at(source_time).utc.iso8601
      end
      source_id = post_data['id']
      meme['reddit_post_id'] = source_id if source_id.is_a?(String) && source_id.match?(/\A[a-z0-9]{1,16}\z/)
      dimensions = if gallery_images && gallery_images.any?
                     MediaDimensions.for(gallery_images.first)
                   else
                     matching_preview_dimensions(post_data, image_url)
                   end
      dimensions.each { |key, value| meme[key.to_s] = value }

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
        "media_id" => media_id,
        **MediaDimensions.for('width' => media_info.dig('s', 'x'), 'height' => media_info.dig('s', 'y')).transform_keys(&:to_s)
      }
    end

    images.any? ? images : nil
  end

  def matching_preview_dimensions(post_data, image_url)
    preview = post_data['preview']
    return {} unless preview.is_a?(Hash) && preview['images'].is_a?(Array)
    preview['images'].each do |image|
      next unless image.is_a?(Hash) && image['source'].is_a?(Hash)
      source = image['source']
      next unless source['url'].is_a?(String) && source['url'].gsub('&amp;', '&') == image_url
      return MediaDimensions.for(source)
    end
    {}
  end

  # Centralized error logging
  def log_error(context, error)
    message = error.is_a?(String) ? error : error.message
    AppLogger.warn("⚠️  [RedditFetcher] #{context}: #{message}")

    # Send to Sentry if available
    if defined?(Sentry) && error.is_a?(Exception)
      Sentry.capture_exception(error, extra: { context: context })
    end
  end
end
