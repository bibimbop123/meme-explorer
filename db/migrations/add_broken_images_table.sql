-- Broken Images Tracking Table
-- Tracks URLs that fail validation to prevent repeated attempts
-- and enable intelligent blacklisting

CREATE TABLE IF NOT EXISTS broken_images (
  url TEXT PRIMARY KEY,
  failure_count INTEGER DEFAULT 1,
  first_failed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_failed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  failure_reason TEXT,
  is_blacklisted BOOLEAN DEFAULT FALSE,
  blacklisted_until TIMESTAMP NULL,
  http_status_code INTEGER NULL,
  last_check_duration_ms INTEGER NULL
);

-- Index for performance on blacklist checks
CREATE INDEX IF NOT EXISTS idx_broken_images_blacklisted ON broken_images(is_blacklisted, blacklisted_until);

-- Index for failure analysis
CREATE INDEX IF NOT EXISTS idx_broken_images_failure_count ON broken_images(failure_count);

-- Index for cleanup/monitoring
CREATE INDEX IF NOT EXISTS idx_broken_images_last_failed ON broken_images(last_failed_at);

-- SQLite doesn't support COMMENT ON, but we document the table here:
-- broken_images: Tracks URLs that fail validation to prevent repeated serving of broken content
-- failure_count: Number of times this URL has failed validation
-- is_blacklisted: Whether this URL should be excluded from meme pool  
-- blacklisted_until: Temporary blacklist expiration (NULL = permanent)
