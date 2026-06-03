-- ============================================
-- PRODUCTION ERROR FIXES - June 2026
-- Run this on Render PostgreSQL to fix missing tables
-- ============================================

-- 1. USER LIKED MEMES TABLE (for persistent likes)
CREATE TABLE IF NOT EXISTS user_liked_memes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);

CREATE INDEX IF NOT EXISTS idx_user_liked_memes_user_id ON user_liked_memes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_liked_memes_meme_url ON user_liked_memes(meme_url);

-- 2. USER LEVELS TABLE (if not exists from previous migration)
CREATE TABLE IF NOT EXISTS user_levels (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  level INTEGER DEFAULT 1,
  current_xp INTEGER DEFAULT 0,
  total_xp INTEGER DEFAULT 0,
  title VARCHAR(255) DEFAULT 'Meme Novice',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_levels_user_id ON user_levels(user_id);
CREATE INDEX IF NOT EXISTS idx_user_levels_total_xp ON user_levels(total_xp DESC);

-- 3. USER STREAKS TABLE (if not exists from previous migration)
CREATE TABLE IF NOT EXISTS user_streaks (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_visit_date DATE,
  streak_freeze_count INTEGER DEFAULT 2,
  total_memes_viewed INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_streaks_user_id ON user_streaks(user_id);
CREATE INDEX IF NOT EXISTS idx_user_streaks_current ON user_streaks(current_streak DESC);

-- 4. Ensure meme_stats has all required columns
ALTER TABLE meme_stats ADD COLUMN IF NOT EXISTS failure_count INTEGER DEFAULT 0;
ALTER TABLE meme_stats ADD COLUMN IF NOT EXISTS last_checked_at TIMESTAMP WITH TIME ZONE;

-- DONE!
