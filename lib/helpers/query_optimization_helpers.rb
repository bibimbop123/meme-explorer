# frozen_string_literal: true

require_relative '../app_logger'

# Query Optimization Helpers
# Provides utilities to fix N+1 queries and optimize database access
# Week 3 Implementation - June 3, 2026

module QueryOptimizationHelpers
  class << self
    # Fetch memes with user data (prevents N+1)
    def fetch_memes_with_users(meme_urls)
      return [] if meme_urls.nil? || meme_urls.empty?
      
      placeholders = meme_urls.map { '?' }.join(',')
      
      DB.execute("
        SELECT 
          ms.*,
          u.id as creator_id,
          u.username as creator_username,
          u.reddit_username as creator_reddit_username
        FROM meme_stats ms
        LEFT JOIN user_meme_stats ums ON ms.url = ums.meme_url
        LEFT JOIN users u ON ums.user_id = u.id
        WHERE ms.url IN (#{placeholders})
      ", meme_urls)
    rescue => e
      AppLogger.error("Failed to fetch memes with users", 
        error: e.message,
        meme_count: meme_urls.length
      )
      []
    end
    
    # Fetch leaderboard with user details (prevents N+1)
    def fetch_leaderboard_with_users(limit: 50, week_start: nil)
      week_filter = week_start ? "AND wl.week_start = ?" : ""
      params = week_start ? [limit, week_start] : [limit]
      
      DB.execute("
        SELECT 
          wl.*,
          u.username,
          u.reddit_username,
          u.created_at as user_created_at
        FROM weekly_leaderboard wl
        JOIN users u ON wl.user_id = u.id
        WHERE 1=1 #{week_filter}
        ORDER BY wl.xp DESC
        LIMIT ?
      ", params)
    rescue => e
      AppLogger.error("Failed to fetch leaderboard", 
        error: e.message,
        limit: limit
      )
      []
    end
    
    # Fetch saved memes with stats (prevents N+1)
    def fetch_saved_memes_with_stats(user_id, limit: 50, offset: 0)
      DB.execute("
        SELECT 
          sm.*,
          COALESCE(ms.likes, 0) as meme_likes,
          COALESCE(ms.views, 0) as meme_views,
          ms.title as meme_title,
          ms.subreddit as meme_subreddit
        FROM saved_memes sm
        LEFT JOIN meme_stats ms ON sm.meme_url = ms.url
        WHERE sm.user_id = ?
        ORDER BY sm.saved_at DESC
        LIMIT ? OFFSET ?
      ", [user_id, limit, offset])
    rescue => e
      AppLogger.error("Failed to fetch saved memes", 
        error: e.message,
        user_id: user_id
      )
      []
    end
    
    # Fetch user preferences in bulk (prevents N+1)
    def fetch_user_preferences_bulk(user_ids)
      return {} if user_ids.nil? || user_ids.empty?
      
      placeholders = user_ids.map { '?' }.join(',')
      
      results = DB.execute("
        SELECT 
          user_id,
          subreddit,
          preference_score,
          times_liked
        FROM user_subreddit_preferences
        WHERE user_id IN (#{placeholders})
      ", user_ids)
      
      # Group by user_id
      results.group_by { |r| r['user_id'] }
    rescue => e
      AppLogger.error("Failed to fetch user preferences", 
        error: e.message,
        user_count: user_ids.length
      )
      {}
    end
    
    # Batch insert for better performance
    def batch_insert(table, records, batch_size: 100)
      return 0 if records.empty?
      
      inserted_count = 0
      
      records.each_slice(batch_size) do |batch|
        columns = batch.first.keys
        values_placeholders = batch.map { |_| "(#{columns.map { '?' }.join(', ')})" }.join(', ')
        values = batch.flat_map(&:values)
        
        DB.execute("
          INSERT INTO #{table} (#{columns.join(', ')})
          VALUES #{values_placeholders}
        ", values)
        
        inserted_count += batch.length
      end
      
      AppLogger.info("Batch insert completed", 
        table: table,
        records: inserted_count
      )
      
      inserted_count
    rescue => e
      AppLogger.error("Batch insert failed", 
        error: e.message,
        table: table,
        attempted_records: records.length
      )
      raise
    end
    
    # Get query execution stats (PostgreSQL)
    def explain_query(sql, params = [])
      return unless ENV['RACK_ENV'] == 'development'
      
      explained = DB.execute("EXPLAIN ANALYZE #{sql}", params)
      AppLogger.debug("Query plan", query: sql, plan: explained)
      explained
    rescue => e
      AppLogger.warn("Could not explain query", error: e.message)
      nil
    end
  end
end
