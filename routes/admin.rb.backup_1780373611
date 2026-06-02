# Admin Routes
module MemeExplorer
  module Routes
    class Admin
      def self.register(app)
        app.get "/admin" do
          halt 403, "Forbidden" unless UserService.is_admin?(session[:user_id])

          @total_memes = DB.get_first_value("SELECT COUNT(*) FROM meme_stats").to_i
          @total_likes = DB.get_first_value("SELECT SUM(likes) FROM meme_stats").to_i
          @total_users = DB.get_first_value("SELECT COUNT(*) FROM users").to_i
          @total_saved_memes = DB.get_first_value("SELECT COUNT(*) FROM saved_memes").to_i
          @top_memes = DB.execute("SELECT title, url, likes, subreddit FROM meme_stats ORDER BY likes DESC LIMIT 10")

          erb :admin
        end

        app.delete "/admin/meme/:url" do
          halt 403, "Forbidden" unless UserService.is_admin?(session[:user_id])

          url = params[:url]
          halt 400, "URL required" unless url

          begin
            DB.execute("DELETE FROM meme_stats WHERE url = ?", [url])
            DB.execute("DELETE FROM saved_memes WHERE meme_url = ?", [url])

            ErrorHandler::Logger.log(
              StandardError.new("Admin deleted meme"),
              { admin_id: session[:user_id], meme_url: url },
              :info
            )

            content_type :json
            { deleted: true, message: "Meme deleted" }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { admin_id: session[:user_id], url: url }, :error)
            halt 500, { error: "Failed to delete meme" }.to_json
          end
        end

        app.get "/errors" do
          halt 403, "Forbidden" unless UserService.is_admin?(session[:user_id])

          content_type :json
          {
            recent_errors: ErrorHandler::Logger.recent(50),
            error_rate_5m: ErrorHandler::Logger.error_rate(300),
            critical_errors_5m: ErrorHandler::Logger.critical_errors(300),
            error_patterns: ErrorHandler::ErrorPatterns.top_errors(10)
          }.to_json
        end

        app.get "/health" do
          content_type :json
          {
            status: "ok",
            timestamp: Time.now.iso8601,
            uptime_seconds: (Time.now - $start_time).to_i,
            requests: app.class::METRICS[:total_requests],
            avg_response_time_ms: app.class::METRICS[:avg_request_time_ms].round(2),
            error_rate_5m: ErrorHandler::Logger.error_rate(300)
          }.to_json
        end

        app.get "/metrics.json" do
          total_memes = DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0
          total_likes = DB.get_first_value("SELECT SUM(likes) FROM meme_stats") || 0
          total_views = DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats") || 0

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

        app.get "/metrics" do
          @total_memes         = (DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0).to_i
          @total_likes         = (DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats") || 0).to_i
          @total_views         = (DB.get_first_value("SELECT SUM(views) FROM meme_stats") || 0).to_i
          @total_users         = (DB.get_first_value("SELECT COUNT(*) FROM users") || 0).to_i
          @total_saved_memes   = (DB.get_first_value("SELECT COUNT(*) FROM saved_memes") || 0).to_i
          @memes_with_no_likes = (DB.get_first_value("SELECT COUNT(*) FROM meme_stats WHERE likes = 0") || 0).to_i
          @memes_with_no_views = (DB.get_first_value("SELECT COUNT(*) FROM meme_stats WHERE views = 0") || 0).to_i

          @avg_likes = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0
          @avg_views = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0

          @top_memes = DB.execute("
            SELECT title, subreddit, url, likes, views
            FROM meme_stats
            ORDER BY (likes * 2 + views) DESC
            LIMIT 10
          ")

          @top_subreddits = DB.execute("
            SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
            FROM meme_stats
            GROUP BY subreddit
            ORDER BY total_likes DESC
            LIMIT 10
          ")

          erb :metrics
        end
      end
    end
  end
end
