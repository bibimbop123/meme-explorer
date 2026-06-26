# Session Data Optimizer
# P1 Fix: Reduce session bloat and move data to Redis/DB

module SessionOptimizer
  # Maximum items to keep in session
  MAX_HISTORY_ITEMS = 20  # Reduced from 50/100
  MAX_LIKE_COUNTS = 50
  
  # Keys that should be stored in Redis instead of session cookie
  REDIS_KEYS = [:meme_history, :meme_like_counts, :last_subreddit]
  
  # Move large session data to Redis
  def optimize_session_storage(session, user_id)
    return unless user_id
    
    REDIS_KEYS.each do |key|
      next unless session[key]
      
      # Store in Redis with user-specific key
      redis_key = "user:\#{user_id}:session:\#{key}"
      safe_redis_write(redis_key, session[key].to_json, ttl: 86400)  # 24 hours
      
      # Remove from session cookie
      session.delete(key)
    end
  end
  
  # Retrieve session data from Redis
  def get_session_data(user_id, key)
    return nil unless user_id
    
    redis_key = "user:\#{user_id}:session:\#{key}"
    begin
      data = RedisService.get(redis_key)
      data ? JSON.parse(data) : nil
    rescue Redis::BaseError, JSON::ParserError => e
      AppLogger.warn("Failed to retrieve session data from Redis", key: key, error: e.message)
      nil
    end
  end
  
  # Cap session history size
  def cap_session_history!(session, key, max_items = MAX_HISTORY_ITEMS)
    return unless session[key].is_a?(Array)
    session[key] = session[key].last(max_items) if session[key].size > max_items
  end
  
  # Clean up old session keys
  def cleanup_session!(session)
    # Remove nil and empty values
    session.delete_if { |_k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
    
    # Cap array sizes
    cap_session_history!(session, :meme_history)
    
    # Cap hash sizes
    if session[:meme_like_counts].is_a?(Hash) && session[:meme_like_counts].size > MAX_LIKE_COUNTS
      # Keep only most recent likes
      session[:meme_like_counts] = session[:meme_like_counts].to_a.last(MAX_LIKE_COUNTS).to_h
    end
  end
end
