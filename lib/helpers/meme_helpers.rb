# frozen_string_literal: true

# Helper module for common meme operations
# Extracts duplicate code from app.rb for better maintainability

module MemeHelpers
  # Load local memes from YAML with proper structure handling
  # Returns array of meme hashes
  def load_local_memes
    begin
      yaml_data = YAML.load_file("data/memes.yml")
      
      if yaml_data.is_a?(Hash)
        # Handle categorized memes (e.g., { funny: [...], wholesome: [...] })
        yaml_data.values.flatten.compact.map { |m| normalize_meme_paths(m) }
      elsif yaml_data.is_a?(Array)
        # Handle flat array of memes
        yaml_data.compact.map { |m| normalize_meme_paths(m) }
      else
        []
      end
    rescue => e
      puts "⚠️ Error loading local memes: #{e.message}"
      []
    end
  end
  
  # Normalize meme file paths (remove leading slashes for File.join compatibility)
  def normalize_meme_paths(meme)
    return meme unless meme.is_a?(Hash)
    
    meme_copy = meme.dup
    if meme_copy["file"] && meme_copy["file"].start_with?("/")
      meme_copy["file"] = meme_copy["file"][1..-1]
    end
    meme_copy
  end
  
  # Get meme identifier (URL or file path)
  def meme_identifier(meme)
    return nil unless meme.is_a?(Hash)
    meme["url"] || meme["file"]
  end
  
  # Track meme view in database (non-blocking)
  def track_meme_view(meme, user_id: nil)
    return unless meme.is_a?(Hash)
    
    identifier = meme_identifier(meme)
    return unless identifier
    
    Thread.new do
      begin
        title = meme["title"] || "Unknown"
        subreddit = meme["subreddit"] || "local"
        
        # Track in meme_stats
        DB.execute(
          "INSERT INTO meme_stats (url, title, subreddit, views, likes) 
           VALUES (?, ?, ?, 1, 0) 
           ON CONFLICT(url) DO UPDATE SET 
           views = views + 1, updated_at = CURRENT_TIMESTAMP",
          [identifier, title, subreddit]
        )
        
        # Track user exposure for spaced repetition
        if user_id
          DB.execute(
            "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) 
             VALUES (?, ?, 1) 
             ON CONFLICT(user_id, meme_url) DO UPDATE SET 
             shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
            [user_id, identifier]
          )
        end
      rescue => e
        puts "⚠️ Background meme tracking error: #{e.message}"
      end
    end
  end
  
  # Check if meme should be excluded based on session history
  def recently_shown?(meme, session_history)
    return false unless meme.is_a?(Hash) && session_history.is_a?(Array)
    
    identifier = meme_identifier(meme)
    return false unless identifier
    
    session_history.include?(identifier)
  end
  
  # Add meme to session history with size limit
  def add_to_history(identifier, session, max_size: 100)
    return unless identifier
    
    session[:meme_history] ||= []
    session[:meme_history] << identifier
    session[:meme_history] = session[:meme_history].last(max_size)
  end
  
  # Validate meme has required data and accessible resources
  def valid_meme?(meme)
    return false unless meme.is_a?(Hash)
    
    # Check for file-based meme
    if meme["file"]
      file_path = File.join(settings.public_folder, meme["file"])
      return File.exist?(file_path)
    end
    
    # Check for URL-based meme
    if meme["url"]
      return meme["url"].match?(/^https?:\/\//)
    end
    
    false
  end
  
  # Check if meme has valid media URL (not just a reddit post link)
  # This prevents showing fallback images for memes without actual media
  def has_valid_media?(meme)
    return false unless meme.is_a?(Hash)
    
    # Local file-based memes are always valid if file exists
    if meme["file"]
      file_path = File.join(settings.public_folder, meme["file"])
      return File.exist?(file_path)
    end
    
    # For URL-based memes, check if it's an actual media URL
    url = meme["url"]
    return false unless url && url.match?(/^https?:\/\//)
    
    # Exclude reddit post URLs (these would trigger fallback images)
    return false if url.include?('/r/') && url.include?('/comments/')
    
    # Valid media URLs should have recognizable media extensions or domains
    url_lower = url.downcase
    
    # Check for image/video extensions
    return true if url_lower =~ /\.(jpg|jpeg|png|gif|webp|mp4|webm|mov)(\?|$|&)/
    
    # Check for known media hosting domains
    media_domains = [
      'i.redd.it',
      'i.imgur.com',
      'imgur.com',
      'gfycat.com',
      'redgifs.com',
      'v.redd.it',
      'giphy.com',
      'tenor.com'
    ]
    
    return true if media_domains.any? { |domain| url_lower.include?(domain) }
    
    # If we have preview images from Reddit, that's valid
    return true if meme["preview"] && meme["preview"].is_a?(Hash)
    
    # Default: reject to avoid fallback images
    false
  end
  
  # Extract preview images from Reddit post data for fallback chain
  # Returns array of preview image URLs in descending quality order
  def extract_preview_images(meme)
    return [] unless meme.is_a?(Hash)
    
    preview_urls = []
    
    # Check for Reddit preview data structure
    if meme["preview"] && meme["preview"]["images"].is_a?(Array)
      meme["preview"]["images"].each do |img_data|
        # Get source (highest quality)
        if img_data["source"] && img_data["source"]["url"]
          preview_urls << unescape_html_entities(img_data["source"]["url"])
        end
        
        # Get resolutions (fallback options)
        if img_data["resolutions"].is_a?(Array)
          img_data["resolutions"].reverse.each do |res|
            preview_urls << unescape_html_entities(res["url"]) if res["url"]
          end
        end
      end
    end
    
    # Check for thumbnail
    if meme["thumbnail"] && valid_thumbnail_url?(meme["thumbnail"])
      preview_urls << meme["thumbnail"]
    end
    
    preview_urls.compact.uniq
  end
  
  # Check if thumbnail URL is valid (not default Reddit placeholders)
  def valid_thumbnail_url?(thumbnail)
    return false if thumbnail.nil? || thumbnail.empty?
    return false if %w[self default nsfw].include?(thumbnail)
    return false unless thumbnail.start_with?('http')
    true
  end
  
  # Unescape HTML entities in URLs (Reddit returns &amp; instead of &)
  def unescape_html_entities(url)
    return url unless url
    url.gsub('&amp;', '&')
  rescue => e
    puts "⚠️ URL unescape error: #{e.message}"
    url
  end
  
  # Detect media type from URL
  def detect_media_type(url)
    return 'unknown' unless url
    
    url_lower = url.downcase
    
    return 'video' if url_lower =~ /\.(mp4|webm|mov)(\?|$)/
    return 'gif' if url_lower =~ /\.gif(\?|$)/
    return 'image' if url_lower =~ /\.(jpg|jpeg|png|webp)(\?|$)/
    
    # Check if it's a Reddit video domain
    return 'video' if url.include?('v.redd.it')
    
    # Default to image
    'image'
  end
  
  # Get category-appropriate fallback image
  def get_category_fallback(meme)
    return '/images/funny1.jpeg' unless meme.is_a?(Hash)
    
    subreddit = meme["subreddit"]&.downcase || ""
    
    # Use ImageFallbackService if available
    if defined?(ImageFallbackService)
      return ImageFallbackService.get_fallback(subreddit, randomize: true, use_primary: false)
    end
    
    # Fallback to category-based logic
    case subreddit
    when /wholesome|aww|mademesmile/
      ['/images/wholesome1.jpeg', '/images/wholesome2.jpeg', '/images/wholesome3.jpeg'].sample
    when /selfcare|health|fitness|wellness/
      ['/images/selfcare1.jpeg', '/images/selfcare2.jpeg', '/images/selfcare3.jpeg'].sample
    when /dank/
      ['/images/dank1.jpeg', '/images/dank2.jpeg'].sample
    else
      ['/images/funny1.jpeg', '/images/funny2.jpeg', '/images/funny3.jpeg'].sample
    end
  end
  
  # Get reddit path for meme (permalink or URL)
  def reddit_path(meme, image_src)
    return nil unless meme.is_a?(Hash)
    
    # Try reddit_post_urls array
    if meme["reddit_post_urls"]&.is_a?(Array)
      post_url = meme["reddit_post_urls"].find { |u| u.include?(image_src) }
      return extract_path(post_url) if post_url
    end
    
    # Fallback to permalink
    if meme["permalink"].to_s.strip != ""
      return extract_path(meme["permalink"])
    end
    
    nil
  rescue => e
    puts "⚠️ Reddit path error: #{e.message}"
    nil
  end
  
  # Extract path from full URL
  def extract_path(url)
    return nil if url.nil? || url.strip.empty?
    return url unless url.start_with?("http")
    
    uri = URI.parse(url)
    uri.path
  rescue => e
    puts "⚠️ Path extraction error: #{e.message}"
    nil
  end
  
  # Build meme response hash for JSON API
  def meme_to_json(meme, include_likes: true)
    image_url = meme_identifier(meme)
    
    response = {
      title: meme["title"],
      subreddit: meme["subreddit"],
      file: meme["file"],
      url: image_url
    }
    
    if include_likes && image_url
      response[:likes] = get_meme_likes(image_url)
    end
    
    # Add reddit path if available
    reddit_link = reddit_path(meme, image_url)
    response[:reddit_path] = reddit_link if reddit_link
    
    response
  end
  
  # Calculate engagement score for meme
  def engagement_score(meme)
    likes = meme["likes"].to_i
    views = meme["views"].to_i
    (likes * 2) + views
  end
  
  # Check if meme is placeholder/fallback
  def placeholder_meme?(meme)
    return false unless meme.is_a?(Hash)
    meme["is_placeholder"] == true
  end
end
