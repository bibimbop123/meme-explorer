-- Add premium subscription support to users
-- Date: 2026-09-29
-- Purpose: ROADMAP.md Phase 2 ("Diversify beyond generic ad-network
-- monetization ... premium personalization, ad-free tier") - the
-- `stripe` gem has been in the Gemfile with no integration code behind
-- it since before this session (.env.example explicitly flagged this).
-- This migration is additive and idempotent (IF NOT EXISTS throughout),
-- matching the established pattern in this directory
-- (add_role_column_july_22_2026.sql, add_admin_column_audit_2026.sql) -
-- safe to run against the live production DB with existing rows/traffic.
--
-- NOTE: this repo has no automated migration runner wired into deploy
-- (confirmed: render.yaml's startCommand is a plain `rackup`, no
-- migration step) - migrations here are applied manually. The
-- application code that reads these columns
-- (lib/services/subscription_service.rb) defensively checks for their
-- existence first (same pattern routes/metrics_routes.rb already uses
-- for meme_activity_log) and fails safe to "not premium" rather than
-- crashing if this hasn't been run yet in a given environment.

ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_subscription_id VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_status VARCHAR(50) DEFAULT 'none' NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_current_period_end TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_users_stripe_customer_id ON users(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_users_stripe_subscription_id ON users(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_users_premium_status ON users(premium_status);

-- premium_status mirrors Stripe subscription status values we act on
-- directly ('none' is our own default, not a Stripe value): 'active',
-- 'trialing', 'past_due', 'canceled', 'unpaid'. Ad-free access
-- (SubscriptionService.premium?) only ever checks for 'active'/'trialing'
-- AND a future premium_current_period_end - both conditions together,
-- not status alone, so a stale webhook that failed to update status
-- can't leave someone premium forever if their period has actually
-- lapsed.
UPDATE users SET premium_status = 'none' WHERE premium_status IS NULL;

-- Idempotency for Stripe webhook events (Stripe recommends deduplicating
-- by event id - the same event can be delivered more than once, e.g. on
-- a slow response causing a retry). Separate table rather than a column
-- on users since a webhook event isn't inherently tied to one user
-- (e.g. price/product-level events).
CREATE TABLE IF NOT EXISTS stripe_webhook_events (
  id SERIAL PRIMARY KEY,
  stripe_event_id VARCHAR(255) UNIQUE NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Verify columns were added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'users' AND (column_name LIKE '%premium%' OR column_name LIKE '%stripe%');
