-- Ad Impressions Table
-- Tracks ad impressions for revenue analytics

CREATE TABLE IF NOT EXISTS ad_impressions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER,
  page VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ad_impressions_created_at ON ad_impressions(created_at);
CREATE INDEX IF NOT EXISTS idx_ad_impressions_user_id ON ad_impressions(user_id);
CREATE INDEX IF NOT EXISTS idx_ad_impressions_page ON ad_impressions(page);

-- Cleanup old impressions (keep last 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_ad_impressions()
RETURNS void AS $$
BEGIN
  DELETE FROM ad_impressions
  WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE ad_impressions IS 'Tracks ad impressions for revenue analytics';
COMMENT ON COLUMN ad_impressions.user_id IS 'User who saw the ad (nullable for anonymous)';
COMMENT ON COLUMN ad_impressions.page IS 'Page where ad was displayed';
