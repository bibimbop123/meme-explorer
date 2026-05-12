-- Phase 3-6: Addictiveness, Quality, Humor, Retention Tables
-- Run this migration to support all phase 3-6 features

-- User Achievements (Phase 3: Milestones)
CREATE TABLE IF NOT EXISTS user_achievements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  achievement_type TEXT NOT NULL,
  achievement_data TEXT NOT NULL,
  earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_type ON user_achievements(achievement_type);

-- User XP Log (Phase 3: Milestones)
CREATE TABLE IF NOT EXISTS user_xp_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  xp_amount INTEGER NOT NULL,
  reason TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_user_xp_log_user_id ON user_xp_log(user_id);

-- User Streaks (Phase 6: Retention)
CREATE TABLE IF NOT EXISTS user_streaks (
  user_id INTEGER PRIMARY KEY,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_visit_date DATE,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_user_streaks_last_visit ON user_streaks(last_visit_date);

-- User Rewards (Phase 6: Retention)
CREATE TABLE IF NOT EXISTS user_rewards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  reward_type TEXT NOT NULL,
  reward_data TEXT,
  earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  claimed BOOLEAN DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_user_rewards_user_id ON user_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_user_rewards_claimed ON user_rewards(claimed);

-- Add total_xp column to users table if it doesn't exist
-- ALTER TABLE users ADD COLUMN total_xp INTEGER DEFAULT 0;

-- PostgreSQL Version (comment out SQLite version above and use this)
-- CREATE TABLE IF NOT EXISTS user_achievements (
--   id SERIAL PRIMARY KEY,
--   user_id INTEGER NOT NULL,
--   achievement_type VARCHAR(100) NOT NULL,
--   achievement_data JSONB NOT NULL,
--   earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   FOREIGN KEY (user_id) REFERENCES users(id)
-- );
-- 
-- CREATE TABLE IF NOT EXISTS user_xp_log (
--   id SERIAL PRIMARY KEY,
--   user_id INTEGER NOT NULL,
--   xp_amount INTEGER NOT NULL,
--   reason TEXT,
--   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   FOREIGN KEY (user_id) REFERENCES users(id)
-- );
-- 
-- CREATE TABLE IF NOT EXISTS user_streaks (
--   user_id INTEGER PRIMARY KEY,
--   current_streak INTEGER DEFAULT 0,
--   longest_streak INTEGER DEFAULT 0,
--   last_visit_date DATE,
--   updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   FOREIGN KEY (user_id) REFERENCES users(id)
-- );
-- 
-- CREATE TABLE IF NOT EXISTS user_rewards (
--   id SERIAL PRIMARY KEY,
--   user_id INTEGER NOT NULL,
--   reward_type VARCHAR(100) NOT NULL,
--   reward_data JSONB,
--   earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   claimed BOOLEAN DEFAULT FALSE,
--   FOREIGN KEY (user_id) REFERENCES users(id)
-- );
