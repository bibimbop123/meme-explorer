-- P2 Performance Indexes
-- Optimizes trending, search, and leaderboard queries
-- Generated: 2026-06-26 00:01:17 -0500

-- For trending score calculations (used in TrendingService)
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending_calc 
  ON meme_stats(updated_at DESC, likes DESC, views DESC) 
  WHERE updated_at >= CURRENT_TIMESTAMP - INTERVAL '48 hours';

-- For search relevance scoring
CREATE INDEX IF NOT EXISTS idx_meme_stats_title_gin 
  ON meme_stats USING gin(to_tsvector('english', title));

-- For leaderboard window function queries
CREATE INDEX IF NOT EXISTS idx_users_leaderboard_rank 
  ON users(level DESC, xp DESC, id) 
  WHERE role != 'admin';

-- For category-based trending
CREATE INDEX IF NOT EXISTS idx_meme_stats_category_trending 
  ON meme_stats(subreddit, updated_at DESC, likes DESC)
  WHERE updated_at >= CURRENT_TIMESTAMP - INTERVAL '48 hours';

-- For user engagement calculations
CREATE INDEX IF NOT EXISTS idx_users_engagement 
  ON users(total_likes_given, total_memes_saved, streak_days)
  WHERE role != 'admin';

-- Composite index for common query patterns
CREATE INDEX IF NOT EXISTS idx_meme_stats_hot 
  ON meme_stats(updated_at, likes, views) 
  WHERE views > 0 AND likes > 0;
