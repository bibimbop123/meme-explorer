CREATE TABLE IF NOT EXISTS browser_visitor_collection (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS browser_visitors (
  visitor_key VARCHAR(64) PRIMARY KEY,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS browser_visitors_last_seen ON browser_visitors(last_seen_at);