-- P2 Performance Indexes (fixed: removed IMMUTABLE predicate, non-existent columns)
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending_calc ON meme_stats(updated_at DESC, likes DESC, views DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_title_gin ON meme_stats USING gin(to_tsvector('english', COALESCE(title, '')));
CREATE INDEX IF NOT EXISTS idx_user_levels_leaderboard ON user_levels(total_xp DESC, user_id);
CREATE INDEX IF NOT EXISTS idx_meme_stats_category_trending ON meme_stats(subreddit, updated_at DESC, likes DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_hot ON meme_stats(updated_at, likes, views) WHERE views > 0 AND likes > 0;
