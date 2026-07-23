-- Critical Database Indexes for Performance
-- Week 1 Days 3-4: Database Optimization
-- Date: July 22, 2026

-- Drop indexes if they exist (idempotent)
DROP INDEX IF EXISTS idx_memes_created_at;
DROP INDEX IF EXISTS idx_memes_subreddit;
DROP INDEX IF EXISTS idx_memes_quality_score;
DROP INDEX IF EXISTS idx_memes_composite_trending;
DROP INDEX IF EXISTS idx_users_username;
DROP INDEX IF EXISTS idx_user_likes_composite;
DROP INDEX IF EXISTS idx_viewing_history_composite;
DROP INDEX IF EXISTS idx_sessions_user_id;
DROP INDEX IF EXISTS idx_sessions_expires_at;

-- Memes table indexes
-- For trending/recent queries
CREATE INDEX idx_memes_created_at ON memes(created_at DESC);

-- For subreddit filtering
CREATE INDEX idx_memes_subreddit ON memes(subreddit) WHERE subreddit IS NOT NULL;

-- For quality filtering
CREATE INDEX idx_memes_quality_score ON memes(quality_score DESC) WHERE quality_score IS NOT NULL;

-- Composite index for trending queries (most common query pattern)
CREATE INDEX idx_memes_composite_trending ON memes(created_at DESC, quality_score DESC)
  WHERE quality_score > 0.5;

-- Users table indexes
CREATE UNIQUE INDEX idx_users_username ON users(LOWER(username));

-- User_likes composite (user + meme lookup)
CREATE INDEX idx_user_likes_composite ON user_likes(user_id, meme_id);

-- Viewing history composite (for "seen" checks)
CREATE INDEX idx_viewing_history_composite ON viewing_history(user_id, meme_id, viewed_at DESC);

-- Sessions table indexes
CREATE INDEX idx_sessions_user_id ON sessions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at) WHERE expires_at > NOW();

-- Analyze tables to update statistics
ANALYZE memes;
ANALYZE users;
ANALYZE user_likes;
ANALYZE viewing_history;
ANALYZE sessions;
