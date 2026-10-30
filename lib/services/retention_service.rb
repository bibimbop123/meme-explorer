# frozen_string_literal: true

# Adjacent-day recorded account activity, not new-user cohort retention.
# Historical views may include speculative selection; no attention/enjoyment claim.
module RetentionService
  extend self

  # UTC account-day weighted returns; only fully observed next days.
  def daily_return_rate(window_days: 14, now: Time.now)
    window_days = [[window_days.to_i, 1].max, 365].min
    utc = now.getutc
    finish = Time.utc(utc.year, utc.month, utc.day)
    cohort_end = finish - 86_400
    start = cohort_end - window_days * 86_400
    query = <<~SQL
      WITH active_days AS (
        SELECT DISTINCT user_id, DATE(created_at AT TIME ZONE 'UTC') AS active_date
        FROM meme_activity_log
        WHERE user_id IS NOT NULL
          AND activity_type IN ('view','like','unlike','save','unsave')
          AND created_at >= $1::timestamptz AND created_at < $2::timestamptz
      )
      SELECT
        a.active_date,
        COUNT(DISTINCT a.user_id) AS active_users,
        COUNT(DISTINCT b.user_id) AS returned_next_day
      FROM active_days a
      LEFT JOIN active_days b
        ON b.user_id = a.user_id
        AND b.active_date = a.active_date + INTERVAL '1 day'
      WHERE a.active_date < ($3::timestamptz AT TIME ZONE 'UTC')::date
      GROUP BY a.active_date
      ORDER BY a.active_date ASC
    SQL

    rows = DB_POOL.with { |conn| conn.exec_params(query, [start.iso8601, finish.iso8601, cohort_end.iso8601]).map { |row| row.transform_keys(&:to_sym) } }

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
      window_days: window_days,
      eligible_account_days: total_active, returned_account_days: total_returned,
      timezone: 'UTC', available: true,
      cohort_start: start.iso8601, cohort_end_exclusive: cohort_end.iso8601,
      observed_until_exclusive: finish.iso8601
    }
  rescue => e
    AppLogger.error("RetentionService.daily_return_rate failed", error: e.message, backtrace: e.backtrace&.first(3)) if defined?(AppLogger)
    { days: [], overall_return_rate_pct: nil, window_days: window_days, available: false }
  end

  # Average session length in minutes, approximated as the time between
  # a logged-in user's first and last recorded activity within each
  # calendar day (a genuine multi-event session-length proxy would need
  # an explicit session-boundary concept the schema doesn't have; this
  # is the honest approximation available from existing data, and is
  # labeled as such wherever it's surfaced).
  def avg_session_length_minutes(window_days: 14, now: Time.now)
    finish = now.getutc
    start = finish - [[window_days.to_i, 1].max, 365].min * 86_400
    query = <<~SQL
      SELECT AVG(EXTRACT(EPOCH FROM (day_last - day_first)) / 60.0) AS avg_minutes
      FROM (
        SELECT
          user_id,
          DATE(created_at AT TIME ZONE 'UTC') AS active_date,
          MIN(created_at) AS day_first,
          MAX(created_at) AS day_last
        FROM meme_activity_log
        WHERE user_id IS NOT NULL
          AND activity_type IN ('view','like','unlike','save','unsave')
          AND created_at >= $1::timestamptz AND created_at <= $2::timestamptz
        GROUP BY user_id, DATE(created_at AT TIME ZONE 'UTC')
        HAVING COUNT(*) > 1
      ) per_user_day
    SQL

    value = DB_POOL.with { |conn| conn.exec_params(query, [start.iso8601, finish.iso8601]).first&.[]('avg_minutes') }
    value.nil? ? nil : value.to_f.round(1)
  rescue => e
    AppLogger.error("RetentionService.avg_session_length_minutes failed", error: e.message, backtrace: e.backtrace&.first(3)) if defined?(AppLogger)
    nil
  end

  # 7-day conversion funnel & session depth from recorded meme_activity_log events
  def engagement_funnel(window_days: 7, now: Time.now)
    window_days = [[window_days.to_i, 1].max, 365].min
    finish = now.getutc
    start = finish - window_days * 86_400
    query = <<~SQL
      SELECT
        COUNT(*) FILTER (WHERE activity_type = 'view') AS views,
        COUNT(*) FILTER (WHERE activity_type = 'like') AS likes,
        COUNT(*) FILTER (WHERE activity_type = 'save') AS saves,
        COUNT(DISTINCT CASE WHEN user_id IS NOT NULL THEN CONCAT(user_id::text, ':', DATE(created_at AT TIME ZONE 'UTC')::text) END) AS active_account_days
      FROM meme_activity_log
      WHERE activity_type IN ('view','like','unlike','save','unsave')
        AND created_at >= $1::timestamptz AND created_at <= $2::timestamptz
    SQL

    row = DB_POOL.with { |conn| conn.exec_params(query, [start.iso8601, finish.iso8601]).first } || {}
    views = row['views'].to_i
    likes = row['likes'].to_i
    saves = row['saves'].to_i
    account_days = row['active_account_days'].to_i

    {
      window_days: window_days,
      views: views,
      likes: likes,
      saves: saves,
      like_conversion_pct: views > 0 ? ((likes.to_f / views) * 100).round(2) : nil,
      save_conversion_pct: views > 0 ? ((saves.to_f / views) * 100).round(2) : nil,
      avg_views_per_account_day: account_days > 0 ? (views.to_f / account_days).round(1) : nil,
      available: true
    }
  rescue => e
    AppLogger.error("RetentionService.engagement_funnel failed", error: e.message) if defined?(AppLogger)
    { window_days: window_days, views: 0, likes: 0, saves: 0, like_conversion_pct: nil, save_conversion_pct: nil, avg_views_per_account_day: nil, available: false }
  end
end
