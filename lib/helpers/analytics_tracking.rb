# Analytics Tracking Helper
# Extracted from app.rb to eliminate code duplication (P0 Fix)

module AnalyticsTracking
  def track_meme_view_async(meme, user_id = nil)
    return unless ANALYTICS_POOL && meme
    
    ANALYTICS_POOL.post do
      begin
        meme_identifier = meme["url"] || meme["file"]
        return unless meme_identifier
        
        # Track view in meme_stats
        DB.execute(
          "INSERT INTO meme_stats (url, title, subreddit, views, likes) 
           VALUES (?, ?, ?, 1, 0) 
           ON CONFLICT(url) DO UPDATE SET 
             views = views + 1, 
             updated_at = CURRENT_TIMESTAMP",
          [meme_identifier, meme["title"] || "Unknown", meme["subreddit"] || "local"]
        )
        
        # Track user exposure for spaced repetition
        if user_id
          DB.execute(
            "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) 
             VALUES (?, ?, 1) 
             ON CONFLICT(user_id, meme_url) DO UPDATE SET 
               shown_count = user_meme_exposure.shown_count + 1, 
               last_shown = CURRENT_TIMESTAMP",
            [user_id, meme_identifier]
          )
        end
      rescue => e
        AppLogger.error("Background analytics tracking failed", 
          error: e.message, 
          meme: meme_identifier,
          backtrace: e.backtrace.first(5)
        )
        # Re-raise if this is a critical error that needs alerting
        raise if e.is_a?(PG::ConnectionBad) || e.is_a?(Redis::ConnectionError)
      end
    end
  end
end
