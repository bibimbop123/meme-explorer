-- Broken Images Tracking Table
-- Adds missing columns to existing table (idempotent ALTER TABLE approach)
-- Table itself was created via postgres_schema.sql with fewer columns.

ALTER TABLE broken_images ADD COLUMN IF NOT EXISTS failure_reason TEXT;
ALTER TABLE broken_images ADD COLUMN IF NOT EXISTS is_blacklisted BOOLEAN DEFAULT FALSE;
ALTER TABLE broken_images ADD COLUMN IF NOT EXISTS blacklisted_until TIMESTAMP NULL;
ALTER TABLE broken_images ADD COLUMN IF NOT EXISTS http_status_code INTEGER NULL;
ALTER TABLE broken_images ADD COLUMN IF NOT EXISTS last_check_duration_ms INTEGER NULL;

CREATE INDEX IF NOT EXISTS idx_broken_images_blacklisted ON broken_images(is_blacklisted, blacklisted_until);
CREATE INDEX IF NOT EXISTS idx_broken_images_failure_count ON broken_images(failure_count);
CREATE INDEX IF NOT EXISTS idx_broken_images_last_failed ON broken_images(last_failed_at);
