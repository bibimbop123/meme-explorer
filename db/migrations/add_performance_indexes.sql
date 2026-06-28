-- Performance Indexes (fixed: user_streaks may already exist via add_gamification_tables)
CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_user_meme_perf ON user_meme_exposure(user_id, meme_url);
CREATE INDEX IF NOT EXISTS idx_user_streaks_user_date ON user_streaks(user_id, last_visit_date);
CREATE INDEX IF NOT EXISTS idx_saved_memes_user_saved_perf ON saved_memes(user_id, saved_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending_perf ON meme_stats((likes * 2 + views) DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_fresh_perf ON meme_stats(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_liked_perf ON user_meme_stats(user_id, liked, liked_at DESC);
CREATE INDEX IF NOT EXISTS idx_broken_images_cleanup ON broken_images(failure_count, first_failed_at);
