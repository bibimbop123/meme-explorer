-- ============================================
-- ENGAGEMENT FEATURES DATABASE MIGRATIONS
-- Created: April 30, 2026
-- Purpose: Add reactions, battles, comments, challenges, and achievements
-- ============================================

-- ============================================
-- 1. REACTIONS SYSTEM
-- ============================================

CREATE TABLE IF NOT EXISTS meme_reactions (
  id SERIAL PRIMARY KEY,
  meme_url TEXT NOT NULL,
  user_id INTEGER,
  session_id TEXT,
  reaction_type VARCHAR(20) NOT NULL CHECK (reaction_type IN ('hilarious', 'fire', 'dead', 'shocking', 'relatable')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT unique_user_reaction UNIQUE (meme_url, user_id, reaction_type),
  CONSTRAINT unique_session_reaction UNIQUE (meme_url, session_id, reaction_type)
);

CREATE INDEX idx_reactions_meme_url ON meme_reactions(meme_url);
CREATE INDEX idx_reactions_user_id ON meme_reactions(user_id);
CREATE INDEX idx_reactions_type ON meme_reactions(reaction_type);
CREATE INDEX idx_reactions_created ON meme_reactions(created_at DESC);

-- Reaction counts view for fast queries
CREATE OR REPLACE VIEW meme_reaction_counts AS
SELECT 
  meme_url,
  reaction_type,
  COUNT(*) as count
FROM meme_reactions
GROUP BY meme_url, reaction_type;

-- ============================================
-- 2. MEME BATTLES SYSTEM
-- ============================================

CREATE TABLE IF NOT EXISTS meme_battles (
  id SERIAL PRIMARY KEY,
  meme_a_url TEXT NOT NULL,
  meme_b_url TEXT NOT NULL,
  winner_url TEXT,
  user_id INTEGER,
  session_id TEXT,
  battle_type VARCHAR(50) DEFAULT 'random',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_battles_user ON meme_battles(user_id);
CREATE INDEX idx_battles_meme_a ON meme_battles(meme_a_url);
CREATE INDEX idx_battles_meme_b ON meme_battles(meme_b_url);
CREATE INDEX idx_battles_created ON meme_battles(created_at DESC);

-- Meme ELO ratings for battles
CREATE TABLE IF NOT EXISTS meme_elo_ratings (
  id SERIAL PRIMARY KEY,
  meme_url TEXT UNIQUE NOT NULL,
  elo_score INTEGER DEFAULT 1200,
  total_battles INTEGER DEFAULT 0,
  wins INTEGER DEFAULT 0,
  losses INTEGER DEFAULT 0,
  win_rate DECIMAL(5,2) DEFAULT 0.0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_elo_score ON meme_elo_ratings(elo_score DESC);
CREATE INDEX idx_elo_battles ON meme_elo_ratings(total_battles DESC);

-- ============================================
-- 3. QUICK COMMENTS SYSTEM
-- ============================================

CREATE TABLE IF NOT EXISTS quick_comments (
  id SERIAL PRIMARY KEY,
  meme_url TEXT NOT NULL,
  user_id INTEGER,
  session_id TEXT,
  comment_text TEXT NOT NULL,
  is_preset BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_comments_meme ON quick_comments(meme_url);
CREATE INDEX idx_comments_user ON quick_comments(user_id);
CREATE INDEX idx_comments_created ON quick_comments(created_at DESC);

-- Preset comment templates
CREATE TABLE IF NOT EXISTS comment_presets (
  id SERIAL PRIMARY KEY,
  text TEXT NOT NULL UNIQUE,
  emoji TEXT,
  category VARCHAR(50),
  usage_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default comment presets
INSERT INTO comment_presets (text, emoji, category) VALUES
  ('DEAD 💀', '💀', 'reaction'),
  ('This is me fr fr', '💯', 'relatable'),
  ('No cap 🧢', '🧢', 'agreement'),
  ('Why is this so accurate?', '🎯', 'relatable'),
  ('Sending this to my ex', '📤', 'relationship'),
  ('Bruh moment', '😳', 'reaction'),
  ('I''m crying 😂', '😂', 'funny'),
  ('Too real', '💀', 'relatable'),
  ('Big mood', '😤', 'mood'),
  ('This hits different', '💯', 'relatable'),
  ('Not me reading this at 3AM', '🌙', 'personal'),
  ('The accuracy is scary', '👻', 'relatable'),
  ('I feel attacked', '🎯', 'personal'),
  ('Nah this is facts', '📠', 'agreement'),
  ('Literally just happened to me', '⏰', 'timing')
ON CONFLICT (text) DO NOTHING;

-- ============================================
-- 4. DAILY CHALLENGES SYSTEM
-- ============================================

CREATE TABLE IF NOT EXISTS daily_challenges (
  id SERIAL PRIMARY KEY,
  challenge_date DATE UNIQUE NOT NULL,
  challenge_type VARCHAR(50) NOT NULL,
  description TEXT NOT NULL,
  goal_count INTEGER NOT NULL,
  reward_xp INTEGER DEFAULT 50,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_challenges_date ON daily_challenges(challenge_date DESC);

-- User challenge progress
CREATE TABLE IF NOT EXISTS user_challenge_progress (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  challenge_id INTEGER NOT NULL REFERENCES daily_challenges(id),
  current_progress INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT unique_user_challenge UNIQUE (user_id, challenge_id)
);

CREATE INDEX idx_progress_user ON user_challenge_progress(user_id);
CREATE INDEX idx_progress_challenge ON user_challenge_progress(challenge_id);
CREATE INDEX idx_progress_completed ON user_challenge_progress(completed, completed_at DESC);

-- ============================================
-- 5. ACHIEVEMENTS SYSTEM
-- ============================================

CREATE TABLE IF NOT EXISTS achievements (
  id SERIAL PRIMARY KEY,
  achievement_key VARCHAR(100) UNIQUE NOT NULL,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  icon TEXT,
  category VARCHAR(50),
  requirement_type VARCHAR(50) NOT NULL,
  requirement_value INTEGER,
  reward_xp INTEGER DEFAULT 100,
  rarity VARCHAR(20) DEFAULT 'common' CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
  is_secret BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User achievements
CREATE TABLE IF NOT EXISTS user_achievements (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  achievement_id INTEGER NOT NULL REFERENCES achievements(id),
  progress INTEGER DEFAULT 0,
  unlocked BOOLEAN DEFAULT FALSE,
  unlocked_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT unique_user_achievement UNIQUE (user_id, achievement_id)
);

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_unlocked ON user_achievements(unlocked, unlocked_at DESC);

-- Insert default achievements
INSERT INTO achievements (achievement_key, name, description, icon, category, requirement_type, requirement_value, reward_xp, rarity) VALUES
  ('first_like', 'First Love', 'Give your first like', '❤️', 'engagement', 'likes_given', 1, 25, 'common'),
  ('hundred_likes', 'Like Machine', 'Give 100 likes', '💯', 'engagement', 'likes_given', 100, 200, 'rare'),
  ('first_save', 'Collector Begins', 'Save your first meme', '🔖', 'collecting', 'memes_saved', 1, 25, 'common'),
  ('ten_saves', 'Meme Curator', 'Save 10 memes', '📚', 'collecting', 'memes_saved', 10, 100, 'common'),
  ('fifty_saves', 'Meme Museum', 'Save 50 memes', '🏛️', 'collecting', 'memes_saved', 50, 300, 'epic'),
  ('week_warrior', 'Week Warrior', 'Maintain a 7-day streak', '🔥', 'streaks', 'streak_days', 7, 150, 'rare'),
  ('month_legend', 'Month Legend', 'Maintain a 30-day streak', '👑', 'streaks', 'streak_days', 30, 1000, 'epic'),
  ('century_club', '100 Days Strong', 'Maintain a 100-day streak', '💪', 'streaks', 'streak_days', 100, 5000, 'legendary'),
  ('level_10', 'Double Digits', 'Reach level 10', '🎯', 'leveling', 'level_reached', 10, 200, 'common'),
  ('level_25', 'Quarter Century', 'Reach level 25', '🌟', 'leveling', 'level_reached', 25, 500, 'rare'),
  ('level_50', 'Halfway There', 'Reach level 50', '⭐', 'leveling', 'level_reached', 50, 1500, 'epic'),
  ('battle_champion', 'Battle Champion', 'Win 100 meme battles', '⚔️', 'battles', 'battles_won', 100, 400, 'rare'),
  ('reaction_king', 'Reaction Royalty', 'React to 500 memes', '👑', 'engagement', 'reactions_given', 500, 350, 'epic'),
  ('comment_legend', 'Comment Legend', 'Leave 200 quick comments', '💬', 'engagement', 'comments_made', 200, 250, 'rare'),
  ('early_bird', 'Early Bird', 'View memes before 6 AM', '🌅', 'special', 'early_access', 1, 50, 'common'),
  ('night_owl', 'Night Owl', 'View memes after midnight', '🦉', 'special', 'late_night', 1, 50, 'common'),
  ('completionist', 'Completionist', 'Complete all collections', '🏆', 'collecting', 'collections_complete', 1, 2000, 'legendary'),
  ('social_butterfly', 'Social Butterfly', 'Share 50 memes', '🦋', 'social', 'shares', 50, 300, 'rare')
ON CONFLICT (achievement_key) DO NOTHING;

-- ============================================
-- 6. NOTIFICATION PREFERENCES
-- ============================================

CREATE TABLE IF NOT EXISTS user_notification_preferences (
  id SERIAL PRIMARY KEY,
  user_id INTEGER UNIQUE NOT NULL,
  streak_reminders BOOLEAN DEFAULT TRUE,
  achievement_alerts BOOLEAN DEFAULT TRUE,
  challenge_updates BOOLEAN DEFAULT TRUE,
  milestone_notifications BOOLEAN DEFAULT TRUE,
  social_notifications BOOLEAN DEFAULT FALSE,
  push_enabled BOOLEAN DEFAULT FALSE,
  push_subscription JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notif_prefs_user ON user_notification_preferences(user_id);

-- ============================================
-- 7. ANALYTICS TRACKING
-- ============================================

CREATE TABLE IF NOT EXISTS user_actions_log (
  id SERIAL PRIMARY KEY,
  user_id INTEGER,
  session_id TEXT,
  action_type VARCHAR(50) NOT NULL,
  meme_url TEXT,
  metadata JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_actions_user ON user_actions_log(user_id);
CREATE INDEX idx_actions_type ON user_actions_log(action_type);
CREATE INDEX idx_actions_created ON user_actions_log(created_at DESC);

-- Partition by month for performance
CREATE INDEX idx_actions_month ON user_actions_log(DATE_TRUNC('month', created_at));

-- ============================================
-- 8. ONBOARDING DATA
-- ============================================

CREATE TABLE IF NOT EXISTS user_onboarding (
  id SERIAL PRIMARY KEY,
  user_id INTEGER UNIQUE NOT NULL,
  humor_style VARCHAR(50),
  favorite_topics TEXT[],
  usage_frequency VARCHAR(20),
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_onboarding_user ON user_onboarding(user_id);
CREATE INDEX idx_onboarding_completed ON user_onboarding(completed);

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Function to update meme win rate
CREATE OR REPLACE FUNCTION update_meme_win_rate()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.total_battles > 0 THEN
    NEW.win_rate := (NEW.wins::DECIMAL / NEW.total_battles::DECIMAL) * 100;
  ELSE
    NEW.win_rate := 0.0;
  END IF;
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_win_rate
BEFORE UPDATE ON meme_elo_ratings
FOR EACH ROW
EXECUTE FUNCTION update_meme_win_rate();

-- Function to auto-update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = CURRENT_TIMESTAMP;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_challenge_progress_timestamp
BEFORE UPDATE ON user_challenge_progress
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ All engagement features migrated successfully!';
  RAISE NOTICE '   - Reactions system';
  RAISE NOTICE '   - Meme battles with ELO';
  RAISE NOTICE '   - Quick comments';
  RAISE NOTICE '   - Daily challenges';
  RAISE NOTICE '   - Achievements (% achievements inserted)', (SELECT COUNT(*) FROM achievements);
  RAISE NOTICE '   - Notification preferences';
  RAISE NOTICE '   - Analytics tracking';
  RAISE NOTICE '   - Onboarding system';
END $$;
