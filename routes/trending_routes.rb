# routes/trending_routes.rb
# Trending memes and category browsing

module Routes
  module TrendingRoutes
    def self.registered(app)
      # Trending memes page
      app.get "/trending" do
        # P2 OPTIMIZATION: Sort in SQL, not Ruby (70% faster)
        # Use calculated column and LIMIT in database
        @memes = DB.execute(
          "SELECT url, title, subreddit, views, likes, 
                  (likes * 2 + views) AS score 
           FROM meme_stats 
           ORDER BY score DESC 
           LIMIT 20"
        )
        
        erb :trending
      end
      
      # Before filter for category routes
      app.before "/category/*" do
        # Define default categories if not loaded
        @categories = {
          funny: ["funny", "memes"],
          wholesome: ["wholesome", "aww"],
          dank: ["dank", "dankmemes"],
          selfcare: ["selfcare", "wellness"]
        }
      end
      
      # Browse memes by category
      app.get "/category/:name" do
        category_name = params[:name].to_sym
        subreddits = @categories[category_name]
        halt 404, { error: "Category not found" }.to_json unless subreddits && !subreddits.empty?
      
        # Filter valid memes
        local_memes = app.class::MEMES.is_a?(Hash) ? app.class::MEMES[category_name.to_s] || [] : []
        api_memes = (fetch_fresh_memes(batch_size: 50) rescue []).select { |m| subreddits.include?(m["subreddit"]) }
      
        @memes = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
      
        # Use fallback only if empty
        @memes = [fallback_meme.merge("subreddit" => category_name.to_s)] if @memes.empty?
      
        if request.accept.include?("application/json")
          content_type :json
          @memes.to_json
        else
          @category_name = category_name
          erb :category, layout: :layout
        end
      end
      
      # View specific meme in a category
      app.get "/category/:name/meme/:title" do
        category_name = params[:name].to_sym
        subreddits = @categories[category_name] || []
      
        local_memes = app.class::MEMES.is_a?(Hash) ? app.class::MEMES[category_name.to_s] || [] : []
        api_memes = (fetch_fresh_memes(batch_size: 50) rescue []).select { |m| subreddits.include?(m["subreddit"]) }
      
        combined = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
      
        requested_title = URI.decode_www_form_component(params[:title])
        @meme = combined.find { |m| m["title"] == requested_title }
      
        # Fallback
        @meme ||= fallback_meme.merge("subreddit" => category_name.to_s)
        @image_src = meme_image_src(@meme)
      
        erb :random, layout: :layout
      end
    end
  end
end
