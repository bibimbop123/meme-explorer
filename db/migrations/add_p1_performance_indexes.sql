-- P1 Additional Performance Indexes
-- Generated: 2026-06-26 00:01:25 -0500

-- For search queries (case-insensitive title search)
CREATE INDEX IF NOT EXISTS idx_meme_stats_title_lower 
  ON meme_stats(LOWER(title));

-- For user-specific queries
CREATE INDEX IF NOT EXISTS idx_saved_memes_user_saved 
  ON saved_memes(user_id, saved_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_liked 
  ON user_meme_stats(user_id, liked) WHERE liked = 1;

-- For trending algorithm (composite scoring)
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending_score 
  ON meme_stats(updated_at DESC, likes DESC) 
  WHERE views > 0;

-- For subreddit filtering
CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit 
  ON meme_stats(subreddit, created_at DESC);

-- For leaderboard queries
CREATE INDEX IF NOT EXISTS idx_users_xp_level 
  ON users(level DESC, xp DESC) WHERE role != 'admin';

-- For session cleanup
CREATE INDEX IF NOT EXISTS idx_sessions_updated_at 
  ON sessions(updated_at) WHERE updated_at < NOW() - INTERVAL '7 days';
