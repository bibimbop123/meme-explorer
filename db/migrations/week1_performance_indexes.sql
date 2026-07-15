-- ============================================
-- WEEK 1 PERFORMANCE INDEXES
-- ============================================
-- Date: July 15, 2026
-- Purpose: Speed up critical queries by 40%+

-- Index 1: Composite index for meme fetching
-- Speeds up: SELECT * FROM meme_stats WHERE subreddit = ? ORDER BY views DESC
CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit_views_failure 
  ON meme_stats(subreddit, views DESC, failure_count);

-- Index 2: Trending memes lookup
-- Speeds up: SELECT * FROM meme_stats WHERE failure_count < 3 ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending
  ON meme_stats(created_at DESC, likes DESC) 
  WHERE failure_count < 3;

-- Index 3: User-meme lookups (fix N+1 queries)
-- Speeds up: SELECT * FROM user_meme_stats WHERE user_id = ? AND meme_url = ?
CREATE INDEX IF NOT EXISTS idx_user_meme_lookup
  ON user_meme_stats(user_id, meme_url);

-- Index 4: Liked memes lookup
CREATE INDEX IF NOT EXISTS idx_user_meme_liked
  ON user_meme_stats(user_id, liked)
  WHERE liked = true;

-- Index 5: Saved memes lookup  
CREATE INDEX IF NOT EXISTS idx_user_meme_saved
  ON user_meme_stats(user_id, saved)
  WHERE saved = true;

-- Analyze tables for query planner
ANALYZE meme_stats;
ANALYZE user_meme_stats;
