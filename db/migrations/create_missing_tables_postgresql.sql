-- Create Missing Tables for PostgreSQL Production
-- Date: June 3, 2026
-- Purpose: Fix production errors from missing tables

-- 1. Create meme_activity_log table (for engagement tracking)
CREATE TABLE IF NOT EXISTS meme_activity_log (
  id SERIAL PRIMARY KEY,
  meme_url VARCHAR(500) NOT NULL,
  activity_type VARCHAR(50) NOT NULL,
  user_id INTEGER,
  session_id VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Indexes for performance
  INDEX idx_meme_activity_url (meme_url),
  INDEX idx_meme_activity_user (user_id),
  INDEX idx_meme_activity_type (activity_type),
  INDEX idx_meme_activity_created (created_at)
);

-- 2. Create user_achievements table (for milestone rewards)
CREATE TABLE IF NOT EXISTS user_achievements (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  achievement_type VARCHAR(100) NOT NULL,
  achievement_name VARCHAR(200) NOT NULL,
  achievement_description TEXT,
  xp_awarded INTEGER DEFAULT 0,
  awarded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Indexes for performance
  INDEX idx_user_achievements_user (user_id),
  INDEX idx_user_achievements_type (achievement_type),
  INDEX idx_user_achievements_awarded (awarded_at),
  
  -- Prevent duplicate achievements
  UNIQUE (user_id, achievement_type, achievement_name)
);

-- 3. Add comments for documentation
COMMENT ON TABLE meme_activity_log IS 'Tracks all meme engagement activities (views, likes, saves, etc.)';
COMMENT ON TABLE user_achievements IS 'Stores user achievements and milestones';

-- 4. Grant permissions (if needed)
-- GRANT ALL PRIVILEGES ON meme_activity_log TO your_db_user;
-- GRANT ALL PRIVILEGES ON user_achievements TO your_db_user;
