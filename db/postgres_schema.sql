-- PostgreSQL Schema for Meme Explorer

-- users table
CREATE TABLE IF NOT EXISTS meme_catalog (
  id VARCHAR(64) PRIMARY KEY,
  media_url TEXT NOT NULL UNIQUE,
  payload JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  removed_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  reddit_id VARCHAR(255) UNIQUE,
  reddit_username VARCHAR(255),
  reddit_email VARCHAR(255),
  email VARCHAR(255) UNIQUE,
  password_hash VARCHAR(255),
  role VARCHAR(50) DEFAULT 'user',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- meme_stats table (critical for app functionality)
CREATE TABLE IF NOT EXISTS meme_stats (
  id SERIAL PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,
  title TEXT,
  subreddit VARCHAR(255),
  likes INTEGER DEFAULT 0,
  views INTEGER DEFAULT 0,
  failure_count INTEGER DEFAULT 0,
  first_failed_at TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_meme_stats_likes_views ON meme_stats(likes DESC, views DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit ON meme_stats(subreddit);
CREATE INDEX IF NOT EXISTS idx_meme_stats_updated_at ON meme_stats(updated_at DESC);

-- user_meme_stats table
CREATE TABLE IF NOT EXISTS meme_impressions (
  id VARCHAR(64) PRIMARY KEY,
  meme_url TEXT NOT NULL,
  session_key VARCHAR(64) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_meme_impressions_created_at ON meme_impressions(created_at);
CREATE TABLE IF NOT EXISTS meme_activity_log (
  id SERIAL PRIMARY KEY,
  meme_url TEXT NOT NULL,
  activity_type TEXT NOT NULL,
  user_id INTEGER,
  session_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_meme_activity_log_created_at ON meme_activity_log(created_at DESC, activity_type);
CREATE INDEX IF NOT EXISTS idx_meme_activity_log_user_date ON meme_activity_log(user_id, created_at DESC);

-- Persistent likes used by the live /like route and profile. Mirrors the
-- additive fix_production_errors_2026 migration for fresh installations.
CREATE TABLE IF NOT EXISTS user_liked_memes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);
CREATE INDEX IF NOT EXISTS idx_user_liked_memes_user_id ON user_liked_memes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_liked_memes_meme_url ON user_liked_memes(meme_url);

CREATE TABLE IF NOT EXISTS user_meme_stats (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  liked INTEGER DEFAULT 0,
  liked_at TIMESTAMP,
  unliked_at TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);

-- user_meme_exposure table (for spaced repetition)
CREATE TABLE IF NOT EXISTS user_meme_exposure (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  shown_count INTEGER DEFAULT 1,
  last_shown TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);

-- user_subreddit_preferences table
CREATE TABLE IF NOT EXISTS user_subreddit_preferences (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subreddit VARCHAR(255) NOT NULL,
  preference_score DOUBLE PRECISION DEFAULT 1.0,
  times_liked INTEGER DEFAULT 1,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, subreddit)
);

-- saved_memes table
CREATE TABLE IF NOT EXISTS saved_memes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  meme_title TEXT,
  meme_subreddit VARCHAR(255),
  saved_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);

-- broken_images table
CREATE TABLE IF NOT EXISTS broken_images (
  id SERIAL PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,
  failure_count INTEGER DEFAULT 1,
  first_failed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  last_failed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- browser_visitors tables (24h / 7d / 30d unique viewer tracking on /metrics)
CREATE TABLE IF NOT EXISTS browser_visitor_collection (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS browser_visitors (
  visitor_key VARCHAR(64) PRIMARY KEY,
  last_seen_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS browser_visitors_last_seen ON browser_visitors(last_seen_at);

-- email_subscriptions table (used by POST /api/subscribe)
CREATE TABLE IF NOT EXISTS email_subscriptions (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  subscribed_at BIGINT NOT NULL
);

-- push_subscriptions table (used by POST /api/subscribe-push)
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subscription_data TEXT,
  endpoint TEXT,
  p256dh TEXT,
  auth TEXT,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);
