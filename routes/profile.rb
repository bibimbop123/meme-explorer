# User Profile Routes
module MemeExplorer
  module Routes
    class Profile
      def self.register(app)
        app.get "/profile" do
          user_id = session[:user_id] rescue nil
          halt 401, "Not logged in" unless user_id

          begin
            @user = UserService.find_by_id(user_id)
            halt 500, "User not found" unless @user

            @saved_memes = UserService.get_saved_memes(user_id) || []
            @liked_memes = UserService.get_liked_memes(user_id) || []
            @saved_count = @saved_memes.size
            @liked_count = @liked_memes.size

            erb :profile
          rescue => e
            ErrorHandler::Logger.log(e, { user_id: user_id }, :error)
            halt 500, "Error loading profile"
          end
        end

        app.post "/api/save-meme" do
          halt 401, { error: "Not logged in" }.to_json unless session[:user_id]

          url = params[:url]
          title = params[:title]
          subreddit = params[:subreddit]

          halt 400, { error: "URL required" }.to_json unless url

          begin
            UserService.save_meme(session[:user_id], url, title, subreddit)
            content_type :json
            { saved: true, message: "Meme saved" }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { user_id: session[:user_id], url: url }, :error)
            halt 500, { error: "Failed to save meme" }.to_json
          end
        end

        app.post "/api/unsave-meme" do
          halt 401, { error: "Not logged in" }.to_json unless session[:user_id]

          url = params[:url]
          halt 400, { error: "URL required" }.to_json unless url

          begin
            UserService.unsave_meme(session[:user_id], url)
            content_type :json
            { unsaved: true, message: "Meme unsaved" }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { user_id: session[:user_id], url: url }, :error)
            halt 500, { error: "Failed to unsave meme" }.to_json
          end
        end

        app.get "/saved/:id" do
          saved_id = params[:id].to_i
          saved_meme = DB.execute("SELECT * FROM saved_memes WHERE id = ?", [saved_id]).first

          halt 404, "Meme not found" unless saved_meme

          @meme = {
            "title" => saved_meme["meme_title"],
            "url" => saved_meme["meme_url"],
            "subreddit" => saved_meme["meme_subreddit"]
          }
          @image_src = saved_meme["meme_url"]
          @likes = MemeService.get_likes(@image_src)
          @saved_meme_id = saved_id

          erb :saved_meme
        end

        app.get "/api/notifications" do
          halt 401, { error: "Not logged in" }.to_json unless session[:user_id]
          user_id = session[:user_id]

          content_type :json
          {
            user_id: user_id,
            saved_count: UserService.get_saved_memes_count(user_id),
            timestamp: Time.now.iso8601,
            message: "Your profile is up to date"
          }.to_json
        end
      end
    end
  end
end
