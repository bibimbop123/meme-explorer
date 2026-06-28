# frozen_string_literal: true

# Materialized View Refresh Worker
# Refreshes PostgreSQL materialized views for optimal query performance
# Part of Phase 2 performance optimization

class MaterializedViewRefreshWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :maintenance, retry: 3
  
  VIEWS = {
    trending_memes_hourly: { interval: 3600, priority: :high },
    leaderboard_hourly: { interval: 3600, priority: :high },
    category_stats_daily: { interval: 86400, priority: :medium }
  }.freeze

  # Refresh all views
  def perform(view_name = 'all')
    if view_name == 'all'
      refresh_all_views
    else
      refresh_single_view(view_name.to_sym)
    end
  end

  private

  def refresh_all_views
    start_time = Time.now
    results = {}

    VIEWS.each_key do |view|
      begin
        refresh_single_view(view)
        results[view] = :success
      rescue => e
        AppLogger.error("Failed to refresh view #{view}: #{e.message}")
        results[view] = :failed
        # Don't raise, continue with other views
      end
    end

    duration = Time.now - start_time
    AppLogger.info("Materialized view refresh complete in #{duration.round(2)}s: #{results}")
    
    results
  end

  def refresh_single_view(view_name)
    unless VIEWS.key?(view_name)
      raise ArgumentError, "Unknown view: #{view_name}"
    end

    start_time = Time.now
    
    # Use CONCURRENTLY to avoid locking the view
    DB.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY #{view_name}")

    duration = Time.now - start_time

    # Track refresh metrics
    track_refresh_metrics(view_name, duration)

    AppLogger.info("Refreshed #{view_name} in #{duration.round(3)}s")

    duration
  rescue PG::Error => e
    # Handle case where CONCURRENTLY fails (e.g., no unique index)
    if e.message.include?('CONCURRENTLY') || e.message.include?('unique index')
      AppLogger.warn("CONCURRENTLY failed for #{view_name}, trying regular refresh")
      DB.execute("REFRESH MATERIALIZED VIEW #{view_name}")
    else
      raise
    end
  end

  def track_refresh_metrics(view_name, duration)
    DB.execute(
      "INSERT INTO materialized_view_refreshes (view_name, duration_seconds, refreshed_at, row_count) VALUES (?, ?, ?, ?)",
      [view_name.to_s, duration, Time.now, get_view_row_count(view_name)]
    )
  rescue => e
    AppLogger.warn("Failed to track metrics for #{view_name}: #{e.message}")
  end

  def get_view_row_count(view_name)
    DB.get_first_value("SELECT COUNT(*) FROM #{view_name}").to_i
  rescue
    nil
  end

  # Schedule all view refreshes
  def self.schedule_all_refreshes
    VIEWS.each do |view_name, config|
      interval = config[:interval]
      
      # Schedule based on interval
      if interval <= 3600 # Hourly
        # Schedule to run every hour
        perform_in(rand(60), view_name.to_s)
      elsif interval <= 86400 # Daily
        # Schedule to run daily at 3 AM
        seconds_until_3am = Time.parse('03:00:00').to_i - Time.now.to_i
        seconds_until_3am += 86400 if seconds_until_3am < 0
        perform_in(seconds_until_3am, view_name.to_s)
      end
    end
  end

  # Check if a view needs refresh based on last refresh time
  def self.needs_refresh?(view_name)
    last_refresh = DB.execute(
      "SELECT refreshed_at FROM materialized_view_refreshes WHERE view_name = ? ORDER BY refreshed_at DESC LIMIT 1",
      [view_name.to_s]
    ).first

    return true unless last_refresh # Never refreshed

    interval = VIEWS[view_name.to_sym][:interval]
    Time.now - Time.parse(last_refresh['refreshed_at'].to_s) >= interval
  rescue
    true
  end

  # Manual refresh endpoint for admin
  def self.refresh_now(view_name = 'all')
    perform_async(view_name)
  end
end
