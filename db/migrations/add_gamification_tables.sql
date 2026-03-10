-- Gamification Tables Migration
-- Created: March 10, 2026
-- Purpose: Add daily streaks, XP/leveling, collections, and weekly challenges

-- ============================================
-- 1. USER STREAKS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_streaks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_visit_date DATE,
  streak_freeze_count INTEGER DEFAULT 2, -- Allow 2 "freeze" days per month
  total_memes_viewed INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_streaks_user_id ON user_streaks(user_id);
CREATE INDEX IF NOT EXISTS idx_user_streaks_last_visit ON user_streaks(last_visit_date);

-- ============================================
-- 2. USER LEVELS TABLE (XP System)
-- ============================================
CREATE TABLE IF NOT EXISTS user_levels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE,
  level INTEGER DEFAULT 1,
  current_xp INTEGER DEFAULT 0,
  total_xp INTEGER DEFAULT 0,
  title TEXT DEFAULT 'Meme Novice',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_levels_user_id ON user_levels(user_id);
CREATE INDEX IF NOT EXISTS idx_user_levels_level ON user_levels(level);

-- ============================================
-- 3. MEME COLLECTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS meme_collections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  badge_emoji TEXT,
  required_memes TEXT, -- JSON: requirements like subreddit count
  unlock_requirement TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed initial collections
INSERT OR IGNORE INTO meme_collections (name, description, badge_emoji, required_memes, unlock_requirement) VALUES
('Wholesome Warrior', 'View 50 wholesome memes', '😊', '{"subreddits": ["wholesome", "aww", "MadeMeSmile"], "count": 50}', 'View 50 memes from wholesome subreddits'),
('Dank Connoisseur', 'Master of dank memes', '💀', '{"subreddits": ["dankmemes", "dank"], "count": 100}', 'View 100 dank memes'),
('Early Bird', 'Check memes before 8 AM', '🌅', '{"early_morning_views": 5}', 'View memes before 8 AM on 5 different days'),
('Night Owl', 'Browse after midnight', '🦉', '{"late_night_views": 10}', 'View memes after midnight on 10 different days'),
('Meme Archaeologist', 'Like 10 memes older than 30 days', '🏺', '{"old_meme_likes": 10}', 'Like 10 memes from archive'),
('Social Butterfly', 'Share 20 memes', '🦋', '{"shares": 20}', 'Share 20 memes with friends'),
('Century Club', 'View 100 different memes', '💯', '{"total_views": 100}', 'View 100 unique memes'),
('Streak Master', 'Maintain a 30-day streak', '🔥', '{"streak_days": 30}', 'Keep your streak alive for 30 days');

-- ============================================
-- 4. USER COLLECTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_collections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  collection_id INTEGER NOT NULL,
  progress INTEGER DEFAULT 0,
  completed INTEGER DEFAULT 0, -- 0 = false, 1 = true
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, collection_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (collection_id) REFERENCES meme_collections(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_collections_user_id ON user_collections(user_id);
CREATE INDEX IF NOT EXISTS idx_user_collections_completed ON user_collections(completed);

-- ============================================
-- 5. WEEKLY CHALLENGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS weekly_challenges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  week_number INTEGER NOT NULL, -- e.g., 202612 (year + week)
  challenge_type TEXT, -- e.g., "most_likes", "streak_keeper"
  description TEXT,
  reward_xp INTEGER DEFAULT 500,
  starts_at TIMESTAMP,
  ends_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_weekly_challenges_week ON weekly_challenges(week_number);

-- ============================================
-- 6. WEEKLY LEADERBOARD TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS weekly_leaderboard (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  week_number INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  metric_value INTEGER DEFAULT 0,
  rank INTEGER,
  reward_claimed INTEGER DEFAULT 0, -- 0 = false, 1 = true
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(week_number, user_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_week ON weekly_leaderboard(week_number);
CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_user ON weekly_leaderboard(user_id);
CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_rank ON weekly_leaderboard(week_number, rank);

-- ============================================
-- 7. XP ACTIVITY LOG (Optional - for analytics)
-- ============================================
CREATE TABLE IF NOT EXISTS xp_activity_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  activity_type TEXT NOT NULL, -- 'like_meme', 'save_meme', 'daily_streak', etc.
  xp_gained INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_xp_activity_user_id ON xp_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_xp_activity_date ON xp_activity_log(created_at);

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
-- Run this file with: sqlite3 memes.db < db/migrations/add_gamification_tables.sql
