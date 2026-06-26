-- P0 Critical Indexes - Performance Fix
-- Generated: 2026-06-25 23:50:05 -0500

-- For admin role checks (high frequency)
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- For meme creation/sorting queries
CREATE INDEX IF NOT EXISTS idx_meme_stats_created_at ON meme_stats(created_at);
CREATE INDEX IF NOT EXISTS idx_meme_stats_updated_at ON meme_stats(updated_at);

-- For spaced repetition algorithm
CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_last_shown 
  ON user_meme_exposure(last_shown) WHERE last_shown IS NOT NULL;

-- Composite index for user exposure queries
CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_user_last_shown 
  ON user_meme_exposure(user_id, last_shown);

-- For saved memes sorting
CREATE INDEX IF NOT EXISTS idx_saved_memes_saved_at ON saved_memes(saved_at);

-- For trending queries (likes + views scoring)
CREATE INDEX IF NOT EXISTS idx_meme_stats_engagement_score 
  ON meme_stats((likes * 2 + views)) WHERE likes > 0 OR views > 0;
