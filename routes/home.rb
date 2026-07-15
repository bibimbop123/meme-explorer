# routes/home.rb
# Home page route - serves the main landing page

module Routes
  module Home
    def self.registered(app)
      app.get "/" do
        # Prevent caching of homepage (ensures nav bar updates after login/logout)
        headers(
          'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
          'Pragma' => 'no-cache'
        )
        
        begin
          # Try pre-warmed cache first (instant when Sidekiq is running)
          cached = MemeExplorer::App::MEME_CACHE[:memes]
          if cached.is_a?(Array) && cached.any?
            @meme = cached.sample
          else
            # Cache empty — fetch from Reddit on-demand via random_memes_pool
            # (triggers OAuth fetch in InlineRedditFetcher when no workers running)
            pool = random_memes_pool
            @meme = pool.sample
          end
          @meme ||= fallback_meme
        rescue => e
          AppLogger.error("Error in root route: #{e.class}: #{e.message}")
          @meme = fallback_meme
        end
        
        @image_src = meme_image_src(@meme)
        @likes = 0  # Will be loaded by JS
        
        # FIXED: Track analytics synchronously with proper error handling + activity log
        begin
          user_id = current_user_id
          meme_identifier = @meme["url"] || @meme["file"]
          
          if meme_identifier
            # Track view in main thread with proper logging
            MemeExplorer::App::DB.execute(
              "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = meme_stats.views + 1, updated_at = CURRENT_TIMESTAMP",
              [meme_identifier, @meme["title"] || "Unknown", @meme["subreddit"] || "local"]
            )
            
            # Log view event to activity log for accurate time-based metrics
            MemeExplorer::App::DB.execute(
              "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id) VALUES (?, 'view', ?, ?)",
              [meme_identifier, user_id, session.id]
            ) rescue nil # Fail gracefully if activity log doesn't exist yet
            
            # Track exposure for spaced repetition
            if user_id
              MemeExplorer::App::DB.execute(
                "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
                [user_id, meme_identifier]
              )
            end
          end
        rescue => e
          # Log error properly instead of silent failure
          AppLogger.error("❌ Analytics tracking error: #{e.class} - #{e.message}")
          ErrorHandler::Logger.log(e, { meme_url: meme_identifier }, :warning)
        end
        
        erb :random
      end
    end
  end
end
