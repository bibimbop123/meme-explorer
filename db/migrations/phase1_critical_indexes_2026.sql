-- Phase 1 Critical Database Indexes
-- Based on COMPREHENSIVE_AUDIT_JUNE_26_2026.md recommendations
-- Expected Impact: 50-80% query performance improvement

-- ==========================================
-- MEME_STATS TABLE INDEXES
-- ==========================================

-- Critical for trending/recent queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_meme_stats_created_at 
  ON meme_stats(created_at DESC);

-- Composite index for leaderboard queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_meme_stats_engagement
  ON meme_stats((likes * 2 + views) DESC, created_at DESC);

-- JSONB preview data indexing
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_meme_stats_preview
  ON meme_stats USING GIN (preview jsonb_path_ops)
  WHERE preview IS NOT NULL;

-- ==========================================
-- USER_MEME_EXPOSURE TABLE INDEXES
-- ==========================================

-- Critical for meme selection algorithm
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_meme_exposure_compound
  ON user_meme_exposure(user_id, last_shown DESC);

-- For exposure count queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_meme_exposure_count
  ON user_meme_exposure(user_id, shown_count);

-- ==========================================
-- SAVED_MEMES TABLE INDEXES
-- ==========================================

-- User's saved memes with recency
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_saved_memes_user_created
  ON saved_memes(user_id, saved_at DESC);

-- Lookup by meme URL
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_saved_memes_url
  ON saved_memes(meme_url);

-- ==========================================
-- USERS TABLE INDEXES
-- ==========================================

-- Partial index for admin users (fast role checks)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_role_admin
  ON users(role) 
  WHERE role = 'admin';

-- Active users index (30-day window)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_active
  ON users(updated_at DESC) 
  WHERE updated_at > NOW() - INTERVAL '30 days';

-- Username lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_username_lower
  ON users(LOWER(username));

-- ==========================================
-- LEADERBOARD TABLE INDEXES
-- ==========================================

-- Leaderboard ranking queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_leaderboard_score
  ON leaderboard(score DESC, updated_at DESC);

-- User's leaderboard position
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_leaderboard_user
  ON leaderboard(user_id, score DESC);

-- ==========================================
-- MEME_ACTIVITY_LOG TABLE INDEXES
-- ==========================================

-- Recent activity queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activity_log_recent
  ON meme_activity_log(created_at DESC, user_id);

-- User activity history
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activity_log_user
  ON meme_activity_log(user_id, created_at DESC);

-- Activity type filtering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activity_log_type
  ON meme_activity_log(activity_type, created_at DESC);

-- ==========================================
-- PUSH_SUBSCRIPTIONS TABLE INDEXES
-- ==========================================

-- User's push subscriptions
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_push_subscriptions_user
  ON push_subscriptions(user_id, created_at DESC);

-- Active subscriptions
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_push_subscriptions_active
  ON push_subscriptions(endpoint)
  WHERE endpoint IS NOT NULL;

-- ==========================================
-- QUALITY_SIGNALS TABLE INDEXES (if exists)
-- ==========================================

-- Quality score lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_quality_signals_meme
  ON quality_signals(meme_url, quality_score DESC)
  WHERE quality_signals EXISTS;

-- ==========================================
-- ANALYSIS & MONITORING
-- ==========================================

-- Show index sizes
SELECT
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;

-- Show missing indexes (queries without indexes)
SELECT
  schemaname,
  tablename,
  attname,
  n_distinct,
  correlation
FROM pg_stats
WHERE schemaname = 'public'
  AND n_distinct > 100
  AND correlation < 0.1
ORDER BY n_distinct DESC;
