-- iFunny-Style Features: Smart Pools, Collaborative Filtering, Session Learning
-- Migration adds tables for advanced recommendation engine

-- User interaction history for collaborative filtering
CREATE TABLE IF NOT EXISTS user_interactions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  session_id VARCHAR(255) NOT NULL,
  meme_id TEXT NOT NULL,
  meme_url TEXT NOT NULL,
  interaction_type VARCHAR(50) NOT NULL, -- 'view', 'like', 'skip', 'share', 'save'
  duration_seconds INTEGER DEFAULT 0,
  subreddit VARCHAR(255),
  pool_type VARCHAR(50), -- 'trending', 'fresh', 'vintage', 'random', 'serendipity'
  humor_type VARCHAR(100),
  engagement_rate FLOAT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_interactions_user_id ON user_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_session_id ON user_interactions(session_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_meme_id ON user_interactions(meme_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_type ON user_interactions(interaction_type);
CREATE INDEX IF NOT EXISTS idx_user_interactions_created_at ON user_interactions(created_at DESC);

-- User similarity matrix for collaborative filtering
CREATE TABLE IF NOT EXISTS user_similarity (
  id SERIAL PRIMARY KEY,
  user_id_a INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_id_b INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  similarity_score FLOAT NOT NULL DEFAULT 0.0, -- 0.0 to 1.0
  common_likes INTEGER DEFAULT 0,
  last_calculated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id_a, user_id_b)
);

CREATE INDEX IF NOT EXISTS idx_user_similarity_user_a ON user_similarity(user_id_a, similarity_score DESC);
CREATE INDEX IF NOT EXISTS idx_user_similarity_user_b ON user_similarity(user_id_b, similarity_score DESC);

-- Smart pool effectiveness tracking
CREATE TABLE IF NOT EXISTS pool_performance (
  id SERIAL PRIMARY KEY,
  pool_type VARCHAR(50) NOT NULL,
  date DATE NOT NULL,
  selections INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0,
  skips INTEGER DEFAULT 0,
  avg_duration FLOAT DEFAULT 0.0,
  engagement_rate FLOAT DEFAULT 0.0,
  user_satisfaction FLOAT DEFAULT 0.0, -- Calculated from interactions
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(pool_type, date)
);

CREATE INDEX IF NOT EXISTS idx_pool_performance_date ON pool_performance(date DESC);
CREATE INDEX IF NOT EXISTS idx_pool_performance_type ON pool_performance(pool_type);

-- Session learning data - tracks what users learn to like/dislike
CREATE TABLE IF NOT EXISTS session_learning (
  id SERIAL PRIMARY KEY,
  session_id VARCHAR(255) NOT NULL,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  learning_type VARCHAR(50) NOT NULL, -- 'subreddit_preference', 'humor_preference', 'time_preference'
  key VARCHAR(255) NOT NULL, -- subreddit name, humor type, time slot
  value FLOAT NOT NULL, -- preference score
  confidence FLOAT DEFAULT 0.5, -- How confident we are (0-1)
  sample_size INTEGER DEFAULT 1, -- Number of interactions
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(session_id, learning_type, key)
);

CREATE INDEX IF NOT EXISTS idx_session_learning_session ON session_learning(session_id);
CREATE INDEX IF NOT EXISTS idx_session_learning_user ON session_learning(user_id);
CREATE INDEX IF NOT EXISTS idx_session_learning_type ON session_learning(learning_type);

-- Meme recommendation scores (pre-calculated for performance)
CREATE TABLE IF NOT EXISTS meme_recommendations (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_id TEXT NOT NULL,
  meme_url TEXT NOT NULL,
  recommendation_score FLOAT NOT NULL,
  source VARCHAR(50) NOT NULL, -- 'collaborative', 'content_based', 'hybrid', 'pool'
  pool_type VARCHAR(50),
  calculated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '1 hour')
);

CREATE INDEX IF NOT EXISTS idx_meme_recs_user ON meme_recommendations(user_id, recommendation_score DESC);
CREATE INDEX IF NOT EXISTS idx_meme_recs_expires ON meme_recommendations(expires_at);

-- Content similarity matrix (for content-based filtering)
CREATE TABLE IF NOT EXISTS meme_similarity (
  id SERIAL PRIMARY KEY,
  meme_id_a TEXT NOT NULL,
  meme_id_b TEXT NOT NULL,
  similarity_score FLOAT NOT NULL, -- Based on title, subreddit, humor type
  similarity_type VARCHAR(50), -- 'title', 'subreddit', 'visual', 'hybrid'
  calculated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(meme_id_a, meme_id_b)
);

CREATE INDEX IF NOT EXISTS idx_meme_similarity_a ON meme_similarity(meme_id_a, similarity_score DESC);
CREATE INDEX IF NOT EXISTS idx_meme_similarity_b ON meme_similarity(meme_id_b, similarity_score DESC);

-- User engagement patterns (when they're most active, what they like at different times)
CREATE TABLE IF NOT EXISTS user_engagement_patterns (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  hour_of_day INTEGER NOT NULL CHECK (hour_of_day >= 0 AND hour_of_day < 24),
  day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week < 7),
  avg_session_length INTEGER DEFAULT 0, -- seconds
  avg_memes_per_session FLOAT DEFAULT 0.0,
  preferred_pool_type VARCHAR(50),
  engagement_rate FLOAT DEFAULT 0.0,
  sample_size INTEGER DEFAULT 0,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, hour_of_day, day_of_week)
);

CREATE INDEX IF NOT EXISTS idx_engagement_patterns_user ON user_engagement_patterns(user_id);

-- Algorithm A/B test results for pool optimization
CREATE TABLE IF NOT EXISTS algorithm_experiments (
  id SERIAL PRIMARY KEY,
  experiment_name VARCHAR(255) NOT NULL,
  variant VARCHAR(100) NOT NULL, -- 'control', 'test_a', 'test_b', etc.
  session_id VARCHAR(255) NOT NULL,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  pool_weights JSONB, -- Store pool weight configuration
  total_interactions INTEGER DEFAULT 0,
  total_likes INTEGER DEFAULT 0,
  total_skips INTEGER DEFAULT 0,
  avg_session_duration FLOAT DEFAULT 0.0,
  retention_score FLOAT DEFAULT 0.0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_algorithm_experiments_name ON algorithm_experiments(experiment_name);
CREATE INDEX IF NOT EXISTS idx_algorithm_experiments_variant ON algorithm_experiments(variant);
CREATE INDEX IF NOT EXISTS idx_algorithm_experiments_session ON algorithm_experiments(session_id);

-- Add engagement_rate column to meme_stats if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meme_stats' AND column_name = 'engagement_rate'
  ) THEN
    ALTER TABLE meme_stats ADD COLUMN engagement_rate FLOAT DEFAULT 0.0;
  END IF;
END $$;

-- Create materialized view for top collaborative recommendations (performance optimization)
CREATE MATERIALIZED VIEW IF NOT EXISTS top_collaborative_recommendations AS
SELECT 
  ui1.user_id as target_user_id,
  ui2.meme_id,
  COUNT(*) as recommendation_strength,
  AVG(CASE WHEN ui2.interaction_type = 'like' THEN 1.0 ELSE 0.0 END) as like_rate
FROM user_interactions ui1
JOIN user_interactions ui2 ON ui1.meme_id = ui2.meme_id 
  AND ui1.user_id != ui2.user_id
  AND ui1.interaction_type = 'like'
WHERE ui2.interaction_type IN ('like', 'view')
  AND ui2.created_at > CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY ui1.user_id, ui2.meme_id
HAVING COUNT(*) >= 3;

CREATE INDEX IF NOT EXISTS idx_collab_recs_user ON top_collaborative_recommendations(target_user_id, recommendation_strength DESC);

-- Function to refresh collaborative recommendations (call daily)
CREATE OR REPLACE FUNCTION refresh_collaborative_recommendations()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY top_collaborative_recommendations;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate user similarity
CREATE OR REPLACE FUNCTION calculate_user_similarity(user_a_id INTEGER, user_b_id INTEGER)
RETURNS FLOAT AS $$
DECLARE
  common_likes INTEGER;
  total_a INTEGER;
  total_b INTEGER;
  jaccard_score FLOAT;
BEGIN
  -- Get common liked memes
  SELECT COUNT(*) INTO common_likes
  FROM (
    SELECT meme_id FROM user_interactions 
    WHERE user_id = user_a_id AND interaction_type = 'like'
    INTERSECT
    SELECT meme_id FROM user_interactions 
    WHERE user_id = user_b_id AND interaction_type = 'like'
  ) AS common;
  
  -- Get total likes for each user
  SELECT COUNT(DISTINCT meme_id) INTO total_a
  FROM user_interactions
  WHERE user_id = user_a_id AND interaction_type = 'like';
  
  SELECT COUNT(DISTINCT meme_id) INTO total_b
  FROM user_interactions
  WHERE user_id = user_b_id AND interaction_type = 'like';
  
  -- Calculate Jaccard similarity
  IF (total_a + total_b - common_likes) = 0 THEN
    RETURN 0.0;
  END IF;
  
  jaccard_score := common_likes::FLOAT / (total_a + total_b - common_likes);
  
  RETURN jaccard_score;
END;
$$ LANGUAGE plpgsql;

-- Function to update pool performance stats
CREATE OR REPLACE FUNCTION update_pool_performance()
RETURNS void AS $$
BEGIN
  INSERT INTO pool_performance (pool_type, date, selections, likes, skips, avg_duration, engagement_rate)
  SELECT 
    pool_type,
    DATE(created_at) as date,
    COUNT(*) as selections,
    SUM(CASE WHEN interaction_type = 'like' THEN 1 ELSE 0 END) as likes,
    SUM(CASE WHEN interaction_type = 'skip' THEN 1 ELSE 0 END) as skips,
    AVG(duration_seconds) as avg_duration,
    AVG(CASE WHEN interaction_type = 'like' THEN 1.0 ELSE 0.0 END) as engagement_rate
  FROM user_interactions
  WHERE DATE(created_at) = CURRENT_DATE
  GROUP BY pool_type, DATE(created_at)
  ON CONFLICT (pool_type, date) 
  DO UPDATE SET
    selections = EXCLUDED.selections,
    likes = EXCLUDED.likes,
    skips = EXCLUDED.skips,
    avg_duration = EXCLUDED.avg_duration,
    engagement_rate = EXCLUDED.engagement_rate;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE user_interactions IS 'Tracks all user interactions with memes for collaborative filtering and learning';
COMMENT ON TABLE user_similarity IS 'Pre-calculated similarity scores between users for fast collaborative filtering';
COMMENT ON TABLE pool_performance IS 'Tracks effectiveness of each content pool type over time';
COMMENT ON TABLE session_learning IS 'Stores learned preferences within a session for real-time personalization';
COMMENT ON TABLE meme_recommendations IS 'Cached recommendation scores for performance optimization';
COMMENT ON TABLE meme_similarity IS 'Content-based similarity between memes';
COMMENT ON TABLE user_engagement_patterns IS 'Tracks when users are most active and what they prefer at different times';
COMMENT ON TABLE algorithm_experiments IS 'A/B testing data for algorithm optimization';
