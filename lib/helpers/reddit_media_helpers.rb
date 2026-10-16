# frozen_string_literal: true
require_relative '../security/media_url'

# RedditMediaHelpers - Reddit API integration and media processing
#
# Responsibilities:
# - Fetch memes from Reddit's public JSON API
# - Extract image URLs from various Reddit post formats
# - Build enriched meme objects with preview data
# - Process media metadata for fallback chains
# - Detect media types and provide category-appropriate fallbacks
#
# Part of Phase 4 refactoring to reduce app.rb monolith
module RedditMediaHelpers
  # Fetch memes from popular subreddits with working image links
  def fetch_reddit_memes(subreddits = POPULAR_SUBREDDITS, limit = 45)
    memes = []
    subreddits = subreddits.sample(25) if subreddits.size > 30

    # Multiple user agents to avoid blocking
    user_agents = [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1",
      "curl/7.64.1"
    ]

    subreddits.each do |subreddit|
      attempts = 0
      max_attempts = 3
      
      while attempts < max_attempts
        fetched = false
        begin
          url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
          uri = URI(url)
          
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15, open_timeout: 15) do |http|
            request = Net::HTTP::Get.new(uri.request_uri)
            request["User-Agent"] = user_agents[attempts % user_agents.size]
            request["Accept"] = "application/json, text/javascript, */*; q=0.01"
            request["Accept-Language"] = "en-US,en;q=0.9"
            request["Accept-Encoding"] = "gzip, deflate"
            request["DNT"] = "1"
            request["Connection"] = "keep-alive"
            request["Upgrade-Insecure-Requests"] = "1"
            
            response = http.request(request)
            
            if response.code == "200"
              body = response.body
              data = JSON.parse(body)

              data["data"]["children"].each do |post|
                post_data = post["data"]
                next if post_data["is_video"] || post_data["is_self"] || !post_data["url"]

                image_url = extract_image_url(post_data)
                next unless image_url && image_url.match?(/^https?:\/\//)

                # Use build_meme_object to include preview images for fallback
                meme = build_meme_object(post_data, image_url)
                memes << meme
              end
              fetched = true
            else
              attempts += 1
              sleep 2 if attempts < max_attempts
            end
          end
          break if fetched
        rescue JSON::ParserError => e
          attempts += 1
          sleep 2 if attempts < max_attempts
        rescue => e
          attempts += 1
          sleep 2 if attempts < max_attempts
        end
      end
      
      sleep 1.5  # Be respectful to Reddit between requests
    end

    memes
  end

  # Extract direct image URL from Reddit post data (including GIFs and animated content)
  # NOW ENHANCED: Also enriches meme with preview images for fallback chain
  def extract_image_url(post_data)
    return nil unless post_data.is_a?(Hash)
    url = MediaUrl.safe(post_data['url'])
    return nil unless url

    # Always prefer i.redd.it, imgur, and other known image CDNs
    # Most permissive: Accept any HTTPS URL that looks like an image
    if url.match?(/^https:\/\/.*?\.(jpg|jpeg|png|gif|webp|gifv|mp4)(\?.*)?$/i)
      return url
    end

    # Handle imgur page URLs - convert to direct imgur image
    if url.match?(/^https:\/\/imgur\.com\/([a-zA-Z0-9]+)$/i)
      imgur_id = url.match(/imgur\.com\/([a-zA-Z0-9]+)/i)[1]
      return "https://i.imgur.com/#{imgur_id}.jpg"
    end

    # Media metadata gallery
    gallery = post_data['gallery_data']
    items = gallery['items'] if gallery.is_a?(Hash)
    first_item = items.first if items.is_a?(Array)
    metadata = post_data['media_metadata']
    image = metadata[first_item['media_id']] if metadata.is_a?(Hash) && first_item.is_a?(Hash)
    source = image['s'] if image.is_a?(Hash)
    candidate = source['u'] if source.is_a?(Hash)
    if candidate.is_a?(String)
      gallery_url = MediaUrl.social_image(candidate.gsub('&amp;', '&'), origin: '')
      return gallery_url if gallery_url
    end

    # Reuse shape checking and URL validation for preview fallback candidates.
    extract_preview_images(post_data.reject { |key, _| key == 'thumbnail' }).each do |candidate|
      preview_url = MediaUrl.social_image(candidate, origin: '')
      return preview_url if preview_url
    end

    nil
  end
  
  # Build enriched meme object with preview images for smart fallback
  def build_meme_object(post_data, image_url)
    meme = {
      "title" => post_data["title"],
      "url" => image_url,
      "subreddit" => post_data["subreddit"],
      "likes" => post_data["ups"] || 0,
      "permalink" => post_data["permalink"]
    }
    
    # Add preview data for smart fallback chain
    if post_data["preview"]
      meme["preview"] = post_data["preview"]
    end
    
    # Add thumbnail if valid
    if post_data["thumbnail"] && !%w[self default nsfw].include?(post_data["thumbnail"])
      meme["thumbnail"] = post_data["thumbnail"]
    end
    
    meme
  end

  # Extract preview images from Reddit post data for fallback chain
  def extract_preview_images(meme)
    return [] unless meme.is_a?(Hash)
    
    candidates = []
    preview = meme['preview']
    entries = preview['images'] if preview.is_a?(Hash)
    if entries.is_a?(Array)
      entries.each do |entry|
        next unless entry.is_a?(Hash)
        source = entry['source']
        candidates << source['url'] if source.is_a?(Hash)
        resolutions = entry['resolutions']
        if resolutions.is_a?(Array)
          resolutions.each { |resolution| candidates << resolution['url'] if resolution.is_a?(Hash) }
        end
      end
    end
    candidates << meme['thumbnail']
    candidates.filter_map do |candidate|
      MediaUrl.safe(candidate.gsub('&amp;', '&')) if candidate.is_a?(String)
    end.uniq
  end
  
  # Detect media type from URL
  def detect_media_type(url)
    return 'image' unless url.is_a?(String)
    
    ext = File.extname(url.split(/[?#]/, 2).first).downcase
    case ext
    when '.mp4', '.webm', '.mov'
      'video'
    when '.gif', '.gifv'
      'gif'
    else
      'image'
    end
  end
  
  # Get category-appropriate fallback image based on subreddit
  def get_category_fallback(meme)
    return '/images/funny1.jpeg' unless meme.is_a?(Hash)
    
    subreddit = (meme["subreddit"] || '').downcase
    
    # Match subreddit to category
    if subreddit.match?(/wholesome|aww|mademesmile|heartwarming/)
      ['/images/wholesome1.jpeg', '/images/wholesome2.jpeg', '/images/wholesome3.jpeg'].sample
    elsif subreddit.match?(/selfcare|health|fitness|wellness|meditation/)
      ['/images/selfcare1.jpeg', '/images/selfcare2.jpeg', '/images/selfcare3.jpeg'].sample
    elsif subreddit.match?(/dank/)
      ['/images/dank1.jpeg', '/images/dank2.jpeg'].sample
    else
      # Funny/general - rotate through all
      ['/images/funny1.jpeg', '/images/funny2.jpeg', '/images/funny3.jpeg'].sample
    end
  end
end
