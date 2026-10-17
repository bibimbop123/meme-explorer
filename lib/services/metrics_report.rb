# frozen_string_literal: true
require 'time'

# Stored totals are snapshots; only activity rows support historical windows.
class MetricsReport
  PERIODS = { 'all' => nil, '24h' => 86_400, '7d' => 604_800, '30d' => 2_592_000 }.freeze

  def self.build(period:, db: DB, now: Time.now.utc)
    raise ArgumentError, 'Invalid metrics period' unless PERIODS.key?(period)

    finish = now.utc
    start = PERIODS[period] && finish - PERIODS.fetch(period)
    condition = 'created_at <= ?'
    args = [finish.iso8601(6)]
    if start
      condition += ' AND created_at >= ?'
      args << start.iso8601(6)
    end
    totals = if period == 'all'
      db.execute('SELECT COUNT(*) AS total_memes, COALESCE(SUM(likes),0) AS total_likes, COALESCE(SUM(views),0) AS total_views FROM meme_stats').first
    else
      db.execute("SELECT COUNT(DISTINCT meme_url) AS total_memes, COUNT(*) FILTER (WHERE activity_type = 'like') AS total_likes, COUNT(*) FILTER (WHERE activity_type = 'view') AS total_views FROM meme_activity_log WHERE #{condition} AND activity_type IN ('view','like','unlike','save','unsave')", args).first
    end
    report = totals.transform_keys(&:to_sym).transform_values(&:to_i)
    count = report[:total_memes]
    report.merge!(period: period, generated_at: finish.iso8601, window_start: start&.iso8601,
      source: period == 'all' ? 'cumulative stored counters' : 'recorded activity events',
      total_users: db.get_first_value('SELECT COUNT(*) FROM users').to_i,
      total_saved_memes: db.get_first_value('SELECT COUNT(*) FROM saved_memes').to_i,
      memes_with_no_likes: db.get_first_value('SELECT COUNT(*) FROM meme_stats WHERE likes = 0').to_i,
      memes_with_no_views: db.get_first_value('SELECT COUNT(*) FROM meme_stats WHERE views = 0').to_i,
      avg_likes: count.positive? ? (report[:total_likes].to_f / count).round(2) : 0,
      avg_views: count.positive? ? (report[:total_views].to_f / count).round(2) : 0,
      engagement_rate: report[:total_views].positive? ? (100.0 * report[:total_likes] / report[:total_views]).round(2) : nil)

    # Keep all-time charts bounded, but explicitly label their shorter scope.
    chart_start = start || finish - PERIODS.fetch('30d')
    unit = period == '24h' ? 'hour' : 'day'
    step = unit == 'hour' ? 3600 : 86_400
    rows = db.execute("SELECT date_trunc('#{unit}', created_at AT TIME ZONE 'UTC') AS bucket, COUNT(*) FILTER (WHERE activity_type = 'view') AS views, COUNT(*) FILTER (WHERE activity_type = 'like') AS likes FROM meme_activity_log WHERE created_at >= ? AND created_at <= ? GROUP BY bucket", [chart_start.iso8601(6), finish.iso8601(6)])
    lookup = rows.to_h { |row| [Time.parse("#{row['bucket']} UTC").to_i, row] }
    dates, views, likes = [], [], []
    bucket = Time.at((chart_start.to_i / step) * step).utc
    while bucket <= finish
      row = lookup[bucket.to_i] || {}
      dates << bucket.strftime(unit == 'hour' ? '%Y-%m-%d %H:00 UTC' : '%Y-%m-%d UTC')
      views << row.fetch('views', 0).to_i
      likes << row.fetch('likes', 0).to_i
      bucket += step
    end
    report.merge!(chart_dates: dates, chart_views: views, chart_likes: likes)

    ranking = if period == 'all'
      'SELECT url, title, subreddit, likes, views FROM meme_stats'
    else
      "SELECT a.meme_url AS url, MAX(s.title) AS title, MAX(s.subreddit) AS subreddit, COUNT(*) FILTER (WHERE a.activity_type = 'like') AS likes, COUNT(*) FILTER (WHERE a.activity_type = 'view') AS views FROM meme_activity_log a LEFT JOIN meme_stats s ON s.url = a.meme_url WHERE #{condition.gsub('created_at', 'a.created_at')} AND a.activity_type IN ('view','like','unlike','save','unsave') GROUP BY a.meme_url"
    end
    rankings = db.execute("SELECT * FROM (#{ranking}) ranked ORDER BY (likes * 2 + views) DESC, url LIMIT 10", period == 'all' ? [] : args)
    report[:top_memes] = rankings
    report[:top_subreddits] = db.execute("SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count FROM (#{ranking}) ranked WHERE subreddit IS NOT NULL GROUP BY subreddit ORDER BY total_likes DESC, subreddit LIMIT 10", period == 'all' ? [] : args)
    report
  end
end