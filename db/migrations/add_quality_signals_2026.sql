-- Phase 2: Quality Signals Migration
-- Adds meme_quality_signals table for crowdsourced quality tracking
-- Created: June 3, 2026

-- Create quality signals table
CREATE TABLE IF NOT EXISTS meme_quality_signals (
  id SERIAL PRIMARY KEY,
  meme_url TEXT NOT NULL,
  signal_type VARCHAR(50) NOT NULL,  -- 'like', 'save', 'share', 'skip_fast', 'report'
  user_id INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_quality_signals_meme 
ON meme_quality_signals(meme_url);

CREATE INDEX IF NOT EXISTS idx_quality_signals_type 
ON meme_quality_signals(signal_type);

CREATE INDEX IF NOT EXISTS idx_quality_signals_user 
ON meme_quality_signals(user_id);

CREATE INDEX IF NOT EXISTS idx_quality_signals_created 
ON meme_quality_signals(created_at DESC);

-- Composite index for aggregations
CREATE INDEX IF NOT EXISTS idx_quality_signals_meme_type 
ON meme_quality_signals(meme_url, signal_type);

-- Add comments for documentation
COMMENT ON TABLE meme_quality_signals IS 'Crowdsourced quality signals from user interactions';
COMMENT ON COLUMN meme_quality_signals.signal_type IS 'Type of signal: like, save, share, skip_fast, report';
COMMENT ON COLUMN meme_quality_signals.user_id IS 'Optional user ID for personalization';
