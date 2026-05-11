# routes/metrics_routes.rb
# Metrics, monitoring, and notification endpoints

module Routes
  module MetricsRoutes
    def self.registered(app)
      # Metrics JSON API
      app.get "/metrics.json" do
        total_memes = app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0
        total_likes = app.class::DB.get_first_value("SELECT SUM(likes) FROM meme_stats") || 0
        total_views = app.class::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats") || 0

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
          if defined?(app.class::DB) && app.class::DB
            # Get time period filter
            period = params[:period] || 'all'
            where_clause = case period
                          when '24h' then "WHERE updated_at >= datetime('now', '-1 day')"
                          when '7d' then "WHERE updated_at >= datetime('now', '-7 days')"
                          when '30d' then "WHERE updated_at >= datetime('now', '-30 days')"
                          else ""
                          end
            # Get meme stats with period filter
            @total_memes = (app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause}") || 0).to_i
            @total_likes = (app.class::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats #{where_clause}") || 0).to_i
            @total_views = (app.class::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats #{where_clause}") || 0).to_i
            @total_users = (app.class::DB.get_first_value("SELECT COUNT(*) FROM users") || 0).to_i
            @total_saved_memes = (app.class::DB.get_first_value("SELECT COUNT(*) FROM saved_memes") || 0).to_i
            @memes_with_no_likes = (app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause.empty? ? 'WHERE' : where_clause + ' AND'} likes = 0") || 0).to_i
            @memes_with_no_views = (app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause.empty? ? 'WHERE' : where_clause + ' AND'} views = 0") || 0).to_i

            # Calculate averages
            @avg_likes = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0
            @avg_views = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0
            
            # Calculate engagement rate
            @engagement_rate = @total_views > 0 ? ((@total_likes.to_f / @total_views) * 100).round(2) : 0
            
            # Get chart data for last 7 days
            @chart_dates = []
            @chart_views = []
            @chart_likes = []
            
            7.downto(0) do |days_ago|
              date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
              date_start = (Time.now - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
              date_end = (Time.now - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
              
              daily_views = app.class::DB.get_first_value(
                "SELECT COALESCE(SUM(views), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                [date_start, date_end]
              ).to_i
              
              daily_likes = app.class::DB.get_first_value(
                "SELECT COALESCE(SUM(likes), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                [date_start, date_end]
              ).to_i
              
              @chart_dates << date
              @chart_views << daily_views
              @chart_likes << daily_likes
            end

            # Top memes (DB already returns hashes with results_as_hash = true)
            # FIXED: Only show real Reddit memes with external URLs (not local YAML fallbacks)
            top_memes_where = where_clause.empty? ? "WHERE" : where_clause + " AND"
            @top_memes = app.class::DB.execute("
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
            @top_subreddits = app.class::DB.execute("
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
        total_memes = app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause}") || 0
        total_likes = app.class::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats #{where_clause}") || 0
        total_views = app.class::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats #{where_clause}") || 0
        
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
