      -- Performance Indexes
      -- Created: July 26, 2026
      -- Critical indexes for production performance

      CREATE INDEX IF NOT EXISTS idx_meme_stats_url ON meme_stats(url);
      CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit ON meme_stats(subreddit);
      CREATE INDEX IF NOT EXISTS idx_meme_stats_quality ON meme_stats(quality_score DESC);
      CREATE INDEX IF NOT EXISTS idx_user_interactions_user_id ON user_meme_interactions(user_id);
      CREATE INDEX IF NOT EXISTS idx_user_interactions_meme_url ON user_meme_interactions(meme_url);
      CREATE INDEX IF NOT EXISTS idx_sessions_updated ON sessions(updated_at);

      COMMIT;
