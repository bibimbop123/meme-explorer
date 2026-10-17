# routes/random_meme.rb
# Random meme routes - HTML and JSON endpoints
# Services required at file load time (not per-request) to avoid require mutex contention
require_relative '../lib/services/viewing_history_service'
require_relative '../lib/services/simple_meme_selector'
require 'digest'
require_relative '../lib/security/reddit_source'
require_relative '../lib/services/meme_identity_service'
require_relative '../lib/security/public_origin'

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

      RedditSource.path(reddit_path)
    end

    def self.build_meme_json(meme, media_type:, likes:)
      image_url = meme["url"] || meme["file"]
      reddit_path = build_reddit_path(meme, image_url)

      response_data = {
        title: meme["title"],
        subreddit: meme["subreddit"],
        file: meme["file"],
        url: image_url,
        reddit_path: reddit_path,
        likes: likes,
        media_type: media_type,
        inventory_exhausted: meme['inventory_exhausted'] == true,
        **MediaDimensions.for(meme)
      }

      if meme["is_gallery"] && meme["gallery_images"]
        response_data[:is_gallery] = true
        response_data[:gallery_images] = meme["gallery_images"]
        response_data[:total_images] = meme["gallery_images"].size
      end

      response_data
    end

    def self.registered(app)
      app.helpers do
        def viewer_engagement_state(url, likes: nil)
          {
            liked: current_user_id ? EngagementService.user_liked?(user_id: current_user_id, meme_url: url) : (session[:liked_memes] || []).include?(url),
            saved: current_user_id ? EngagementService.user_saved?(user_id: current_user_id, meme_url: url) : false,
            likes: (likes.nil? ? get_meme_likes(url) : likes).to_i
          }
        end

        def issue_impression(response_data)
          feed_session_id
          session[:impression_session_key] ||= SecureRandom.hex(32)
          pending = (session[:pending_impressions] || {}).reject { |_, item| item['expires_at'].to_i < Time.now.to_i }
          pending.shift while pending.size >= 20
          id = SecureRandom.hex(32)
          pending[id] = {
            'url' => response_data[:url], 'title' => response_data[:title],
            'subreddit' => response_data[:subreddit], 'user_id' => current_user_id, 'expires_at' => Time.now.to_i + 1800
          }
          session[:pending_impressions] = pending
          # Reuse the server-built response's count instead of fetching it twice.
          result = response_data.merge(viewer_engagement_state(response_data[:url], likes: response_data[:likes])).merge(impression_id: id)
          begin
            snapshot = @meme.is_a?(Hash) ? @meme.merge('url' => response_data[:url]) : response_data.transform_keys(&:to_s)
            content_id = MemeIdentityService.register(snapshot)
            if content_id
              result[:content_id] = content_id
              result[:share_path] = "/meme/#{content_id}"
            end
          rescue => e
            AppLogger.warn('Meme catalog registration unavailable', error: e.class.name)
          end
          @share_path = result[:share_path]
          result
        end
      end

      app.get '/meme/:id' do
        headers 'Cache-Control' => 'no-store'
        begin
          @meme = MemeIdentityService.find(params[:id])
        rescue => e
          AppLogger.error('Meme catalog lookup unavailable', error: e.class.name)
          @meme_unavailable = true
          @retry_path = "/meme/#{params[:id]}" if params[:id].match?(/\A[a-f0-9]{64}\z/)
          headers 'Retry-After' => '60', 'X-Robots-Tag' => 'noindex, nofollow'
          status 503
          next erb :meme_unavailable
        end
        unless @meme
          @meme_unavailable = true
          headers 'X-Robots-Tag' => 'noindex, nofollow'
          status 404
          next erb :meme_unavailable
        end
        @image_src = meme_image_src(@meme)
        @reddit_path = RedditSource.path(@meme['permalink'])
        @permalink_page = true
        @share_path = "/meme/#{params[:id]}"
        if params[:search_q].is_a?(String) && params[:search_q].length <= 200 &&
           params[:search_page].to_s.match?(/\A[1-9][0-9]{0,8}\z/) &&
           params[:search_result].to_s.match?(/\A(?:[0-9]|1[0-9]|2[0-3])\z/)
          @search_return_path = "/search?#{URI.encode_www_form(q: params[:search_q], page: params[:search_page])}#search-result-#{params[:search_result]}"
        end
        origin = PublicOrigin.resolve(configured: ENV['PUBLIC_ORIGIN'], production: settings.environment == :production, fallback: request.base_url)
        @social_url = "#{origin}/meme/#{params[:id]}" if origin
        images = @meme['gallery_images']
        first_image = images.first if images.is_a?(Array)
        candidate = @meme['is_gallery'] ? (first_image['url'] if first_image.is_a?(Hash)) : @image_src
        @social_image = MediaUrl.social_image(candidate, origin: origin) if origin
        engagement = viewer_engagement_state(@meme['url'])
        @likes, @liked, @saved = engagement.values_at(:likes, :liked, :saved)
        @impression_id = issue_impression(url: @meme['url'], title: @meme['title'], subreddit: @meme['subreddit'])[:impression_id]
        erb :random
      end

      app.post '/api/impressions' do
        content_type :json
        begin
          request.body.rewind
          data = JSON.parse(request.body.read)
          halt 400, { error: 'JSON object required' }.to_json unless data.is_a?(Hash)
        rescue JSON::ParserError
          halt 400, { error: 'Invalid JSON' }.to_json
        end
        id = data['impression_id']
        pending = session[:pending_impressions] || {}
        item = id.is_a?(String) ? pending[id] : nil
        unless item && item['expires_at'].to_i >= Time.now.to_i
          reason = if !id.is_a?(String) || !id.match?(/\A[a-f0-9]{64}\z/)
                     'malformed_id'
                   elsif item
                     'expired_pending'
                   else
                     'missing_pending'
                   end
          # Never log supplied IDs, tokens, content or account identity. Missing
          # pending state alone cannot distinguish eviction/session races/logout.
          AppLogger.info('Impression acknowledgment rejected', reason: reason)
          halt 404, { error: 'Unknown or expired impression' }.to_json
        end
        recorded = false
        begin
          DB.transaction do
            inserted = DB.execute(
              'INSERT INTO meme_impressions (id, meme_url, session_key) VALUES (?, ?, ?) ON CONFLICT DO NOTHING RETURNING id',
              [id, item['url'], session[:impression_session_key]]
            )
            unless inserted.empty?
              DB.execute(
                'INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = meme_stats.views + 1, updated_at = CURRENT_TIMESTAMP',
                [item['url'], item['title'] || 'Unknown', item['subreddit'] || 'unknown']
              )
              if item['user_id'] && item['user_id'] == current_user_id
                DB.execute(
                  'INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = user_meme_exposure.shown_count + 1, last_shown = CURRENT_TIMESTAMP',
                  [current_user_id, item['url']]
                )
              end
              DB.execute(
                "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id) VALUES (?, 'view', ?, ?)",
                [item['url'], current_user_id, session[:impression_session_key]]
              )
              recorded = true
            end
          end
        rescue => e
          AppLogger.error('Impression acknowledgment failed', error: e.message)
          halt 503, { error: 'Impression tracking temporarily unavailable' }.to_json
        end
        { success: true, recorded: recorded }.to_json
      end

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
          session_id = feed_session_id

          # The core product loop: given this person, pick their meme.
          # Timed end-to-end AND broken into stages (pool lookup vs.
          # selection algorithm) so /metrics can show not just the one
          # headline number, but WHERE its time actually goes - see
          # lib/services/selection_benchmark.rb.
          @meme = SelectionBenchmark.measure do
            meme_pool = SelectionBenchmark.measure(stage: :pool_lookup) { random_memes_pool }
            # ROADMAP.md Phase 1: same personalization wiring as
            # /random.json below - this is the first-load HTML path, the
            # other real entry point into selection.
            SelectionBenchmark.measure(stage: :selection) { MemeExplorer::SimpleMemeSelector.select(meme_pool, session_id, user_id: current_user_id) }
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
        engagement = viewer_engagement_state(@meme['url'] || @meme['file'])
        @likes, @liked, @saved = engagement.values_at(:likes, :liked, :saved)
      
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
        
        @impression_id = issue_impression(
          url: @meme['url'] || @meme['file'], title: @meme['title'],
          subreddit: @meme['subreddit']
        )[:impression_id]

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

          session_id = feed_session_id

          # Find similar meme (same subreddit)
        similar_pool = meme_pool.select { |m| m['subreddit']&.downcase == subreddit }
        similar_pool = meme_pool if similar_pool.empty? # Fallback to all if no matches
        
        # ROADMAP.md Phase 1: same personalization wiring as /random and
        # /random.json above - /similar.json is a real, live endpoint too.
        @meme = MemeExplorer::SimpleMemeSelector.select(similar_pool, session_id, user_id: current_user_id)
          
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
          issue_impression(response_data).to_json
        rescue => e
          AppLogger.error("❌ [/similar.json] Error: #{e.class}: #{e.message}")
          AppLogger.info("backtrace", lines: e.backtrace.first(5).join("\n"))
          halt 500, { error: "Internal server error", message: e.message }.to_json
        end
      end
      
      # JSON API endpoint for random memes with validation
      app.get "/random.json" do
        AppLogger.debug("🔄 [/random.json] Request received")

        session_id = feed_session_id

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

          # ROADMAP.md Phase 1: thread the logged-in user's id through so
          # SimpleMemeSelector can fold in their real subreddit
          # preferences (from likes/saves - see
          # EngagementService#bump_subreddit_preference) into selection
          # weighting - this is the actual live selection path every
          # subsequent /random.json request hits, unlike the separate,
          # never-called apply_user_preferences path.
          SelectionBenchmark.measure(stage: :selection) { MemeExplorer::SimpleMemeSelector.select(memes, session_id, user_id: current_user_id) }
        end
        AppLogger.info("✅ [/random.json] Got #{memes.size} memes from pool")
        post_selection_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        halt 404, { error: "No memes found" }.to_json if memes.empty?
        
        # Each response is a new selection with session-bound impression state.
        headers 'Cache-Control' => 'no-store, private'

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
        response_prepared = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response_with_impression = issue_impression(response_data)
        impression_finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        json = response_with_impression.to_json
        serialization_finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        # Aggregate timing only: no extra network telemetry calls or identities.
        # Excludes middleware/session persistence and media download/render time.
        headers 'Server-Timing' => [
          "response_prepare;dur=#{((response_prepared - post_selection_started) * 1000).round(2)}",
          "impression_issue;dur=#{((impression_finished - response_prepared) * 1000).round(2)}",
          "serialization;dur=#{((serialization_finished - impression_finished) * 1000).round(2)}"
        ].join(', ')
        json
      end
    end
  end
end
