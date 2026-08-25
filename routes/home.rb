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
          # BUG FIX (Aug 25, 2026, round 9): this used to trust
          # MemeExplorer::App::MEME_CACHE[:memes] first and only call
          # random_memes_pool (which correctly prioritizes
          # MemePoolManager's Redis-backed, tier-distributed pool) when
          # that legacy cache was empty. Once MEME_CACHE[:memes] got seeded
          # with just the 10-item local fallback list (e.g. during an
          # earlier rate-limited/cold-start window), this route kept
          # serving only those 10 local memes on every subsequent request
          # - even after MemePoolManager's real Reddit-sourced pool became
          # available. random_memes_pool already checks MemePoolManager
          # first and only falls back to the legacy cache/local memes when
          # nothing better is available, so call it unconditionally
          # instead of trusting a possibly-stale MEME_CACHE snapshot.
          pool = random_memes_pool
          @meme = pool.sample
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
                "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = user_meme_exposure.shown_count + 1, last_shown = CURRENT_TIMESTAMP",
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
