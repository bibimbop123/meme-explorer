-- P0 Critical Indexes (fixed: removed indexes on non-existent users columns)
-- role/xp/level/streak_days live in user_levels/user_streaks, not users
CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_user_meme ON user_meme_exposure(user_id, meme_url);
CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_liked ON user_meme_stats(user_id, liked, liked_at DESC);
CREATE INDEX IF NOT EXISTS idx_saved_memes_user_saved ON saved_memes(user_id, saved_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending ON meme_stats((likes * 2 + views) DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_fresh ON meme_stats(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_levels_xp ON user_levels(total_xp DESC);
CREATE INDEX IF NOT EXISTS idx_user_streaks_current ON user_streaks(current_streak DESC);
