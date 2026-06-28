-- Phase 2 Performance Optimization (fixed: removed references to non-existent memes table)
-- The memes table does not exist; meme data lives in meme_stats and the YAML cache
CREATE INDEX IF NOT EXISTS idx_phase2_meme_stats_quality ON meme_stats(quality_score DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_phase2_meme_stats_composite ON meme_stats(updated_at DESC, likes DESC, views DESC);
CREATE INDEX IF NOT EXISTS idx_phase2_user_meme_exp_shown ON user_meme_exposure(user_id, shown_count);
