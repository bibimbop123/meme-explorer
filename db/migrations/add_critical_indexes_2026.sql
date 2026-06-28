-- Critical Index Additions (fixed: meme_activity_log now exists)
CREATE INDEX IF NOT EXISTS idx_meme_stats_updated_at_desc ON meme_stats(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit_engagement ON meme_stats(subreddit, likes DESC, views DESC);
CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_lookup ON user_meme_exposure(user_id, last_shown, shown_count);
CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_lookup ON user_meme_stats(user_id, liked, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_saved_memes_chronological ON saved_memes(user_id, saved_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_activity_log_time ON meme_activity_log(created_at DESC, activity_type);
CREATE INDEX IF NOT EXISTS idx_meme_activity_log_meme ON meme_activity_log(meme_url, activity_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_failure_count ON meme_stats(failure_count) WHERE failure_count IS NOT NULL;
