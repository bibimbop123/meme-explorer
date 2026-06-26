-- Performance Metrics Table
-- Tracks application performance metrics for monitoring

CREATE TABLE IF NOT EXISTS performance_metrics (
  id SERIAL PRIMARY KEY,
  operation VARCHAR(255) NOT NULL,
  duration_ms DECIMAL(10,2) NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_performance_operation ON performance_metrics(operation);
CREATE INDEX IF NOT EXISTS idx_performance_duration ON performance_metrics(duration_ms);
CREATE INDEX IF NOT EXISTS idx_performance_created_at ON performance_metrics(created_at);

-- Cleanup old metrics (keep last 7 days)
CREATE OR REPLACE FUNCTION cleanup_old_performance_metrics()
RETURNS void AS $$
BEGIN
  DELETE FROM performance_metrics
  WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE performance_metrics IS 'Tracks application performance metrics';
COMMENT ON COLUMN performance_metrics.operation IS 'Name of the operation being tracked';
COMMENT ON COLUMN performance_metrics.duration_ms IS 'Duration in milliseconds';
COMMENT ON COLUMN performance_metrics.metadata IS 'Additional context (JSON)';
