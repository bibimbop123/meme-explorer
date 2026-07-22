-- Premium Subscription Tier Migration
-- Created: July 22, 2026
-- Purpose: Add premium subscription functionality for recurring revenue

-- Premium subscriptions table
CREATE TABLE IF NOT EXISTS premium_subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  stripe_subscription_id TEXT UNIQUE,
  stripe_customer_id TEXT,
  status TEXT DEFAULT 'active', -- 'active', 'canceled', 'past_due', 'trialing'
  plan TEXT DEFAULT 'monthly', -- 'monthly' or 'yearly'
  started_at INTEGER DEFAULT (strftime('%s', 'now')),
  expires_at INTEGER, -- NULL for active subscriptions
  trial_ends_at INTEGER, -- Optional trial period
  canceled_at INTEGER, -- When user canceled (even if still active until expiry)
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_premium_user_id ON premium_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_premium_status ON premium_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_premium_stripe_sub ON premium_subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_premium_stripe_cust ON premium_subscriptions(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_premium_expires_at ON premium_subscriptions(expires_at);

-- Subscription history/audit log
CREATE TABLE IF NOT EXISTS premium_subscription_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subscription_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  event_type TEXT NOT NULL, -- 'created', 'renewed', 'canceled', 'expired', 'payment_failed'
  old_status TEXT,
  new_status TEXT,
  metadata TEXT, -- JSON string with extra info
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (subscription_id) REFERENCES premium_subscriptions(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_premium_history_subscription ON premium_subscription_history(subscription_id);
CREATE INDEX IF NOT EXISTS idx_premium_history_user ON premium_subscription_history(user_id);
CREATE INDEX IF NOT EXISTS idx_premium_history_event ON premium_subscription_history(event_type);

-- Stripe webhook events log (for debugging/reconciliation)
CREATE TABLE IF NOT EXISTS stripe_webhook_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stripe_event_id TEXT UNIQUE NOT NULL,
  event_type TEXT NOT NULL,
  payload TEXT NOT NULL, -- Full JSON payload
  processed INTEGER DEFAULT 0, -- 0 = pending, 1 = processed, 2 = failed
  error_message TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  processed_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_stripe_webhook_event_id ON stripe_webhook_events(stripe_event_id);
CREATE INDEX IF NOT EXISTS idx_stripe_webhook_type ON stripe_webhook_events(event_type);
CREATE INDEX IF NOT EXISTS idx_stripe_webhook_processed ON stripe_webhook_events(processed);

-- For fresh databases: Create users table with premium columns
-- For existing databases: This will fail silently, then we add columns below
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE,
  password_hash TEXT,
  reddit_username TEXT UNIQUE,
  reddit_id TEXT,
  access_token TEXT,
  refresh_token TEXT,
  token_expires_at INTEGER,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  last_login_at INTEGER,
  profile_image_url TEXT,
  karma INTEGER DEFAULT 0,
  role TEXT DEFAULT 'user',
  is_premium INTEGER DEFAULT 0,
  premium_since INTEGER
);

-- For EXISTING users tables: Add premium columns if they don't exist
-- SQLite doesn't have ADD COLUMN IF NOT EXISTS, so we'll check first
-- If this fails, it means columns already exist - that's OK!

-- Try to add is_premium column (will fail silently if exists)
-- Note: Run this manually or catch the error in the Ruby script
-- ALTER TABLE users ADD COLUMN is_premium INTEGER DEFAULT 0;
-- ALTER TABLE users ADD COLUMN premium_since INTEGER;

CREATE INDEX IF NOT EXISTS idx_users_is_premium ON users(is_premium);

-- Premium feature usage tracking (optional - for analytics)
CREATE TABLE IF NOT EXISTS premium_feature_usage (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  feature_name TEXT NOT NULL, -- 'ad_free', 'early_access', 'premium_badge', etc.
  usage_count INTEGER DEFAULT 1,
  last_used_at INTEGER DEFAULT (strftime('%s', 'now')),
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_premium_feature_user ON premium_feature_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_premium_feature_name ON premium_feature_usage(feature_name);

-- Revenue tracking table (for dashboard/metrics)
CREATE TABLE IF NOT EXISTS premium_revenue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  subscription_id INTEGER,
  amount_cents INTEGER NOT NULL,
  currency TEXT DEFAULT 'usd',
  stripe_payment_intent_id TEXT,
  description TEXT, -- 'Monthly subscription', 'Annual subscription', etc.
  recorded_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (subscription_id) REFERENCES premium_subscriptions(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_premium_revenue_user ON premium_revenue(user_id);
CREATE INDEX IF NOT EXISTS idx_premium_revenue_date ON premium_revenue(recorded_at);
CREATE INDEX IF NOT EXISTS idx_premium_revenue_amount ON premium_revenue(amount_cents);

-- Insert initial data/config
-- Pricing plans stored in config but we log plan changes here
CREATE TABLE IF NOT EXISTS premium_pricing_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_type TEXT NOT NULL, -- 'monthly' or 'yearly'
  price_cents INTEGER NOT NULL,
  currency TEXT DEFAULT 'usd',
  effective_from INTEGER NOT NULL,
  effective_to INTEGER, -- NULL if current
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Current pricing (as of July 22, 2026)
INSERT INTO premium_pricing_history (plan_type, price_cents, currency, effective_from) 
VALUES 
  ('monthly', 299, 'usd', strftime('%s', 'now')),
  ('yearly', 2999, 'usd', strftime('%s', 'now'));

-- Success message
SELECT 'Premium tier tables created successfully!' AS result;
SELECT 'Ready to accept subscriptions at $2.99/month or $29.99/year' AS pricing;
