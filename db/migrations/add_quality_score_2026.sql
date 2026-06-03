-- Phase 1: Quality Score Tracking Migration
-- Adds quality_score column to meme_stats for tracking meme quality
-- Created: June 3, 2026

-- Add quality_score column to meme_stats table
ALTER TABLE meme_stats 
ADD COLUMN IF NOT EXISTS quality_score DECIMAL(10,2) DEFAULT 0.0;

-- Add index for quality score queries (important for performance)
CREATE INDEX IF NOT EXISTS idx_quality_score 
ON meme_stats(quality_score DESC);

-- Add composite index for quality-filtered queries
CREATE INDEX IF NOT EXISTS idx_quality_likes_composite 
ON meme_stats(quality_score DESC, likes DESC, updated_at DESC);

-- Add index for fresh high-quality memes
CREATE INDEX IF NOT EXISTS idx_fresh_quality 
ON meme_stats(updated_at DESC, quality_score DESC)
WHERE failure_count < 2;

-- Update existing rows to have default quality score
UPDATE meme_stats 
SET quality_score = 50.0 
WHERE quality_score = 0.0 OR quality_score IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN meme_stats.quality_score IS 'Quality score from 0-100 based on 6-stage quality pipeline validation';
