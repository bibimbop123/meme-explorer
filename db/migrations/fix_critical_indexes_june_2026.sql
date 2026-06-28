-- Fix Critical Indexes June 2026
-- Fixed: WHERE clause predicates using NOW() are not IMMUTABLE in PostgreSQL
-- Solution: Create indexes without time-based WHERE predicates
CREATE INDEX IF NOT EXISTS idx_meme_stats_updated_recent ON meme_stats(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_activity_recent ON meme_activity_log(created_at DESC);
