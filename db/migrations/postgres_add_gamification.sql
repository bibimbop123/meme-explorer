-- PostgreSQL Gamification Tables Migration
-- Run this on your Render PostgreSQL database

-- ============================================
-- 1. USER LEVELS TABLE (XP System)
-- ============================================
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

-- ============================================
-- 2. USER STREAKS TABLE
-- ============================================
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

-- ============================================
-- 3. XP ACTIVITY LOG
-- ============================================
CREATE TABLE IF NOT EXISTS xp_activity_log (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  activity_type VARCHAR(50) NOT NULL,
  xp_earned INTEGER NOT NULL,
  details TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_xp_activity_user ON xp_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_xp_activity_date ON xp_activity_log(created_at DESC);

-- ============================================
-- 4. WEEKLY LEADERBOARD
-- ============================================
CREATE TABLE IF NOT EXISTS weekly_leaderboard (
  id SERIAL PRIMARY KEY,
  week_number INTEGER NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  metric_value INTEGER DEFAULT 0,
  rank INTEGER,
  reward_claimed INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(week_number, user_id)
);

CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_week ON weekly_leaderboard(week_number);
CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_rank ON weekly_leaderboard(week_number, rank);

-- ============================================
-- 5. MONTHLY LEADERBOARD
-- ============================================
CREATE TABLE IF NOT EXISTS monthly_leaderboard (
  id SERIAL PRIMARY KEY,
  month_number INTEGER NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total_xp INTEGER DEFAULT 0,
  rank INTEGER,
  reward_claimed INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(month_number, user_id)
);

CREATE INDEX IF NOT EXISTS idx_monthly_leaderboard_month ON monthly_leaderboard(month_number);
CREATE INDEX IF NOT EXISTS idx_monthly_leaderboard_rank ON monthly_leaderboard(month_number, rank);

-- ============================================
-- 6. MEME COLLECTIONS
-- ============================================
CREATE TABLE IF NOT EXISTS meme_collections (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  badge_emoji VARCHAR(10),
  required_memes TEXT,
  unlock_requirement TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Seed initial collections
INSERT INTO meme_collections (name, description, badge_emoji, required_memes, unlock_requirement) VALUES
('Wholesome Warrior', 'View 50 wholesome memes', '😊', '{"subreddits": ["wholesome", "aww", "MadeMeSmile"], "count": 50}', 'View 50 memes from wholesome subreddits'),
('Dank Connoisseur', 'Master of dank memes', '💀', '{"subreddits": ["dankmemes", "dank"], "count": 100}', 'View 100 dank memes'),
('Century Club', 'View 100 different memes', '💯', '{"total_views": 100}', 'View 100 unique memes'),
('Streak Master', 'Maintain a 30-day streak', '🔥', '{"streak_days": 30}', 'Keep your streak alive for 30 days')
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- 7. USER COLLECTIONS
-- ============================================
CREATE TABLE IF NOT EXISTS user_collections (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  collection_id INTEGER NOT NULL REFERENCES meme_collections(id) ON DELETE CASCADE,
  progress INTEGER DEFAULT 0,
  completed INTEGER DEFAULT 0,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, collection_id)
);

CREATE INDEX IF NOT EXISTS idx_user_collections_user_id ON user_collections(user_id);
CREATE INDEX IF NOT EXISTS idx_user_collections_completed ON user_collections(completed);

-- ============================================
-- 8. WEEKLY CHALLENGES
-- ============================================
CREATE TABLE IF NOT EXISTS weekly_challenges (
  id SERIAL PRIMARY KEY,
  week_number INTEGER NOT NULL,
  challenge_type VARCHAR(100),
  description TEXT,
  reward_xp INTEGER DEFAULT 500,
  starts_at TIMESTAMP WITH TIME ZONE,
  ends_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_weekly_challenges_week ON weekly_challenges(week_number);

-- ============================================
-- DONE! All gamification tables created
-- ============================================
