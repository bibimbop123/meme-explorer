# frozen_string_literal: true
# lib/helpers/meme_navigation_helpers.rb
#
# Extracted from app.rb helpers do...end block (Sprint 6 cleanup).
# Contains navigation, pool selection, validation, and placeholder helpers.
# Registered in app.rb via: helpers MemeNavigationHelpers

module MemeNavigationHelpers
  # PersonalityContent is included via: helpers PersonalityContent (app.rb)
  # Do not include here at load time — it causes NameError if personality_content
  # is not yet required when this file loads.


  # -----------------------
  # Helpers
  # -----------------------
# Safely get meme image - prioritize API URLs over local files
def meme_image_src(m)
  return "/images/funny1.jpeg" unless m.is_a?(Hash)
  m["url"].to_s.strip != "" ? m["url"] : (m["file"].to_s.strip != "" ? m["file"] : "/images/funny1.jpeg")
end

# Fallback meme - shown while API is loading or content unavailable
def fallback_meme
  { 
    "title" => "Loading memes from the cosmos...", 
    "file" => "/images/funny1.jpeg", 
    "subreddit" => "loading",
    "is_placeholder" => true
  }
end

# Ensure subreddit string
def sanitize_subreddit(sub)
  return "local" if sub.nil? || sub.strip.empty?
  sub.downcase
end

# Unified Navigation with Intelligent Pool + Spaced Repetition
# Consolidates navigate_meme and navigate_meme_v3 into single optimized method
def navigate_meme_unified(direction: "next")
  user_id = session[:user_id]
  
  # Choose pool strategy based on user state
  memes = if user_id
    # New users (< 10 views) get fresh cache, established users get personalized pool
    exposure_count = DB.execute("SELECT COUNT(*) FROM user_meme_exposure WHERE user_id = ?", [user_id]).first[0].to_i
    is_new_user = exposure_count < 10
    
    if is_new_user
      random_memes_pool  # Fresh API memes for onboarding
    else
      get_time_based_pools(user_id, 100)  # Intelligent pool with spaced repetition
    end
  else
    random_memes_pool  # Anonymous users get standard pool
  end
  
  return nil if memes.empty?

  # Initialize session tracking
  session[:meme_history] ||= []
  session[:last_subreddit] ||= nil
  last_meme_url = session[:meme_history].last

  # Find valid meme with smart filtering
  new_meme = nil
  attempts = 0
  max_attempts = [memes.size, 30].min
  
  while attempts < max_attempts
    candidate = memes.sample
    candidate_id = candidate["url"] || candidate["file"]
    candidate_subreddit = candidate["subreddit"]&.downcase
    
    # Check spaced repetition for logged-in users
    if user_id && should_exclude_from_exposure(user_id, candidate_id)
      attempts += 1
      next
    end
    
    # Validation checks
    if candidate_id && 
       candidate_id != last_meme_url && 
       is_valid_meme?(candidate) &&
       candidate_subreddit != session[:last_subreddit]
      new_meme = candidate
      break
    end
    attempts += 1
  end

  # Fallback: try random pool if nothing found in primary pool
  if new_meme.nil? && user_id
    memes = random_memes_pool
    attempts = 0
    max_attempts = [memes.size, 30].min
    
    while attempts < max_attempts
      candidate = memes.sample
      candidate_id = candidate["url"] || candidate["file"]
      candidate_subreddit = candidate["subreddit"]&.downcase
      
      if candidate_id && 
         candidate_id != last_meme_url && 
         is_valid_meme?(candidate) &&
         candidate_subreddit != session[:last_subreddit]
        new_meme = candidate
        break
      end
      attempts += 1
    end
  end

  return nil unless new_meme

  # Normalize meme data
  meme_identifier = new_meme["url"] || new_meme["file"]
  new_meme["url"] = meme_identifier if !new_meme["url"]
  new_meme["permalink"] ||= ""
  
  # Track view in meme_stats
  meme_title = new_meme["title"] || "Unknown"
  meme_subreddit = new_meme["subreddit"] || "local"
  DB.execute(
    "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
    [meme_identifier, meme_title, meme_subreddit]
  ) rescue nil
  
  # Update session history
  session[:meme_history] << meme_identifier
  session[:meme_history] = session[:meme_history].last(10)  # Hard cap: 50 (reduced from 100)
  session[:last_subreddit] = meme_subreddit&.downcase

  # Track exposure for analytics and spaced repetition
  if user_id
    DB.execute(
      "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
      [user_id, meme_identifier]
    ) rescue nil
  end

  new_meme
end

# Update user preference when they like a meme
def update_user_preference(user_id, subreddit)
  return unless user_id && subreddit
  
  subreddit = subreddit.downcase
  DB.execute(
    "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, 1.0, 1) ON CONFLICT(user_id, subreddit) DO UPDATE SET preference_score = preference_score + 0.2, times_liked = times_liked + 1, last_updated = CURRENT_TIMESTAMP",
    [user_id, subreddit]
  ) rescue nil
end

# Spaced repetition - allow re-showing memes after decay
def should_exclude_from_exposure(user_id, meme_url)
  return false unless user_id
  
  begin
    exposure = DB.execute(
      "SELECT last_shown, shown_count FROM user_meme_exposure WHERE user_id = ? AND meme_url = ?",
      [user_id, meme_url]
    ).first
    
    return false unless exposure
    return false if exposure.nil?
    
    last_shown_str = exposure["last_shown"].to_s.strip
    return false if last_shown_str.empty?
    
    last_shown = Time.parse(last_shown_str) rescue nil
    return false unless last_shown.is_a?(Time)
    
    shown_count_val = exposure["shown_count"]
    return false if shown_count_val.nil?
    
    shown_count = shown_count_val.to_i
    hours_to_wait = 4 ** (shown_count - 1)
    
    current_time = Time.now
    return false unless current_time.is_a?(Time)
    
    time_diff_seconds = (current_time.to_i - last_shown.to_i).to_f
    time_since_shown = time_diff_seconds / 3600.0
    
    time_since_shown < hours_to_wait
  rescue => e
    AppLogger.error("Error in should_exclude_from_exposure: #{e.class}: #{e.message}")
    false
  end
end

# Validate meme before display
def is_valid_meme?(meme)
  return false unless meme.is_a?(Hash)
  
  if meme["file"]
    File.exist?(File.join("public", meme["file"]))
  elsif meme["url"]
    meme["url"].match?(/^https?:\/\//)
  else
    false
  end
end

# Get memes from cache or MEMES (thread-safe) - MIGRATED TO RedisService (Phase 3 Week 1)
def get_cached_memes
  # Use RedisService.fetch with automatic fallback to memory cache
  memes = RedisService.fetch("memes:latest", ttl: 300) do
    # Fallback: get from memory cache or static data
    MEME_CACHE.get(:memes) || MEMES
  end

  # Filter out invalid memes
  memes.reject! do |m|
    file_missing = m["file"] && !File.exist?(File.join(settings.public_folder, m["file"]))
    url_invalid  = m["url"] && !m["url"].match?(/^https?:\/\//)
    file_missing || url_invalid
  end

  # Update memory cache
  MEME_CACHE.set(:memes, memes)
  memes
rescue => e
  AppLogger.error("❌ get_cached_memes error: #{e.class} - #{e.message}")
  MEME_CACHE.get(:memes) || MEMES
end

# Phase 1: Weighted random selection by score
def weighted_random_select(memes)
  return nil if memes.empty?
  
  # Calculate weights: score = sqrt(likes * 2 + views)
  weights = memes.map do |m|
    score = Math.sqrt((m["likes"].to_i * 2 + m["views"].to_i).to_f)
    [score, 0.1].max  # Minimum weight of 0.1 for unknown memes
  end
  
  total_weight = weights.sum
  return memes.sample if total_weight == 0
  
  # Normalize weights and select
  r = rand * total_weight
  cumulative = 0
  memes.each_with_index do |meme, idx|
    cumulative += weights[idx]
    return meme if cumulative >= r
  end
  
  memes.last
end

# Get likes safely - MIGRATED TO RedisService (Phase 3 Week 1)
def get_meme_likes(url)
  return 0 unless url
  
  # Use RedisService.fetch with automatic DB fallback
  RedisService.fetch("meme:likes:#{url}", ttl: 300) do
    # Fallback: query database if Redis unavailable or cache miss
    row = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [url]).first
    row ? (row["likes"] || row[:likes] || row.values.first).to_i : 0
  end
end

# Toggle like for meme (only count once per session)
def toggle_like(url, liked_now, session)
  return 0 unless url
  
  session[:meme_like_counts] ||= {}
  was_liked_before = session[:meme_like_counts][url] || false
  user_id = session[:user_id]
  
  # Only update DB on first like/unlike transition
  if liked_now && !was_liked_before
    # First time liking in this session
    # Update global meme_stats
    DB.execute("INSERT INTO meme_stats (url, likes) VALUES (?, 0) ON CONFLICT(url) DO NOTHING", [url])
    DB.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])

    # Update user-specific meme_stats (if user logged in)
    if user_id
      DB.execute(
        "INSERT INTO user_meme_stats (user_id, meme_url, liked, liked_at) VALUES (?, ?, 1, CURRENT_TIMESTAMP) ON CONFLICT(user_id, meme_url) DO NOTHING",
        [user_id, url]
      )
      DB.execute(
        "UPDATE user_meme_stats SET liked = 1, liked_at = CURRENT_TIMESTAMP, unliked_at = NULL, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND meme_url = ?",
        [user_id, url]
      )
      
      # GAMIFICATION: Award XP for liking + update leaderboard
      begin
        xp_result = add_xp(user_id, :like_meme)
        session[:last_xp_gain] = xp_result if xp_result
        update_weekly_leaderboard(user_id, 1)
      rescue => e
        AppLogger.error("⚠️ XP/Leaderboard error: #{e.message}")
      end
    end
    session[:meme_like_counts][url] = true
  elsif !liked_now && was_liked_before
    # Unliking after having liked in this session
    DB.execute("UPDATE meme_stats SET likes = likes - 1, updated_at = CURRENT_TIMESTAMP WHERE url = ? AND likes > 0", [url])
    
    # Update user-specific meme_stats (if user logged in)
    if user_id
      DB.execute(
        "UPDATE user_meme_stats SET liked = 0, unliked_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND meme_url = ?",
        [user_id, url]
      )
    end
    session[:meme_like_counts][url] = false
  end

  likes = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [url]).first&.dig("likes").to_i
  RedisService.set("meme:likes:#{url}", likes, ttl: 300)  # MIGRATED: 5 min cache (Phase 3 Week 1)
  likes
end

# Flatten memes from YAML structure
def flatten_memes
  return [] unless MEMES.is_a?(Hash)
  MEMES.values.flatten.compact
end

# Safely execute DB queries
def safe_db_exec(query, params = [])
  return nil unless defined?(DB) && DB
  DB.execute(query, params)
rescue => e
  AppLogger.error("DB Error: #{e.message}")
  nil
end

# Pre-validate image URL (HEAD request to check if accessible)
def is_image_accessible?(url)
  return false unless url&.match?(/^https?:\/\//)
  
  begin
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 5, open_timeout: 5) do |http|
      http.head(uri.request_uri)
    end
    
    # Check if response indicates accessible image
    response.code == "200" && response["Content-Type"]&.include?("image")
  rescue
    false
  end
end

# Track broken image URL
def report_broken_image(url)
  return unless url
  
  begin
    DB.execute(
      "INSERT INTO broken_images (url, failure_count) VALUES (?, 1) ON CONFLICT(url) DO UPDATE SET failure_count = failure_count + 1, last_failed_at = CURRENT_TIMESTAMP",
      [url]
    )
  rescue => e
    AppLogger.error("Error tracking broken image: #{e.message}")
  end
end

# Check if URL is known to be broken
def is_image_broken?(url)
  return false unless url
  
  begin
    result = DB.execute("SELECT failure_count FROM broken_images WHERE url = ?", [url]).first
    result && result["failure_count"].to_i >= 2
  rescue
    false
  end
end

# Get next valid meme (skip broken URLs)
def get_next_valid_meme
  memes = random_memes_pool
  return nil if memes.empty?

  session[:meme_history] ||= []
  last_meme_url = session[:meme_history].last

  # Try to find a meme with working image
  attempts = 0
  max_attempts = [memes.size, 30].min
  
  while attempts < max_attempts
    candidate = memes.sample
    candidate_id = candidate["url"] || candidate["file"]
    
    # Skip if already shown or image is broken
    if candidate_id != last_meme_url && is_valid_meme?(candidate) && !is_image_broken?(candidate_id)
      meme_identifier = candidate_id
      session[:meme_history] << meme_identifier
      session[:meme_history] = session[:meme_history].last(30)
      return candidate
    end
    attempts += 1
  end

  nil
end

# Smart media rendering helpers
def render_meme_with_smart_fallback(meme_data, options = {})
  SmartMediaRendererService.render_with_smart_fallback(meme_data, options)
end

def media_placeholder_styles
  SmartMediaRendererService.placeholder_styles
end

# Meme Placeholder helpers (SEO-optimized)
def meme_placeholder
  PlaceholderImageService.get_placeholder
end

def render_meme_placeholder(options = {})
  PlaceholderImageService.render_html(options)
end

def meme_placeholder_alt_text(context: 'meme', additional_info: nil)
  PlaceholderImageService.generate_alt_text(context: context, additional_info: additional_info)
end

def meme_placeholder_og_tags(page_context = {})
  PlaceholderImageService.generate_og_meta_tags(page_context)
end

def meme_placeholder_styles
  PlaceholderImageService.generate_styles
end

def meme_placeholder_preload_tag
  PlaceholderImageService.generate_preload_tag
end

# Legacy aliases for backward compatibility
alias_method :tattoo_annie_placeholder, :meme_placeholder
alias_method :render_tattoo_annie, :render_meme_placeholder
alias_method :tattoo_annie_alt_text, :meme_placeholder_alt_text
alias_method :tattoo_annie_og_tags, :meme_placeholder_og_tags
alias_method :tattoo_annie_styles, :meme_placeholder_styles
alias_method :tattoo_annie_preload_tag, :meme_placeholder_preload_tag

# Check if meme has valid media URL
def has_valid_media?(meme)
  return false unless meme.is_a?(Hash)
  
  url = meme["url"] || meme["file"]
  return false unless url.is_a?(String) && !url.strip.empty?
  
  # Remote URLs: Accept all valid HTTP/HTTPS URLs (API memes)
  if url.match?(/^https?:\/\//)
    # Reject Reddit comment/post URLs (these would show fallback images)
    return false if url.include?('/r/') && url.include?('/comments/')
    
    # Accept all other HTTP/HTTPS URLs - these are API memes from Reddit
    # This includes:
    # - Direct image URLs (i.redd.it, i.imgur.com, etc.)
    # - Preview URLs (preview.redd.it)
    # - Gallery URLs with media metadata
    # - URLs with preview data in the meme object
    return true
  end
  
  # Local files: check existence (handles both relative and absolute paths)
  begin
    # Normalize path (add leading slash if not present)
    normalized_path = url.start_with?('/') ? url : "/#{url}"
    public_folder = defined?(settings) && settings.respond_to?(:public_folder) ? settings.public_folder : 'public'
    file_path = File.join(public_folder, normalized_path)
    return File.exist?(file_path)
  rescue => e
    AppLogger.error("⚠️  [VALIDATION] Error checking local file #{url}: #{e.message}")
    return false
  end
end
end
