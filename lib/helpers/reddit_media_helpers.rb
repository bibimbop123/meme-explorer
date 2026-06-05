# frozen_string_literal: true

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
              break  # Success, exit retry loop
            else
              attempts += 1
              sleep 2 if attempts < max_attempts
            end
          end
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
    url = post_data["url"]
    return nil unless url && url.is_a?(String)

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
    if post_data["gallery_data"]&.dig("items")&.first
      gallery_id = post_data["gallery_data"]["items"].first["media_id"]
      if post_data["media_metadata"]&.dig(gallery_id, "s", "x")
        gallery_url = post_data["media_metadata"][gallery_id]["s"]["x"]
        # Only return if it ends with an image extension
        return gallery_url if gallery_url.match?(/\.(jpg|jpeg|png|gif|webp)(\?|$)/i)
      end
    end

    # Preview image - fallback
    if post_data["preview"]&.dig("images", 0, "source", "url")
      preview_url = post_data["preview"]["images"][0]["source"]["url"]
      if preview_url&.match?(/\.(jpg|jpeg|png|gif|webp)(\?|$)/i)
        return preview_url.gsub("&amp;", "&")
      end
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
    
    images = []
    
    # Extract from preview metadata
    if meme["preview"].is_a?(Hash)
      preview_images = meme["preview"].dig("images") || []
      preview_images.each do |img_data|
        # Get source URL (highest quality)
        if img_data["source"] && img_data["source"]["url"]
          url = img_data["source"]["url"].gsub("&amp;", "&")
          images << url unless images.include?(url)
        end
        
        # Get resolutions (alternative qualities)
        if img_data["resolutions"].is_a?(Array)
          img_data["resolutions"].each do |res|
            if res["url"]
              url = res["url"].gsub("&amp;", "&")
              images << url unless images.include?(url)
            end
          end
        end
      end
    end
    
    # Add thumbnail if available
    if meme["thumbnail"] && !%w[self default nsfw].include?(meme["thumbnail"])
      images << meme["thumbnail"] unless images.include?(meme["thumbnail"])
    end
    
    images.uniq.compact
  end
  
  # Detect media type from URL
  def detect_media_type(url)
    return 'image' unless url.is_a?(String)
    
    ext = File.extname(url).downcase
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
