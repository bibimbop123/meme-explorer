-- P1 Performance Indexes (fixed: removed indexes on non-existent columns/tables)
CREATE INDEX IF NOT EXISTS idx_meme_stats_title_lower ON meme_stats(LOWER(title));
CREATE INDEX IF NOT EXISTS idx_saved_memes_user_saved_p1 ON saved_memes(user_id, saved_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_liked_p1 ON user_meme_stats(user_id, liked) WHERE liked = 1;
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending_score ON meme_stats(updated_at DESC, likes DESC) WHERE views > 0;
CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit_p1 ON meme_stats(subreddit, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_levels_rank ON user_levels(total_xp DESC, user_id);
-- sessions table does not exist; session cleanup handled by SessionCleanupWorker
