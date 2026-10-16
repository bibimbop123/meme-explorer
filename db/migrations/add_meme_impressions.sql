-- Apply before deploying acknowledged AJAX impressions. Additive/idempotent.
CREATE TABLE IF NOT EXISTS meme_impressions (
  id VARCHAR(64) PRIMARY KEY,
  meme_url TEXT NOT NULL,
  session_key VARCHAR(64) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_meme_impressions_created_at ON meme_impressions(created_at);
-- Retention metrics use acknowledged views rather than page requests.
CREATE TABLE IF NOT EXISTS meme_activity_log (
  id SERIAL PRIMARY KEY,
  meme_url TEXT NOT NULL,
  activity_type TEXT NOT NULL,
  user_id INTEGER,
  session_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);