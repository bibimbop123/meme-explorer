-- Enhanced Leaderboard System Migration
-- Created: May 10, 2026
-- Purpose: Add monthly leaderboards, category leaderboards, achievements, and friend systems

-- ============================================
-- 1. MONTHLY LEADERBOARD TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS monthly_leaderboard (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  month_number INTEGER NOT NULL, -- e.g., 202605 (year + month)
  user_id INTEGER NOT NULL,
  total_xp INTEGER DEFAULT 0,
  rank INTEGER,
  reward_claimed INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(month_number, user_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_monthly_leaderboard_month ON monthly_leaderboard(month_number);
CREATE INDEX IF NOT EXISTS idx_monthly_leaderboard_rank ON monthly_leaderboard(month_number, rank);
CREATE INDEX IF NOT EXISTS idx_monthly_leaderboard_user ON monthly_leaderboard(user_id);

-- ============================================
-- 2. CATEGORY LEADERBOARD TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS category_leaderboard (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  week_number INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  category TEXT NOT NULL, -- 'dank', 'wholesome', 'funny', 'selfcare'
  category_score INTEGER DEFAULT 0, -- XP earned in this category
  rank INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(week_number, user_id, category),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_category_leaderboard_week ON category_leaderboard(week_number);
CREATE INDEX IF NOT EXISTS idx_category_leaderboard_category ON category_leaderboard(category, week_number);
CREATE INDEX IF NOT EXISTS idx_category_leaderboard_rank ON category_leaderboard(category, week_number, rank);

-- ============================================
-- 3. ACHIEVEMENTS LOG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS achievements_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  achievement_type TEXT NOT NULL, -- 'weekly_202621_rank_1', 'collection_complete', etc.
  reward_xp INTEGER DEFAULT 0,
  badge TEXT, -- Emoji or badge identifier
  claimed INTEGER DEFAULT 1, -- Auto-claimed when logged
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_achievements_user ON achievements_log(user_id);
CREATE INDEX IF NOT EXISTS idx_achievements_type ON achievements_log(achievement_type);
CREATE INDEX IF NOT EXISTS idx_achievements_date ON achievements_log(created_at);

-- ============================================
-- 4. USER FRIENDSHIPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_friendships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  friend_id INTEGER NOT NULL,
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'declined', 'blocked'
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  accepted_at TIMESTAMP,
  UNIQUE(user_id, friend_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (friend_id) REFERENCES users(id) ON DELETE CASCADE,
  CHECK (user_id != friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user ON user_friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend ON user_friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON user_friendships(status);

-- ============================================
-- 5. USER CHALLENGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_challenges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  challenger_id INTEGER NOT NULL,
  challenged_id INTEGER NOT NULL,
  challenge_type TEXT NOT NULL, -- 'most_likes', 'highest_streak', 'most_saves'
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status TEXT DEFAULT 'active', -- 'active', 'completed', 'cancelled'
  winner_id INTEGER,
  challenger_score INTEGER DEFAULT 0,
  challenged_score INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  FOREIGN KEY (challenger_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (challenged_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (winner_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_challenges_challenger ON user_challenges(challenger_id);
CREATE INDEX IF NOT EXISTS idx_challenges_challenged ON user_challenges(challenged_id);
CREATE INDEX IF NOT EXISTS idx_challenges_status ON user_challenges(status);
CREATE INDEX IF NOT EXISTS idx_challenges_dates ON user_challenges(end_date, status);

-- ============================================
-- 6. RANK CHANGE HISTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS rank_change_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  leaderboard_type TEXT NOT NULL, -- 'weekly', 'monthly', 'all_time', 'streak'
  period TEXT NOT NULL, -- Week/month identifier
  old_rank INTEGER,
  new_rank INTEGER,
  rank_change INTEGER, -- Positive = moved up, negative = moved down
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_rank_history_user ON rank_change_history(user_id);
CREATE INDEX IF NOT EXISTS idx_rank_history_period ON rank_change_history(leaderboard_type, period);
CREATE INDEX IF NOT EXISTS idx_rank_history_date ON rank_change_history(created_at);

-- ============================================
-- 7. LEADERBOARD NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS leaderboard_notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  notification_type TEXT NOT NULL, -- 'rank_up', 'rank_down', 'passed_by', 'milestone', 'reward'
  title TEXT NOT NULL,
  message TEXT,
  data TEXT, -- JSON data for the notification
  read INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON leaderboard_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON leaderboard_notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_notifications_date ON leaderboard_notifications(created_at);

-- ============================================
-- 8. LEADERBOARD SNAPSHOTS TABLE (Historical Data)
-- ============================================
CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  leaderboard_type TEXT NOT NULL,
  period TEXT NOT NULL,
  snapshot_data TEXT NOT NULL, -- JSON of top 100
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(leaderboard_type, period)
);

CREATE INDEX IF NOT EXISTS idx_snapshots_type ON leaderboard_snapshots(leaderboard_type);
CREATE INDEX IF NOT EXISTS idx_snapshots_period ON leaderboard_snapshots(period);

-- ============================================
-- 9. ADD MISSING COLUMNS TO EXISTING TABLES
-- ============================================

-- Add rank_change_notified to weekly_leaderboard
ALTER TABLE weekly_leaderboard ADD COLUMN rank_change_notified INTEGER DEFAULT 0;
ALTER TABLE weekly_leaderboard ADD COLUMN last_rank INTEGER;

-- ============================================
-- 10. SEED INITIAL DATA
-- ============================================

-- Create initial monthly leaderboard entries for active users
INSERT OR IGNORE INTO monthly_leaderboard (month_number, user_id, total_xp, rank)
SELECT 
  CAST(strftime('%Y%m', 'now') AS INTEGER) as month_number,
  user_id,
  total_xp,
  ROW_NUMBER() OVER (ORDER BY total_xp DESC) as rank
FROM user_levels
WHERE total_xp > 0;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
-- Run this file with: sqlite3 memes.db < db/migrations/enhance_leaderboard_system.sql
