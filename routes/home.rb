# routes/home.rb
# Home page route - serves the main landing page

module Routes
  module Home
    def self.registered(app)
      app.get "/" do
        begin
          # FAST: Serve from pre-warmed cache (instant)
          @meme = app.class::MEME_CACHE[:memes].sample rescue nil
          @meme ||= fallback_meme
        rescue => e
          puts "Error in root route: #{e.class}: #{e.message}"
          @meme = fallback_meme
        end
        
        @image_src = meme_image_src(@meme)
        @likes = 0  # Will be loaded by JS
        
        # ASYNC: Track analytics in background (non-blocking)
        Thread.new do
          begin
            user_id = session[:user_id] rescue nil
            meme_identifier = @meme["url"] || @meme["file"]
            return unless meme_identifier
            
            # Track view
            app.class::DB.execute(
              "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
              [meme_identifier, @meme["title"] || "Unknown", @meme["subreddit"] || "local"]
            ) rescue nil
            
            # Track exposure for spaced repetition
            if user_id
              app.class::DB.execute(
                "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
                [user_id, meme_identifier]
              ) rescue nil
            end
          rescue => e
            puts "⚠️ Background analytics error: #{e.message}"
          end
        end
        
        erb :random
      end
    end
  end
end
