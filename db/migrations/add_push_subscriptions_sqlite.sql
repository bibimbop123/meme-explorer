-- Add push subscriptions table for browser push notifications (SQLite)
-- Created: May 12, 2026
-- Part of: Priority 1 Entertainment Enhancements
-- SQLite-compatible version

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  subscription_data TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Add index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);

-- Add index for duplicate prevention
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_unique 
  ON push_subscriptions(user_id, subscription_data);
