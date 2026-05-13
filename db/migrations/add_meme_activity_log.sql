-- Migration: Add meme_activity_log table for accurate time-based metrics
-- Date: May 13, 2026
-- Purpose: Track individual view and like events with timestamps for accurate period filtering

-- Create activity log table
CREATE TABLE IF NOT EXISTS meme_activity_log (
  id SERIAL PRIMARY KEY,
  meme_url TEXT NOT NULL,
  activity_type VARCHAR(20) NOT NULL, -- 'view', 'like', 'unlike'
  user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  session_id VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for fast querying
CREATE INDEX IF NOT EXISTS idx_activity_log_created_at ON meme_activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_meme_url ON meme_activity_log(meme_url);
CREATE INDEX IF NOT EXISTS idx_activity_log_type_date ON meme_activity_log(activity_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_url_type_date ON meme_activity_log(meme_url, activity_type, created_at DESC);

-- Add created_at to meme_stats for tracking when meme was first seen
ALTER TABLE meme_stats ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

-- Backfill created_at with updated_at for existing records (best estimate we have)
UPDATE meme_stats SET created_at = updated_at WHERE created_at IS NULL;

-- Create materialized view for fast daily metrics (optional optimization)
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_meme_metrics AS
SELECT 
  DATE(created_at) as metric_date,
  COUNT(*) FILTER (WHERE activity_type = 'view') as total_views,
  COUNT(*) FILTER (WHERE activity_type = 'like') as total_likes,
  COUNT(*) FILTER (WHERE activity_type = 'unlike') as total_unlikes,
  COUNT(DISTINCT meme_url) as unique_memes,
  COUNT(DISTINCT user_id) as unique_users
FROM meme_activity_log
GROUP BY DATE(created_at)
ORDER BY metric_date DESC;

-- Create index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_metrics_date ON daily_meme_metrics(metric_date);

-- Note: Refresh materialized view with: REFRESH MATERIALIZED VIEW CONCURRENTLY daily_meme_metrics;
