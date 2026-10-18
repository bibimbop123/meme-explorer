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
          pool = filter_feed_communities(random_memes_pool)
          session_id = feed_session_id
          @meme = MemeExplorer::SimpleMemeSelector.select(pool, session_id, user_id: current_user_id)
          @meme ||= fallback_meme
        rescue => e
          AppLogger.error("Error in root route: #{e.class}: #{e.message}")
          @meme = fallback_meme
        end

        @meme = filter_feed_communities([@meme].compact).first
        
        @image_src = meme_image_src(@meme)
        engagement = viewer_engagement_state(@meme['url'] || @meme['file'])
        @likes, @liked, @saved = engagement.values_at(:likes, :liked, :saved)
        
        @impression_id = issue_impression(
          url: @meme['url'] || @meme['file'], title: @meme['title'],
          subreddit: @meme['subreddit']
        )[:impression_id]

        erb :random
      end
    end
  end
end
