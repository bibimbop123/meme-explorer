-- Apply after add_browser_visitors.sql, before enabling the updated collector.
ALTER TABLE browser_visitors ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
ALTER TABLE browser_visitors ALTER COLUMN last_seen_at DROP NOT NULL;