# routes/metrics_routes.rb
# Metrics, monitoring, and notification endpoints

module Routes
  module MetricsRoutes
    def self.registered(app)
      # Metrics JSON API
      app.get "/metrics.json" do
        total_memes = MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0
        total_likes = MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats") || 0
        total_views = MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats") || 0

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
        @top_memes           = []
        @top_subreddits      = []

        begin
          if defined?(MemeExplorer::App::DB) && MemeExplorer::App::DB
            # Get time period filter
            period = params[:period] || 'all'
            
            # Check if activity log table exists for accurate time-based filtering
            has_activity_log = MemeExplorer::App::DB.get_first_value(
              "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'meme_activity_log'"
            ).to_i > 0 rescue false
            
            if has_activity_log && period != 'all'
              # Use activity log for accurate time-based metrics (SQLite syntax)
              time_filter = case period
                           when '24h' then "WHERE created_at >= datetime('now', '-1 day')"
                           when '7d' then "WHERE created_at >= datetime('now', '-7 days')"
                           when '30d' then "WHERE created_at >= datetime('now', '-30 days')"
                           else ""
                           end
              
              @total_views = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(*) FROM meme_activity_log #{time_filter} AND activity_type = 'view'"
              ) || 0).to_i
              
              @total_likes = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(*) FROM meme_activity_log #{time_filter} AND activity_type = 'like'"
              ) || 0).to_i
              
              @total_memes = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(DISTINCT meme_url) FROM meme_activity_log #{time_filter}"
              ) || 0).to_i
            else
              # Fallback to meme_stats (all-time or if activity log doesn't exist)
              where_clause = case period
                            when '24h' then "WHERE updated_at >= datetime('now', '-1 day')"
                            when '7d' then "WHERE updated_at >= datetime('now', '-7 days')"
                            when '30d' then "WHERE updated_at >= datetime('now', '-30 days')"
                            else ""
                            end
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
            
            # Get chart data based on selected period
            @chart_dates = []
            @chart_views = []
            @chart_likes = []
            
            # Determine chart range based on period - USE ACTIVITY LOG for accurate time-based data
            if has_activity_log && period != 'all'
              case period
              when '24h'
                # Show last 24 hours (hourly) - from activity log
                23.downto(0) do |hours_ago|
                  time = Time.now.utc - (hours_ago * 3600)
                  date = (Time.now - (hours_ago * 3600)).strftime('%I %p')  # Display in local time
                  date_start = time.strftime('%Y-%m-%d %H:00:00')
                  date_end = time.strftime('%Y-%m-%d %H:59:59')
                  
                  hourly_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  hourly_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'like' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << hourly_views
                  @chart_likes << hourly_likes
                end
              when '7d'
                # Show last 7 days (daily) - from activity log
                6.downto(0) do |days_ago|
                  date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
                  date_start = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
                  date_end = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
                  
                  daily_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  daily_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'like' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << daily_views
                  @chart_likes << daily_likes
                end
              when '30d'
                # Show last 30 days (daily) - from activity log
                29.downto(0) do |days_ago|
                  date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
                  date_start = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
                  date_end = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
                  
                  daily_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  daily_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'like' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << daily_views
                  @chart_likes << daily_likes
                end
              end
            else
              # Fallback to meme_stats approach (less accurate but works without activity log)
              case period
              when '24h'
                23.downto(0) do |hours_ago|
                  time = Time.now.utc - (hours_ago * 3600)
                  date = (Time.now - (hours_ago * 3600)).strftime('%I %p')  # Display in local time
                  date_start = time.strftime('%Y-%m-%d %H:00:00')
                  date_end = time.strftime('%Y-%m-%d %H:59:59')
                  
                  hourly_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(views), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  hourly_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(likes), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << hourly_views
                  @chart_likes << hourly_likes
                end
              when '7d'
                6.downto(0) do |days_ago|
                  date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
                  date_start = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
                  date_end = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
                  
                  daily_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(views), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  daily_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(likes), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << daily_views
                  @chart_likes << daily_likes
                end
              when '30d', 'all'
                29.downto(0) do |days_ago|
                  date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
                  date_start = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
                  date_end = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
                  
                  daily_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(views), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  daily_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(likes), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << daily_views
                  @chart_likes << daily_likes
                end
              end
            end
            
            # Store period for view
            @chart_period = period

            # Top memes (DB already returns hashes with results_as_hash = true)
            # FIXED: Only show real Reddit memes with external URLs (not local YAML fallbacks)
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
          puts "Metrics error: #{e.class}: #{e.message}"
        end

        erb :metrics
      end

      # CSV Export endpoint
      app.get "/metrics/export" do
        require 'csv'
        
        period = params[:period] || 'all'
        period_label = case period
                      when '24h' then 'Last 24 Hours'
                      when '7d' then 'Last 7 Days'
                      when '30d' then 'Last 30 Days'
                      else 'All Time'
                      end
        
        where_clause = case period
                      when '24h' then "WHERE updated_at >= datetime('now', '-1 day')"
                      when '7d' then "WHERE updated_at >= datetime('now', '-7 days')"
                      when '30d' then "WHERE updated_at >= datetime('now', '-30 days')"
                      else ""
                      end
        
        # Get metrics
        total_memes = MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause}") || 0
        total_likes = MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats #{where_clause}") || 0
        total_views = MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats #{where_clause}") || 0
        
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
        halt 401, { error: "Not logged in" }.to_json unless session[:user_id]
        user_id = session[:user_id]
        
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
