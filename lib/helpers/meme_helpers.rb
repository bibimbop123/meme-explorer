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
