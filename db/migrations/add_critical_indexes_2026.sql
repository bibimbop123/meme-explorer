-- Critical Index Additions for Performance
-- Generated: May 19, 2026
-- Part of: Phase 1 Critical Fixes

-- Add index on meme_stats.updated_at for time-based queries
CREATE INDEX IF NOT EXISTS idx_meme_stats_updated_at_desc 
ON meme_stats(updated_at DESC);

-- Add composite index for subreddit + engagement queries
CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit_engagement 
ON meme_stats(subreddit, likes DESC, views DESC);

-- Add composite index for user_meme_exposure lookups
CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_lookup 
ON user_meme_exposure(user_id, last_shown, shown_count);

-- Add index for user_meme_stats user lookups
CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_lookup 
ON user_meme_stats(user_id, liked, updated_at DESC);

-- Add index for saved_memes by saved_at for chronological queries
CREATE INDEX IF NOT EXISTS idx_saved_memes_chronological 
ON saved_memes(user_id, saved_at DESC);

-- Add index for meme_activity_log time-based analytics
CREATE INDEX IF NOT EXISTS idx_meme_activity_log_time 
ON meme_activity_log(created_at DESC, activity_type);

-- Add index for meme_activity_log meme lookups
CREATE INDEX IF NOT EXISTS idx_meme_activity_log_meme 
ON meme_activity_log(meme_url, activity_type, created_at DESC);

-- Add index for failure_count filtering (broken images)
CREATE INDEX IF NOT EXISTS idx_meme_stats_failure_count 
ON meme_stats(failure_count) WHERE failure_count IS NOT NULL;
