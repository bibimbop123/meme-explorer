# routes/profile_routes.rb
# User profile and saved memes management

module Routes
  module ProfileRoutes
    def self.registered(app)
      # User profile page
      app.get "/profile" do
        # Check session safely
        user_id = session[:user_id] rescue nil
        halt 401, "Not logged in" unless user_id
      
        # Wrap Redis or DB calls in safe error handling
        begin
          @user = get_user(user_id)
          
          # Ensure @user is not nil - provide default structure
          if @user.nil?
            halt 500, "User not found in database"
          end
          
          @saved_memes = get_user_saved_memes(user_id) || []
          
          # Get user's liked memes from user_meme_stats
          @liked_memes = begin
            results = app.class::DB.execute(
              "SELECT meme_url, liked_at FROM user_meme_stats WHERE user_id = ? AND liked = 1 ORDER BY liked_at DESC",
              [user_id]
            ) || []
            results.map { |row| row.transform_keys(&:to_s) }
          rescue => e
            puts "Error fetching liked memes: #{e.message}"
            []
          end
      
        rescue => e
          # Log the error and return proper error response
          puts "Profile Error: #{e.class}: #{e.message}"
          puts e.backtrace.join("\n")
          halt 500, "Error loading profile: #{e.message}"
        end
      
        # Count stats
        @saved_count = @saved_memes.size
        @liked_count = @liked_memes.size
      
        erb :profile
      end

      # Save a meme to user's collection
      app.post "/api/save-meme" do
        halt 401, { error: "Not logged in" }.to_json unless session[:user_id]

        url = params[:url]
        title = params[:title]
        subreddit = params[:subreddit]

        halt 400, { error: "URL required" }.to_json unless url

        save_meme(session[:user_id], url, title, subreddit)

        content_type :json
        { saved: true, message: "Meme saved" }.to_json
      end

      # Remove a meme from user's collection
      app.post "/api/unsave-meme" do
        halt 401, { error: "Not logged in" }.to_json unless session[:user_id]

        url = params[:url]
        halt 400, { error: "URL required" }.to_json unless url

        unsave_meme(session[:user_id], url)

        content_type :json
        { unsaved: true, message: "Meme unsaved" }.to_json
      end

      # View a specific saved meme
      app.get "/saved/:id" do
        # FIX: IDOR vulnerability - require authentication and authorization
        halt 401, "Not logged in" unless session[:user_id]
        
        saved_id = params[:id].to_i
        saved_meme = app.class::DB.execute(
          "SELECT * FROM saved_memes WHERE id = ? AND user_id = ?", 
          [saved_id, session[:user_id]]
        ).first

        halt 404, "Meme not found" unless saved_meme

        @meme = {
          "title" => saved_meme["meme_title"],
          "url" => saved_meme["meme_url"],
          "subreddit" => saved_meme["meme_subreddit"]
        }
        @image_src = saved_meme["meme_url"]
        @likes = get_meme_likes(@image_src)
        @saved_meme_id = saved_id

        erb :saved_meme
      end
    end
  end
end
