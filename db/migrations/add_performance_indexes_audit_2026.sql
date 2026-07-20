-- Performance Optimization Indexes - July 19, 2026
-- Adds indexes for trending queries and common lookups

-- Trending memes by score and timestamp
CREATE INDEX IF NOT EXISTS idx_memes_score_created 
  ON memes(score DESC, created_at DESC);

-- Meme activity lookups by user
CREATE INDEX IF NOT EXISTS idx_meme_activity_user_created 
  ON meme_activity_log(user_id, created_at DESC);

-- Trending by category
CREATE INDEX IF NOT EXISTS idx_memes_category_score 
  ON memes(category, score DESC) 
  WHERE category IS NOT NULL;

-- User lookup by Reddit username (for auth)
CREATE INDEX IF NOT EXISTS idx_users_reddit_username 
  ON users(reddit_username);

-- Composite index for leaderboard queries
CREATE INDEX IF NOT EXISTS idx_users_points_username 
  ON users(points DESC, username);

-- Cover viewing history queries
CREATE INDEX IF NOT EXISTS idx_meme_activity_type_user 
  ON meme_activity_log(activity_type, user_id, created_at DESC);

-- Optimize saved memes lookup
CREATE INDEX IF NOT EXISTS idx_meme_activity_saved 
  ON meme_activity_log(user_id, meme_id) 
  WHERE activity_type = 'save';

ANALYZE;
