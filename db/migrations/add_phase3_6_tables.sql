-- Phase 3-6 Tables (fixed: use actual column names from existing schema)
-- meme_similarity already exists with meme_id_a/meme_id_b columns
CREATE INDEX IF NOT EXISTS idx_meme_similarity_source_new ON meme_similarity(meme_id_a, similarity_score DESC);

CREATE TABLE IF NOT EXISTS user_engagement_patterns (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  pattern_type TEXT,
  pattern_data TEXT,
  computed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pool_performance (
  id SERIAL PRIMARY KEY,
  pool_name TEXT NOT NULL,
  meme_url TEXT NOT NULL,
  shown_count INTEGER DEFAULT 0,
  like_count INTEGER DEFAULT 0,
  skip_count INTEGER DEFAULT 0,
  engagement_rate FLOAT DEFAULT 0.0,
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
