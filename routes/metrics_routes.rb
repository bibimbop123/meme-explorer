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
            # Get meme stats
            @total_memes = (app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0).to_i
            @total_likes = (app.class::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats") || 0).to_i
            @total_views = (app.class::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats") || 0).to_i
            @total_users = (app.class::DB.get_first_value("SELECT COUNT(*) FROM users") || 0).to_i
            @total_saved_memes = (app.class::DB.get_first_value("SELECT COUNT(*) FROM saved_memes") || 0).to_i
            @memes_with_no_likes = (app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats WHERE likes = 0") || 0).to_i
            @memes_with_no_views = (app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats WHERE views = 0") || 0).to_i

            # Calculate averages
            @avg_likes = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0
            @avg_views = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0
            
            # Calculate engagement rate
            @engagement_rate = @total_views > 0 ? ((@total_likes.to_f / @total_views) * 100).round(2) : 0

            # Top memes (DB already returns hashes with results_as_hash = true)
            # FIXED: Exclude fallback/placeholder memes and require minimum engagement
            @top_memes = app.class::DB.execute("
              SELECT title, subreddit, url, likes, views
              FROM meme_stats
              WHERE url NOT LIKE '%/images/%'
                AND url NOT LIKE '%placeholder%'
                AND url NOT LIKE '%fallback%'
                AND url NOT LIKE '%tattoo-annie%'
                AND url NOT LIKE '%/public/%'
                AND (likes > 0 OR views >= 5)
                AND title IS NOT NULL
                AND title != 'Unknown'
              ORDER BY (likes * 2 + views) DESC
              LIMIT 10
            ")

            # Top subreddits
            # FIXED: Exclude 'local' fallback subreddit
            @top_subreddits = app.class::DB.execute("
              SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
              FROM meme_stats
              WHERE subreddit IS NOT NULL
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
