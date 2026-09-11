# routes/random_meme.rb
# Random meme routes - HTML and JSON endpoints
# Services required at file load time (not per-request) to avoid require mutex contention
require_relative '../lib/services/viewing_history_service'
require_relative '../lib/services/simple_meme_selector'

module Routes
  module RandomMeme
    # Shared by /random.json and /similar.json — both endpoints select a
    # meme and then need to derive its reddit permalink, record a view,
    # and shape the JSON response identically. This used to be copy-pasted
    # in both route bodies (~40 lines each); extracted here so there's one
    # place to fix when the response shape changes.
    def self.build_reddit_path(meme, image_url)
      reddit_path = nil

      if meme["reddit_post_urls"]&.is_a?(Array)
        reddit_path = meme["reddit_post_urls"].find { |u| u.include?(image_url) }
      end

      if !reddit_path && meme["permalink"].to_s.strip != ""
        reddit_path = meme["permalink"]
      end

      if reddit_path&.start_with?("http")
        reddit_path = URI.parse(reddit_path).path
      end

      reddit_path
    end

    def self.build_meme_json(meme, media_type:, likes:)
      image_url = meme["url"] || meme["file"]
      reddit_path = build_reddit_path(meme, image_url)

      # Track view in meme_stats if it's an API meme (not a local file)
      if !image_url.start_with?("/")
        MemeExplorer::App::DB.execute(
          "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = meme_stats.views + 1, updated_at = CURRENT_TIMESTAMP",
          [image_url, meme["title"] || "Unknown", meme["subreddit"] || "reddit"]
        ) rescue nil
      end

      response_data = {
        title: meme["title"],
        subreddit: meme["subreddit"],
        file: meme["file"],
        url: image_url,
        reddit_path: reddit_path,
        likes: likes,
        media_type: media_type
      }

      if meme["is_gallery"] && meme["gallery_images"]
        response_data[:is_gallery] = true
        response_data[:gallery_images] = meme["gallery_images"]
        response_data[:total_images] = meme["gallery_images"].size
      end

      response_data
    end

    def self.registered(app)
      # Render random meme page
      app.get "/random" do
        begin
          # BUG FIX (Aug 25, 2026, round 9): this used to trust
          # MemeExplorer::App::MEME_CACHE[:memes] first, and only call
          # random_memes_pool (which correctly prioritizes
          # MemePoolManager's Redis-backed, tier-distributed pool) when
          # that legacy cache was empty. In production this meant that
          # once MEME_CACHE[:memes] got seeded with just the 10-item local
          # fallback list (e.g. during an earlier rate-limited/cold-start
          # window), /random kept serving only those 10 local memes on
          # every subsequent request - even after MemePoolManager's real
          # 170-meme Reddit-sourced pool became available and /random.json
          # (which already called random_memes_pool unconditionally) was
          # serving it correctly. Route through random_memes_pool
          # unconditionally, matching /random.json, so this page always
          # gets the best available pool instead of a possibly-stale
          # legacy snapshot.
          #
          # BUG FIX: plain `session.id` blew up with NoMethodError whenever
          # `session` was a bare Hash rather than a real Rack session
          # object (e.g. no cookie set yet, or a test double) - `session`
          # doesn't universally respond to `.id`. Guard with
          # `respond_to?(:id)` so this falls through to the request-IP
          # fallback instead of crashing the whole request.
          session_id = session[:session_id] || (session.respond_to?(:id) ? session.id : nil) || "anonymous_#{request.ip}"

          # The core product loop: given this person, pick their meme.
          # Timed end-to-end AND broken into stages (pool lookup vs.
          # selection algorithm) so /metrics can show not just the one
          # headline number, but WHERE its time actually goes - see
          # lib/services/selection_benchmark.rb.
          @meme = SelectionBenchmark.measure do
            meme_pool = SelectionBenchmark.measure(stage: :pool_lookup) { random_memes_pool }
            SelectionBenchmark.measure(stage: :selection) { MemeExplorer::SimpleMemeSelector.select(meme_pool, session_id) }
          end

          # Fallback if something goes wrong
          @meme ||= fallback_meme
          
          # ✅ NEW: Track in Redis (NOT session) - fixes 4KB cookie limit!
          if @meme
            meme_identifier = @meme["url"] || @meme["file"]
            if meme_identifier
              MemeExplorer::ViewingHistoryService.mark_seen(session_id, meme_identifier)
            end
            
            # Track subreddit for diversity tracking
            if defined?(REDIS) && REDIS && @meme["subreddit"]
              key = "recent_subreddits:#{session_id}"
              recent_subs = (JSON.parse(REDIS.get(key) || '[]') rescue [])
              recent_subs << @meme["subreddit"].downcase
              REDIS.setex(key, 3600, recent_subs.last(20).to_json)
            end
          end
        rescue => e
          AppLogger.error("Error in /random route: #{e.class}: #{e.message}")
          AppLogger.info("backtrace", lines: e.backtrace.first(5).join("\n"))
          @meme = fallback_meme
        end
        
        # View count tracking (session-based, works for both logged-in and anonymous users)
        session[:view_count] ||= 0
        session[:view_count] += 1
        
        @image_src = meme_image_src(@meme)
        @likes = 0  # Will be loaded by JS
      
        # Determine reddit_path for this specific image
        @reddit_path = nil
        begin
          if @meme["reddit_post_urls"]&.is_a?(Array)
            post_url = @meme["reddit_post_urls"].find { |u| u.include?(@image_src) }
            @reddit_path = post_url
          end
        
          # Fallback to permalink from API meme
          if !@reddit_path && @meme["permalink"]
            permalink_str = @meme["permalink"].to_s.strip
            if permalink_str != ""
              @reddit_path = permalink_str
              # Strip domain if full URL
              @reddit_path = URI.parse(@reddit_path).path if @reddit_path.start_with?("http")
            end
          end
        rescue => e
          AppLogger.error("⚠️ Reddit path error: #{e.message}")
        end
        
        # ASYNC: Track analytics via bounded thread pool (non-blocking, memory-safe)
        meme_snapshot = { url: @meme["url"], file: @meme["file"],
                          title: @meme["title"], subreddit: @meme["subreddit"] }
        uid_snapshot = current_user_id
        ANALYTICS_POOL.post do
          begin
            meme_identifier = meme_snapshot[:url] || meme_snapshot[:file]
            next unless meme_identifier

            MemeExplorer::App::DB.execute(
              "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = meme_stats.views + 1, updated_at = CURRENT_TIMESTAMP",
              [meme_identifier, meme_snapshot[:title] || "Unknown", meme_snapshot[:subreddit] || "local"]
            )

            if uid_snapshot
              MemeExplorer::App::DB.execute(
                "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = user_meme_exposure.shown_count + 1, last_shown = CURRENT_TIMESTAMP",
                [uid_snapshot, meme_identifier]
              )
            end
          rescue => e
            AppLogger.warn("Background analytics failed", error: e.message, url: meme_snapshot[:url])
          end
        end

        erb :random
      end
      
      # JSON API endpoint for similar memes (more like this)
      app.get "/similar.json" do
        content_type :json
        AppLogger.debug("✨ [/similar.json] Request received")
        
        begin
          # Require subreddit parameter
          subreddit = params[:subreddit]&.strip&.downcase
          halt 400, { error: "Subreddit parameter required" }.to_json if subreddit.nil? || subreddit.empty?
          
          # Get meme pool
          meme_pool = if MemeExplorer::App::MEME_CACHE[:memes].is_a?(Array) && !MemeExplorer::App::MEME_CACHE[:memes].empty?
            MemeExplorer::App::MEME_CACHE[:memes]
          else
            random_memes_pool
          end
          
          halt 404, { error: "No memes available" }.to_json if meme_pool.empty?

          session_id = session[:session_id] || (session.respond_to?(:id) ? session.id : nil) || "anonymous_#{request.ip}"

          # Find similar meme (same subreddit)
        similar_pool = meme_pool.select { |m| m['subreddit']&.downcase == subreddit }
        similar_pool = meme_pool if similar_pool.empty? # Fallback to all if no matches
        
        @meme = MemeExplorer::SimpleMemeSelector.select(similar_pool, session_id)
          
          halt 404, { error: "No similar memes found for #{subreddit}" }.to_json if @meme.nil?
          # ✅ Track in Redis (NOT session)
          meme_identifier = @meme["url"] || @meme["file"]
          if meme_identifier
            MemeExplorer::ViewingHistoryService.mark_seen(session_id, meme_identifier)
          end
          
          image_url = @meme["url"] || @meme["file"]
          response_data = Routes::RandomMeme.build_meme_json(
            @meme,
            media_type: detect_media_type(image_url),
            likes: get_meme_likes(image_url)
          )

          AppLogger.info("✅ [/similar.json] Returning meme from #{@meme['subreddit']}")
          response_data.to_json
        rescue => e
          AppLogger.error("❌ [/similar.json] Error: #{e.class}: #{e.message}")
          AppLogger.info("backtrace", lines: e.backtrace.first(5).join("\n"))
          halt 500, { error: "Internal server error", message: e.message }.to_json
        end
      end
      
      # JSON API endpoint for random memes with validation
      app.get "/random.json" do
        AppLogger.debug("🔄 [/random.json] Request received")

        session_id = session[:session_id] || (session.respond_to?(:id) ? session.id : nil) || "anonymous_#{request.ip}"

        # The core product loop, timed end-to-end AND per-stage - see
        # lib/services/selection_benchmark.rb. This is the endpoint most
        # real usage actually hits (every subsequent meme after the first
        # page load goes through here), so its latency is the number that
        # matters most - and the stage breakdown here is what tells us
        # whether to spend effort on the pool-lookup fallback chain or the
        # selection algorithm itself.
        memes = nil
        @meme = SelectionBenchmark.measure do
          # Use random_memes_pool for ALL users (both auth and non-auth) to ensure API memes are always available
          memes = SelectionBenchmark.measure(stage: :pool_lookup) { random_memes_pool }
          next nil if memes.empty?

          SelectionBenchmark.measure(stage: :selection) { MemeExplorer::SimpleMemeSelector.select(memes, session_id) }
        end
        AppLogger.info("✅ [/random.json] Got #{memes.size} memes from pool")

        halt 404, { error: "No memes found" }.to_json if memes.empty?
        
        # CDN caching - 1 hour for meme data
        headers "Cache-Control" => "public, max-age=3600"
        headers "ETag" => Digest::MD5.hexdigest(memes.to_json)

        halt 404, { error: "No valid meme found" }.to_json if @meme.nil?
        
        AppLogger.info("✅ [/random.json] Selected meme: #{@meme['title']}")
        
        # ✅ Track in Redis (NOT session)
        meme_identifier = @meme["url"] || @meme["file"]
        if meme_identifier
          MemeExplorer::ViewingHistoryService.mark_seen(session_id, meme_identifier)
        end
        session[:last_subreddit] = @meme["subreddit"]&.downcase
        
        image_url = @meme["url"] || @meme["file"]

        # No more client-side fallback chains - backend validation ensures working images
        response_data = Routes::RandomMeme.build_meme_json(
          @meme,
          media_type: detect_media_type(image_url),
          likes: get_meme_likes(image_url)
        )

        content_type :json
        AppLogger.info("✅ [/random.json] Returning validated meme response#{@meme['is_gallery'] ? ' (GALLERY with ' + @meme['gallery_images'].size.to_s + ' images)' : ''}")
        response_data.to_json
      end
    end
  end
end
