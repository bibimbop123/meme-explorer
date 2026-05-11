-- A/B Testing Framework Database Schema
-- Created: May 11, 2026
-- Purpose: Support data-driven feature development with A/B testing

-- Experiments table: defines A/B tests
CREATE TABLE IF NOT EXISTS experiments (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  variants JSONB NOT NULL,  -- {"control": 0.5, "variant_a": 0.5}
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Experiment assignments: tracks which variant each user sees
CREATE TABLE IF NOT EXISTS experiment_assignments (
  id SERIAL PRIMARY KEY,
  experiment_id INTEGER REFERENCES experiments(id) ON DELETE CASCADE,
  user_identifier VARCHAR(255) NOT NULL,  -- session_id or user_id
  variant VARCHAR(50) NOT NULL,
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(experiment_id, user_identifier)
);

-- Experiment conversions: tracks user actions/conversions
CREATE TABLE IF NOT EXISTS experiment_conversions (
  id SERIAL PRIMARY KEY,
  experiment_id INTEGER REFERENCES experiments(id) ON DELETE CASCADE,
  user_identifier VARCHAR(255) NOT NULL,
  variant VARCHAR(50) NOT NULL,
  conversion_type VARCHAR(100) NOT NULL,  -- "meme_like", "signup", "share", etc.
  metadata JSONB,  -- Additional context data
  converted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_assignments_experiment_user 
  ON experiment_assignments(experiment_id, user_identifier);

CREATE INDEX IF NOT EXISTS idx_conversions_experiment 
  ON experiment_conversions(experiment_id);

CREATE INDEX IF NOT EXISTS idx_conversions_variant 
  ON experiment_conversions(experiment_id, variant);

CREATE INDEX IF NOT EXISTS idx_experiments_active 
  ON experiments(active);

-- Sample data: Create a test experiment
INSERT INTO experiments (name, description, variants, active)
VALUES (
  'trending_page_cta',
  'Test different CTA button colors on trending page',
  '{"control": 0.5, "blue_button": 0.5}',
  false
) ON CONFLICT (name) DO NOTHING;

COMMENT ON TABLE experiments IS 'Stores A/B test experiment definitions';
COMMENT ON TABLE experiment_assignments IS 'Tracks which variant each user is assigned to';
COMMENT ON TABLE experiment_conversions IS 'Tracks conversion events for A/B test analysis';
