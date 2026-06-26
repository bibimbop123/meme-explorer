-- Phase 2 Performance Optimization Migration
-- Date: June 26, 2026
-- Goal: Optimize queries and add materialized views for <150ms response times

-- ============================================================================
-- PART 1: Add Missing Indexes (From Audit)
-- ============================================================================

-- Memes table optimization
CREATE INDEX IF NOT EXISTS idx_memes_category_created ON memes(category, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_memes_subreddit_created ON memes(subreddit, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_memes_quality_score ON memes(quality_score DESC) WHERE quality_score IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_memes_composite_trending ON memes(created_at DESC, likes, views);

-- User activity optimization
CREATE INDEX IF NOT EXISTS idx_user_likes_user_created ON user_likes(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_likes_meme_created ON user_likes(meme_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_saved_memes_user_created ON saved_memes(user_id, created_at DESC);

-- Gamification indexes
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_earned ON user_achievements(user_id, earned_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_streaks_user_active ON user_streaks(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_leaderboard_period_score ON leaderboard_scores(period, score DESC);

-- Activity tracking
CREATE INDEX IF NOT EXISTS idx_meme_activity_log_created ON meme_activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_activity_log_user_action ON meme_activity_log(user_id, action_type, created_at DESC);

-- ============================================================================
-- PART 2: Materialized Views for Trending Data
-- ============================================================================

-- Trending Memes (hourly refresh)
CREATE MATERIALIZED VIEW IF NOT EXISTS trending_memes_hourly AS
SELECT 
  m.id,
  m.reddit_id,
  m.title,
  m.url,
  m.category,
  m.subreddit,
  m.created_at,
  COALESCE(m.likes, 0) as likes,
  COALESCE(m.views, 0) as views,
  COALESCE(m.shares, 0) as shares,
  -- Trending score calculation
  ((COALESCE(m.likes, 0) * 2.0) + COALESCE(m.views, 0) + (COALESCE(m.shares, 0) * 3.0)) / 
    POWER((EXTRACT(EPOCH FROM (NOW() - m.created_at)) / 3600.0 + 2), 1.5) as trending_score,
  m.quality_score
FROM memes m
WHERE 
  m.created_at > NOW() - INTERVAL '48 hours'
  AND m.is_deleted = FALSE
ORDER BY trending_score DESC
LIMIT 1000;

-- Create index on materialized view
CREATE INDEX IF NOT EXISTS idx_trending_hourly_score ON trending_memes_hourly(trending_score DESC);
CREATE INDEX IF NOT EXISTS idx_trending_hourly_category ON trending_memes_hourly(category, trending_score DESC);

-- ============================================================================
-- Leaderboard Aggregation (hourly refresh)
CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_hourly AS
SELECT 
  u.id as user_id,
  u.username,
  u.avatar_url,
  COALESCE(SUM(l.points), 0) as total_points,
  COUNT(DISTINCT ul.meme_id) as memes_liked,
  COUNT(DISTINCT sm.meme_id) as memes_saved,
  COALESCE(us.current_streak, 0) as streak_days,
  COALESCE(ua.achievement_count, 0) as achievements_earned,
  ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.points), 0) DESC) as rank
FROM users u
LEFT JOIN leaderboard_scores l ON u.id = l.user_id AND l.period = 'all_time'
LEFT JOIN user_likes ul ON u.id = ul.user_id
LEFT JOIN saved_memes sm ON u.id = sm.user_id
LEFT JOIN user_streaks us ON u.id = us.user_id AND us.is_active = TRUE
LEFT JOIN (
  SELECT user_id, COUNT(*) as achievement_count 
  FROM user_achievements 
  GROUP BY user_id
) ua ON u.id = ua.user_id
WHERE u.is_active = TRUE
GROUP BY u.id, u.username, u.avatar_url, us.current_streak, ua.achievement_count
ORDER BY total_points DESC
LIMIT 500;

CREATE INDEX IF NOT EXISTS idx_leaderboard_hourly_rank ON leaderboard_hourly(rank);
CREATE INDEX IF NOT EXISTS idx_leaderboard_hourly_user ON leaderboard_hourly(user_id);

-- ============================================================================
-- Category Stats (daily refresh)
CREATE MATERIALIZED VIEW IF NOT EXISTS category_stats_daily AS
SELECT 
  category,
  COUNT(*) as meme_count,
  COUNT(DISTINCT subreddit) as subreddit_count,
  AVG(quality_score) as avg_quality,
  SUM(likes) as total_likes,
  SUM(views) as total_views,
  MAX(created_at) as last_updated
FROM memes
WHERE 
  created_at > NOW() - INTERVAL '30 days'
  AND is_deleted = FALSE
GROUP BY category;

CREATE INDEX IF NOT EXISTS idx_category_stats_category ON category_stats_daily(category);

-- ============================================================================
-- PART 3: Query Optimization Functions
-- ============================================================================

-- Function to refresh trending view (called by cron/worker)
CREATE OR REPLACE FUNCTION refresh_trending_memes()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY trending_memes_hourly;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh leaderboard view
CREATE OR REPLACE FUNCTION refresh_leaderboard()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_hourly;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh category stats
CREATE OR REPLACE FUNCTION refresh_category_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY category_stats_daily;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 4: Query Timeouts and Connection Pooling
-- ============================================================================

-- Set statement timeout for expensive queries (5 seconds max)
ALTER DATABASE meme_explorer SET statement_timeout = '5s';

-- Optimize for small, frequent queries
ALTER DATABASE meme_explorer SET random_page_cost = 1.1;
ALTER DATABASE meme_explorer SET effective_cache_size = '4GB';

-- ============================================================================
-- PART 5: Partitioning for Activity Log (Future Scaling)
-- ============================================================================

-- Prepare activity log for partitioning by month
-- (Would require migrating existing data, shown as example)
-- CREATE TABLE meme_activity_log_partitioned (
--   LIKE meme_activity_log INCLUDING ALL
-- ) PARTITION BY RANGE (created_at);

-- ============================================================================
-- PART 6: Analytics Aggregation Tables
-- ============================================================================

-- Daily meme stats aggregation
CREATE TABLE IF NOT EXISTS meme_stats_daily (
  id SERIAL PRIMARY KEY,
  meme_id INTEGER REFERENCES memes(id),
  stat_date DATE NOT NULL,
  views INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0,
  shares INTEGER DEFAULT 0,
  saves INTEGER DEFAULT 0,
  unique_viewers INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(meme_id, stat_date)
);

CREATE INDEX idx_meme_stats_daily_meme_date ON meme_stats_daily(meme_id, stat_date DESC);
CREATE INDEX idx_meme_stats_daily_date ON meme_stats_daily(stat_date DESC);

-- User engagement summary
CREATE TABLE IF NOT EXISTS user_engagement_daily (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  stat_date DATE NOT NULL,
  memes_viewed INTEGER DEFAULT 0,
  memes_liked INTEGER DEFAULT 0,
  memes_shared INTEGER DEFAULT 0,
  memes_saved INTEGER DEFAULT 0,
  time_spent_seconds INTEGER DEFAULT 0,
  sessions_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, stat_date)
);

CREATE INDEX idx_user_engagement_daily_user_date ON user_engagement_daily(user_id, stat_date DESC);

-- ============================================================================
-- PART 7: Cleanup and Optimization
-- ============================================================================

-- Analyze tables for query planner
ANALYZE memes;
ANALYZE users;
ANALYZE user_likes;
ANALYZE saved_memes;
ANALYZE meme_activity_log;
ANALYZE leaderboard_scores;

-- Vacuum tables to reclaim space
VACUUM ANALYZE memes;
VACUUM ANALYZE users;

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- To apply this migration:
-- psql $DATABASE_URL -f db/migrations/phase2_performance_optimization.sql

-- Recommended cron jobs (add to Sidekiq or system cron):
-- Every hour: SELECT refresh_trending_memes();
-- Every hour: SELECT refresh_leaderboard();
-- Every day: SELECT refresh_category_stats();
