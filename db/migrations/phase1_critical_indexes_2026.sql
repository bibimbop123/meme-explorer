-- Phase 1 Critical Indexes (fixed: removed IF NOT EXISTS from WHERE clause syntax error)
CREATE INDEX IF NOT EXISTS idx_phase1_meme_stats_subreddit ON meme_stats(subreddit);
CREATE INDEX IF NOT EXISTS idx_phase1_meme_stats_likes ON meme_stats(likes DESC);
CREATE INDEX IF NOT EXISTS idx_phase1_meme_stats_views ON meme_stats(views DESC);
CREATE INDEX IF NOT EXISTS idx_phase1_saved_memes_user ON saved_memes(user_id);
CREATE INDEX IF NOT EXISTS idx_phase1_user_exposure_user ON user_meme_exposure(user_id);
