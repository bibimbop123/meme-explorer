-- Add push subscriptions table for browser push notifications
-- Created: May 11, 2026
-- Part of: Priority 1 Entertainment Enhancements

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subscription_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);

-- Add unique constraint to prevent duplicate subscriptions
CREATE UNIQUE INDEX IF NOT EXISTS idx_push_subscriptions_unique 
  ON push_subscriptions(user_id, md5(subscription_data::text));

-- Comments
COMMENT ON TABLE push_subscriptions IS 'Browser push notification subscriptions for user engagement';
COMMENT ON COLUMN push_subscriptions.subscription_data IS 'Web Push API subscription object (JSONB)';
