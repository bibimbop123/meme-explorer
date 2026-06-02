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

      # Refresh meme cache manually
      app.post "/admin/refresh-cache" do
        begin
          # Load local memes as fallback
          local_memes = begin
            yaml_data = YAML.load_file("data/memes.yml")
            if yaml_data.is_a?(Hash)
              yaml_data.values.flatten.compact
            else
              yaml_data || []
            end
          rescue => e
            []
          end

          # Use RedditFetcherService (OPTIMIZED for maximum memes!)
          api_memes = []
          client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
          client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
          all_subreddits = YAML.load_file("data/subreddits.yml")["popular"]
          
          if !client_id.empty? && !client_secret.empty?
            begin
              require 'oauth2'
              client = OAuth2::Client.new(
                client_id,
                client_secret,
                site: "https://www.reddit.com",
                authorize_url: "/api/v1/authorize",
                token_url: "/api/v1/access_token"
              )
              token = client.client_credentials.get_token(scope: "read")
              
              # Use RedditFetcherService with OAuth (12 subreddits × 50 posts = 600 memes!)
              fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: token.token)
              api_memes = fetcher.fetch_memes(all_subreddits, limit: 50)
            rescue => e
              # Fall back to unauthenticated if OAuth fails (25 subreddits × 50 = 1,250 memes!)
              fetcher = RedditFetcherService.new(auth_strategy: :static)
              api_memes = fetcher.fetch_memes(all_subreddits, limit: 50) rescue []
            end
          end

          # Update cache
          all_memes = (api_memes + local_memes).uniq { |m| m["url"] || m["file"] }
          MemeExplorer::App::MEME_CACHE.set(:memes, all_memes.shuffle)
          MemeExplorer::App::MEME_CACHE.set(:last_refresh, Time.now)

          # Count memes by type
          api_count = all_memes.count { |m| m["url"] && !m["url"].start_with?("/") }
          local_count = all_memes.count { |m| m["file"] || (m["url"] && m["url"].start_with?("/")) }

          content_type :json
          {
            success: true,
            message: "Cache refreshed successfully",
            total: all_memes.size,
            api_count: api_count,
            local_count: local_count,
            timestamp: Time.now.iso8601
          }.to_json
        rescue => e
          status 500
          content_type :json
          { success: false, error: e.message }.to_json
        end
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
