-- Apply before enabling stable meme identity/detail routes.
-- No existing engagement URL keys are rewritten.
CREATE TABLE IF NOT EXISTS meme_catalog (
  id VARCHAR(64) PRIMARY KEY,
  media_url TEXT NOT NULL UNIQUE,
  payload JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  removed_at TIMESTAMP WITH TIME ZONE
);