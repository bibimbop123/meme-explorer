# routes/admin_routes.rb
# Admin panel and moderation routes

module Routes
  module AdminRoutes
    def self.registered(app)
      # Admin dashboard
      app.get "/admin" do
        halt 403, "Forbidden" unless is_admin?

        @total_memes = app.class::DB.get_first_value("SELECT COUNT(*) FROM meme_stats").to_i
        @total_likes = app.class::DB.get_first_value("SELECT SUM(likes) FROM meme_stats").to_i
        @total_users = app.class::DB.get_first_value("SELECT COUNT(*) FROM users").to_i
        @total_saved_memes = app.class::DB.get_first_value("SELECT COUNT(*) FROM saved_memes").to_i
        @top_memes = app.class::DB.execute("SELECT title, url, likes, subreddit FROM meme_stats ORDER BY likes DESC LIMIT 10")

        erb :admin
      end

      # Delete a meme from the system
      app.delete "/admin/meme/:url" do
        halt 403, "Forbidden" unless is_admin?

        url = params[:url]
        halt 400, "URL required" unless url

        app.class::DB.execute("DELETE FROM meme_stats WHERE url = ?", [url])
        app.class::DB.execute("DELETE FROM saved_memes WHERE meme_url = ?", [url])

        content_type :json
        { deleted: true, message: "Meme deleted" }.to_json
      end
    end
  end
end
