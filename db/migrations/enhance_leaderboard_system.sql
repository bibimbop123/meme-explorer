-- Enhanced Leaderboard System
-- Fixed: monthly_leaderboard exists with total_xp column (not metric_value)
-- weekly_leaderboard exists with metric_value column
CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_week_rank ON weekly_leaderboard(week_number, metric_value DESC);
CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_user ON weekly_leaderboard(user_id, week_number);
CREATE INDEX IF NOT EXISTS idx_monthly_leaderboard_month_xp ON monthly_leaderboard(month_number, total_xp DESC);
CREATE INDEX IF NOT EXISTS idx_monthly_leaderboard_user ON monthly_leaderboard(user_id, month_number);
