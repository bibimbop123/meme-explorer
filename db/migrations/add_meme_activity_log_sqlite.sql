-- Migration: Add meme_activity_log table for accurate time-based metrics (SQLite)
-- Date: May 13, 2026
-- Purpose: Track individual view and like events with timestamps for accurate period filtering

-- Create activity log table (SQLite syntax)
CREATE TABLE IF NOT EXISTS meme_activity_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  meme_url TEXT NOT NULL,
  activity_type TEXT NOT NULL CHECK(activity_type IN ('view', 'like', 'unlike')),
  user_id INTEGER,
  session_id TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for fast querying
CREATE INDEX IF NOT EXISTS idx_activity_log_created_at ON meme_activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_meme_url ON meme_activity_log(meme_url);
CREATE INDEX IF NOT EXISTS idx_activity_log_type_date ON meme_activity_log(activity_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_url_type_date ON meme_activity_log(meme_url, activity_type, created_at DESC);

-- Add created_at to meme_stats for tracking when meme was first seen
-- SQLite doesn't have ADD COLUMN IF NOT EXISTS, so we need to check first
-- This will be handled by the migration script
