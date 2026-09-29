# lib/services/retention_service.rb
#
# Phase 1 roadmap item (ROADMAP.md): "Instrument retention (daily return
# rate, session length) alongside the existing latency benchmarks.
# Latency proves the loop is fast; retention proves the loop is actually
# *better* for the user, which is the real test of a monopoly-shaped
# product versus a merely functional one."
#
# NOTE: this is a new, real implementation - not the old, removed
# `RetentionService` referenced by lib/controllers/random_meme_controller.rb
# (that class backed a different, gamification-era feature and was
# deleted during a prior "Elon audit" cleanup; the controller's `require`
# is wrapped in a `rescue LoadError` specifically so a *future*
# reintroduction under the same filename wouldn't silently break it - see
# the comment there). This service is unrelated to that one and is wired
# up fresh into /metrics below.
#
# Data source: `meme_activity_log` (id, meme_url, activity_type, user_id,
# session_id, created_at) - already real, live, and populated on every
# view/like across the app (see routes/home.rb, routes/random_meme.rb).
# No new table or tracking call needed; this only aggregates what's
# already being recorded.
module RetentionService
  extend self

  # D1 retention: of the distinct logged-in users active on each day in
  # the window, what fraction were ALSO active the very next calendar
  # day? This is the standard "daily return rate" metric - the actual
  # test of whether personalization is working, not just fast.
  #
  # Anonymous activity (user_id IS NULL, i.e. not-logged-in sessions) is
  # excluded: return-rate is only meaningful for identities that can
  # actually be observed returning across days. Session-based
  # anonymous retention would require a different, longer-lived
  # identifier than the current per-process session_id and is out of
  # scope here.
  #
  # Returns { days: [{ date:, active_users:, returned_next_day:,
  # return_rate_pct: }], overall_return_rate_pct:, window_days: } or a
  # safe all-nil/empty shape on any DB error (never raises - this is a
  # dashboard metric, not a critical path).
  def daily_return_rate(window_days: 14)
    query = <<~SQL
      WITH active_days AS (
        SELECT DISTINCT user_id, DATE(created_at) AS active_date
        FROM meme_activity_log
        WHERE user_id IS NOT NULL
          AND created_at >= NOW() - INTERVAL '#{window_days.to_i + 1} days'
      )
      SELECT
        a.active_date,
        COUNT(DISTINCT a.user_id) AS active_users,
        COUNT(DISTINCT b.user_id) AS returned_next_day
      FROM active_days a
      LEFT JOIN active_days b
        ON b.user_id = a.user_id
        AND b.active_date = a.active_date + INTERVAL '1 day'
      WHERE a.active_date >= CURRENT_DATE - INTERVAL '#{window_days.to_i} days'
        AND a.active_date < CURRENT_DATE
      GROUP BY a.active_date
      ORDER BY a.active_date ASC
    SQL

    rows = DB_POOL.with { |conn| conn.exec(query).map { |row| row.transform_keys(&:to_sym) } }

    days = rows.map do |row|
      active = row[:active_users].to_i
      returned = row[:returned_next_day].to_i
      {
        date: row[:active_date],
        active_users: active,
        returned_next_day: returned,
        return_rate_pct: active > 0 ? ((returned.to_f / active) * 100).round(1) : nil
      }
    end

    total_active = days.sum { |d| d[:active_users] }
    total_returned = days.sum { |d| d[:returned_next_day] }

    {
      days: days,
      overall_return_rate_pct: total_active > 0 ? ((total_returned.to_f / total_active) * 100).round(1) : nil,
      window_days: window_days
    }
  rescue => e
    AppLogger.error("RetentionService.daily_return_rate failed", error: e.message, backtrace: e.backtrace&.first(3)) if defined?(AppLogger)
    { days: [], overall_return_rate_pct: nil, window_days: window_days }
  end

  # Average session length in minutes, approximated as the time between
  # a logged-in user's first and last recorded activity within each
  # calendar day (a genuine multi-event session-length proxy would need
  # an explicit session-boundary concept the schema doesn't have; this
  # is the honest approximation available from existing data, and is
  # labeled as such wherever it's surfaced).
  def avg_session_length_minutes(window_days: 14)
    query = <<~SQL
      SELECT AVG(EXTRACT(EPOCH FROM (day_last - day_first)) / 60.0) AS avg_minutes
      FROM (
        SELECT
          user_id,
          DATE(created_at) AS active_date,
          MIN(created_at) AS day_first,
          MAX(created_at) AS day_last
        FROM meme_activity_log
        WHERE user_id IS NOT NULL
          AND created_at >= NOW() - INTERVAL '#{window_days.to_i} days'
        GROUP BY user_id, DATE(created_at)
        HAVING COUNT(*) > 1
      ) per_user_day
    SQL

    value = DB_POOL.with { |conn| conn.exec(query).first&.[]('avg_minutes') }
    value.nil? ? nil : value.to_f.round(1)
  rescue => e
    AppLogger.error("RetentionService.avg_session_length_minutes failed", error: e.message, backtrace: e.backtrace&.first(3)) if defined?(AppLogger)
    nil
  end
end
