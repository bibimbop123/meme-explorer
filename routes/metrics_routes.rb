# routes/metrics_routes.rb
# Metrics, monitoring, and notification endpoints

module Routes
  module MetricsRoutes
    # Single source of truth for period -> WHERE clause translation.
    # Avoids copy/pasted case-statements that used to live in 4+ places in
    # this file and could drift out of sync with each other.
    def self.where_clause_for(period, column)
      case period
      when '24h' then "WHERE #{column} >= NOW() - INTERVAL '1 day'"
      when '7d'  then "WHERE #{column} >= NOW() - INTERVAL '7 days'"
      when '30d' then "WHERE #{column} >= NOW() - INTERVAL '30 days'"
      else ""
      end
    end

    def self.registered(app)
      # Metrics JSON API
      app.get "/metrics.json" do
        require_auth!

        total_memes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0).to_i
        total_likes = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats") || 0).to_i
        total_views = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats") || 0).to_i

        avg_likes = total_memes > 0 ? (total_likes.to_f / total_memes).round(2) : 0
        avg_views = total_memes > 0 ? (total_views.to_f / total_memes).round(2) : 0

        content_type :json
        {
          total_memes: total_memes,
          total_likes: total_likes,
          total_views: total_views,
          avg_likes: avg_likes,
          avg_views: avg_views
        }.to_json
      end


      # Metrics HTML page
      app.get "/metrics" do
        require_auth!

        # Initialize defaults first
        @total_memes         = 0
        @total_likes         = 0
        @total_views         = 0
        @total_users         = 0
        @total_saved_memes   = 0
        @memes_with_no_likes = 0
        @memes_with_no_views = 0
        @avg_likes           = 0
        @avg_views           = 0
        @engagement_rate     = 0
        @top_memes           = []
        @top_subreddits      = []
        @chart_dates         = []
        @chart_views         = []
        @chart_likes         = []

        period = params[:period] || 'all'
        @chart_period = period

        # Assigned unconditionally (fixes a bug where where_clause was only
        # set inside the meme_stats fallback branch, causing a NameError —
        # silently swallowed by the rescue below — whenever the activity-log
        # branch was taken with a non-'all' period).
        where_clause = MetricsRoutes.where_clause_for(period, 'updated_at')

        begin
          if defined?(MemeExplorer::App::DB) && MemeExplorer::App::DB
            # Check if activity log table exists for accurate time-based filtering
            has_activity_log = MemeExplorer::App::DB.get_first_value(
              "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'meme_activity_log'"
            ).to_i > 0 rescue false

            if has_activity_log && period != 'all'
              # Use activity log for accurate time-based metrics
              activity_time_filter = MetricsRoutes.where_clause_for(period, 'created_at')

              @total_views = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(*) FROM meme_activity_log #{activity_time_filter} AND activity_type = 'view'"
              ) || 0).to_i

              @total_likes = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(*) FROM meme_activity_log #{activity_time_filter} AND activity_type = 'like'"
              ) || 0).to_i

              @total_memes = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(DISTINCT meme_url) FROM meme_activity_log #{activity_time_filter}"
              ) || 0).to_i
            else
              # Fallback to meme_stats (all-time or if activity log doesn't exist)
              @total_memes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause}") || 0).to_i
              @total_likes = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats #{where_clause}") || 0).to_i
              @total_views = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats #{where_clause}") || 0).to_i
            end
            @total_users = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM users") || 0).to_i
            @total_saved_memes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM saved_memes") || 0).to_i
            @memes_with_no_likes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause.empty? ? 'WHERE' : where_clause + ' AND'} likes = 0") || 0).to_i
            @memes_with_no_views = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause.empty? ? 'WHERE' : where_clause + ' AND'} views = 0") || 0).to_i

            # Calculate averages
            @avg_likes = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0.0
            @avg_views = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0.0
            
            # Calculate engagement rate (ensure float)
            @engagement_rate = @total_views > 0 ? ((@total_likes.to_f / @total_views) * 100).round(2) : 0.0
            
            # Get chart data based on selected period.
            # NOTE: Uses a single GROUP BY query per metric instead of one
            # query per time bucket (the old code issued up to 60 sequential
            # queries for the 30-day view — one SELECT per day per metric).
            chart_period = (period == 'all') ? '30d' : period
            bucket_unit = (chart_period == '24h') ? 'hour' : 'day'
            bucket_key = lambda { |t| bucket_unit == 'hour' ? t.utc.strftime('%Y-%m-%d %H') : t.utc.strftime('%Y-%m-%d') }

            if has_activity_log && period != 'all'
              activity_bucket_clause = MetricsRoutes.where_clause_for(chart_period, 'created_at')

              views_by_bucket = MemeExplorer::App::DB.execute("
                SELECT date_trunc('#{bucket_unit}', created_at) AS bucket, COUNT(*) AS cnt
                FROM meme_activity_log
                #{activity_bucket_clause} AND activity_type = 'view'
                GROUP BY bucket
              ").each_with_object({}) { |row, h| h[bucket_key.call(Time.parse(row['bucket']))] = row['cnt'].to_i }

              likes_by_bucket = MemeExplorer::App::DB.execute("
                SELECT date_trunc('#{bucket_unit}', created_at) AS bucket, COUNT(*) AS cnt
                FROM meme_activity_log
                #{activity_bucket_clause} AND activity_type = 'like'
                GROUP BY bucket
              ").each_with_object({}) { |row, h| h[bucket_key.call(Time.parse(row['bucket']))] = row['cnt'].to_i }
            else
              # Fallback to meme_stats approach (less accurate but works without activity log).
              # Single GROUP BY query per metric instead of one query per bucket.
              bucket_clause = MetricsRoutes.where_clause_for(chart_period, 'updated_at')

              views_by_bucket = MemeExplorer::App::DB.execute("
                SELECT date_trunc('#{bucket_unit}', updated_at) AS bucket, COALESCE(SUM(views), 0) AS cnt
                FROM meme_stats
                #{bucket_clause}
                GROUP BY bucket
              ").each_with_object({}) { |row, h| h[bucket_key.call(Time.parse(row['bucket']))] = row['cnt'].to_i }

              likes_by_bucket = MemeExplorer::App::DB.execute("
                SELECT date_trunc('#{bucket_unit}', updated_at) AS bucket, COALESCE(SUM(likes), 0) AS cnt
                FROM meme_stats
                #{bucket_clause}
                GROUP BY bucket
              ").each_with_object({}) { |row, h| h[bucket_key.call(Time.parse(row['bucket']))] = row['cnt'].to_i }
            end

            views_lookup = defined?(views_by_bucket) ? views_by_bucket : {}
            likes_lookup = defined?(likes_by_bucket) ? likes_by_bucket : {}

            if chart_period == '24h'
              23.downto(0) do |hours_ago|
                time = Time.now.utc - (hours_ago * 3600)
                @chart_dates << (Time.now - (hours_ago * 3600)).strftime('%I %p')
                key = bucket_key.call(time)
                @chart_views << (views_lookup[key] || 0)
                @chart_likes << (likes_lookup[key] || 0)
              end
            else
              days = (chart_period == '7d') ? 6 : 29
              days.downto(0) do |days_ago|
                time = Time.now.utc - (days_ago * 86400)
                @chart_dates << (Time.now - (days_ago * 86400)).strftime('%m/%d')
                key = bucket_key.call(time)
                @chart_views << (views_lookup[key] || 0)
                @chart_likes << (likes_lookup[key] || 0)
              end
            end

            # Top memes (DB already returns hashes with results_as_hash = true)
            # Only show real Reddit memes with external URLs (not local YAML fallbacks)
            top_memes_where = where_clause.empty? ? "WHERE" : where_clause + " AND"
            @top_memes = MemeExplorer::App::DB.execute("
              SELECT title, subreddit, url, likes, views
              FROM meme_stats
              #{top_memes_where} (url LIKE 'https://i.redd.it/%'
                OR url LIKE 'https://i.imgur.com/%'
                OR url LIKE 'https://imgur.com/%'
                OR url LIKE 'https://v.redd.it/%'
                OR url LIKE 'https://external-preview.redd.it/%'
                OR url LIKE 'https://preview.redd.it/%')
                AND (likes > 0 OR views >= 10)
                AND title IS NOT NULL
                AND title != 'Unknown'
              ORDER BY (likes * 2 + views) DESC
              LIMIT 10
            ")

            # Top subreddits
            # FIXED: Exclude 'local' fallback subreddit
            subreddit_where = where_clause.empty? ? "WHERE" : where_clause + " AND"
            @top_subreddits = MemeExplorer::App::DB.execute("
              SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
              FROM meme_stats
              #{subreddit_where} subreddit IS NOT NULL
                AND subreddit != 'Unknown'
                AND subreddit != 'local'
              GROUP BY subreddit
              ORDER BY total_likes DESC
              LIMIT 10
            ")
          end
        rescue => e
          AppLogger.error("Metrics error: #{e.class}: #{e.message}")
          AppLogger.error("Backtrace: #{e.backtrace.first(5).join("\n")}")
        end

        erb :metrics, layout: false
      end

      # CSV Export endpoint
      app.get "/metrics/export" do
        require_auth!
        require 'csv'

        period = params[:period] || 'all'
        period_label = case period
                      when '24h' then 'Last 24 Hours'
                      when '7d' then 'Last 7 Days'
                      when '30d' then 'Last 30 Days'
                      else 'All Time'
                      end

        where_clause = MetricsRoutes.where_clause_for(period, 'updated_at')

        begin
          total_memes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause}") || 0).to_i
          total_likes = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats #{where_clause}") || 0).to_i
          total_views = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats #{where_clause}") || 0).to_i
        rescue => e
          AppLogger.error("Metrics export error: #{e.class}: #{e.message}")
          halt 500, "Unable to generate export right now."
        end

        # Generate CSV
        csv_data = CSV.generate do |csv|
          csv << ['Meme Explorer Metrics Report']
          csv << ['Period', period_label]
          csv << ['Generated', Time.now.strftime('%Y-%m-%d %H:%M:%S')]
          csv << []
          csv << ['Metric', 'Value']
          csv << ['Total Memes', total_memes]
          csv << ['Total Likes', total_likes]
          csv << ['Total Views', total_views]
          csv << ['Average Likes', total_memes > 0 ? (total_likes.to_f / total_memes).round(2) : 0]
          csv << ['Average Views', total_memes > 0 ? (total_views.to_f / total_memes).round(2) : 0]
          csv << ['Engagement Rate', total_views > 0 ? ((total_likes.to_f / total_views) * 100).round(2) : 0]
        end

        attachment "meme_metrics_#{period}_#{Time.now.strftime('%Y%m%d')}.csv"
        content_type 'text/csv'
        csv_data
      end

      # User notifications API
      app.get "/api/notifications" do
        require_auth!
        user_id = current_user_id
        
        # Get user notifications (saved count changes, likes, etc.)
        content_type :json
        {
          user_id: user_id,
          saved_count: get_user_saved_memes_count(user_id),
          timestamp: Time.now.iso8601,
          message: "Your profile is up to date"
        }.to_json
      end
    end
  end
end
