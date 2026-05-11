-- Performance Indexes Migration
-- Created: May 11, 2026
-- Purpose: Add missing indexes identified in senior engineer code audit

-- Index for user_meme_exposure queries (spaced repetition)
CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_user_meme 
ON user_meme_exposure(user_id, meme_url);

-- Index for user_streaks queries (gamification)
CREATE INDEX IF NOT EXISTS idx_user_streaks_user_date 
ON user_streaks(user_id, last_visit_date);

-- Index for saved_memes queries (profile page)
CREATE INDEX IF NOT EXISTS idx_saved_memes_user_saved 
ON saved_memes(user_id, saved_at DESC);

-- Index for meme_stats trending queries
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending 
ON meme_stats((likes * 2 + views) DESC);

-- Index for meme_stats fresh queries
CREATE INDEX IF NOT EXISTS idx_meme_stats_fresh 
ON meme_stats(updated_at DESC);

-- Index for user_meme_stats queries
CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_liked 
ON user_meme_stats(user_id, liked, liked_at DESC);

-- Index for broken_images cleanup
CREATE INDEX IF NOT EXISTS idx_broken_images_cleanup 
ON broken_images(failure_count, first_failed_at);

-- Composite index for leaderboard queries
CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_week_rank 
ON weekly_leaderboard(week_number, rank);

VACUUM ANALYZE;
