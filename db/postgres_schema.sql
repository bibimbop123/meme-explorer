-- PostgreSQL Schema for Meme Explorer

-- users table
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
