# Meme Routes
# NOTE: GET "/" lives in routes/home.rb (registered via Routes::Home)
# NOTE: GET "/random" lives in routes/random_meme.rb (registered via Routes::RandomMeme)
module Routes
  module Memes
    # Domains we'll actually fetch server-side for /download. Deliberately
    # narrow and separate from the (loosely overlapping) allowlists in
    # lib/helpers/meme_helpers.rb and lib/services/meme_service.rb, which
    # answer a different question ("is this URL plausibly meme media?")
    # than this one needs to ("is it safe for our server to make an
    # outbound HTTP request to this exact host?"). Never fetch an
    # arbitrary user-supplied URL - that's an open proxy / SSRF vector.
    DOWNLOAD_ALLOWED_HOSTS = %w[
      i.redd.it
      v.redd.it
      preview.redd.it
      external-preview.redd.it
      i.imgur.com
      imgur.com
    ].freeze

    def self.registered(app)
        # A plain `<a download>` doesn't reliably force-download
        # cross-origin media (i.redd.it etc. don't send permissive CORS/
        # Content-Disposition headers) - most browsers just navigate to
        # or open the image instead of saving it. The standard, correct
        # fix is a small server-side proxy that fetches the real file and
        # re-serves it with Content-Disposition: attachment, which every
        # browser honors regardless of the origin's own headers.
        app.get "/download" do
          url = params[:url].to_s

          halt 400, "Missing url parameter" if url.empty?

          begin
            uri = URI.parse(url)
          rescue URI::InvalidURIError
            halt 400, "Invalid url"
          end

          unless uri.is_a?(URI::HTTP) && DOWNLOAD_ALLOWED_HOSTS.include?(uri.host)
            AppLogger.warn("⚠️  [Download] Rejected disallowed host: #{uri.host.inspect}")
            halt 403, "That host isn't supported for download"
          end

          begin
            response = HTTParty.get(uri.to_s, timeout: 10)
          rescue => e
            AppLogger.error("❌ [Download] Fetch failed: #{e.class}: #{e.message}")
            halt 502, "Could not fetch the file"
          end

          unless response.code == 200
            halt 502, "Upstream returned #{response.code}"
          end

          extension = File.extname(uri.path)
          extension = ".jpg" if extension.to_s.strip.empty?
          filename = "meme-explorer-#{Time.now.to_i}#{extension}"

          content_type response.headers["content-type"] || "application/octet-stream"
          headers "Content-Disposition" => "attachment; filename=\"#{filename}\""
          response.body
        end

        app.post "/like" do
          content_type :json
          
          # ✅ FIX: Parse JSON body properly (Sinatra doesn't auto-parse!)
          begin
            request.body.rewind
            data = JSON.parse(request.body.read)
          rescue JSON::ParserError => e
            AppLogger.error("❌ [Like] Invalid JSON: #{e.message}")
            halt 400, { error: "Invalid JSON" }.to_json
          end
          
          # Accept both 'url' and 'meme_url' for backwards compatibility
          url = data['url'] || data['meme_url'] || params[:url]
          
          unless url
            AppLogger.warn("⚠️  [Like] No URL provided in request")
            halt 400, { error: "No URL provided" }.to_json
          end
          
          AppLogger.debug("✅ [Like] Request for URL: #{url}")

          # For anonymous users: use session (temporary)
          unless current_user_id
            session[:liked_memes] ||= []
            liked_now = if session[:liked_memes].include?(url)
              session[:liked_memes].delete(url)
              false
            else
              session[:liked_memes] << url
              true
            end
            
            likes = ::MemeService.toggle_like(url, liked_now, session, ::DB)
            return { success: true, liked: liked_now, likes: likes, persistent: false }.to_json
          end

          # For logged-in users: use database with FULL INTEGRATION
          user_id = current_user_id
          
          # Check if already liked in user_liked_memes table
          existing = ::DB.execute(
            "SELECT id FROM user_liked_memes WHERE user_id = ? AND meme_url = ?",
            [user_id, url]
          ).first
          
          if existing
            # Unlike - remove from database
            ::DB.execute("DELETE FROM user_liked_memes WHERE id = ?", [existing['id']])
            liked_now = false
          else
            # Like - add to database
            ::DB.execute(
              "INSERT INTO user_liked_memes (user_id, meme_url, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
              [user_id, url]
            )
            liked_now = true
          end
          
          # Use EngagementService for comprehensive tracking with gamification, leaderboard, and metrics
          result = ::EngagementService.track_like(
            user_id: user_id,
            meme_url: url,
            liked_now: liked_now,
            session: session,
            db: ::DB
          )
          
          response = {
            success: result[:success],
            liked: result[:liked],
            likes: result[:likes],
            persistent: true
          }
          
          # Include XP and level-up info if available
          if result[:xp_awarded] && result[:xp_awarded] > 0
            response[:xp_awarded] = result[:xp_awarded]
            response[:level_up] = result[:level_up]
            response[:new_level] = result[:new_level] if result[:level_up]
            AppLogger.info("✅ [XP] Awarded #{result[:xp_awarded]} XP for like")
          end

          content_type :json
          response.to_json
        end

        app.get "/random.json" do
          memes = ApiCacheService.fetch_and_cache_memes(MemeExplorer::App::POPULAR_SUBREDDITS)
          memes = MemeExplorer::App::MEME_CACHE[:memes] || [] if memes.empty?
          memes = MemeExplorer::App::MEMES.values.flatten if memes.empty?
          halt 404, { error: "No memes available" }.to_json if memes.empty?

          # Use weighted random selector with consistent session tracking
          # FIX: Use consistent session ID (not object_id which changes every request!)
          session_id = session[:visitor_id] || current_user_id || request.session_options[:id]
          session[:visitor_id] ||= session_id  # Persist for consistency
          
          # NOTE: Content filtering removed - users should have choice, not hard-coded exclusions
          user_prefs = {}
          meme = MemeExplorer::MemeSelectionService.select_random_meme(memes, session_id: session_id, preferences: user_prefs)
          
          halt 404, { error: "No suitable memes available" }.to_json unless meme
          
          image_src = app.helpers.meme_image_src(meme)
          reddit_path = extract_reddit_path(meme, image_src)
          likes = MemeService.get_likes(image_src)

          content_type :json
          {
            url: image_src,
            title: meme['title'] || 'Unknown',
            subreddit: meme['subreddit'] || 'reddit',
            reddit_path: reddit_path,
            likes: likes
          }.to_json
        end

        app.post "/report-broken-image" do
          url = params[:url]
          halt 400, { error: "No URL provided" }.to_json unless url

          begin
            # BUG FIX: called `MemeService.report_broken_image(url)`, but
            # that method has never existed on MemeService - the real
            # implementation is a top-level `report_broken_image(url)`
            # helper (lib/helpers/meme_navigation_helpers.rb, defined
            # outside the MemeNavigationHelpers module, so it's a global
            # method callable directly here) - every request to this
            # route raised NoMethodError/500 instead of ever recording a
            # broken image report.
            report_broken_image(url)
            content_type :json
            { reported: true, message: "Broken image tracked" }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { url: url }, :warning)
            halt 500, { error: "Failed to report" }.to_json
          end
        end

        # BUG FIX: all three search routes below called
        # `MemeService.cached_memes`, a class method that has never
        # existed on MemeService (it only ever has instance state, and no
        # class-level cache accessor at all) - every single request to
        # `/search`, `/api/search.json` raised NoMethodError/500. The real,
        # live meme cache is `MemeExplorer::App::MEME_CACHE[:memes]` (see
        # routes/memes.rb's own use of it a few lines up, and
        # routes/random_meme.rb, routes/health.rb, etc.) - swapped in.
        app.get "/search" do
          query = params[:q]

          if request.accept?("application/json")
            # BUG FIX: SearchService.search (lib/services/search_service.rb)
            # always returns a Hash ({success:, results:, query:, total:}),
            # never a bare Array - but this called `.map`/`.size` directly
            # on that return value, which would raise NoMethodError on any
            # Hash (Hash doesn't define `.map` the way an Array does; even
            # where it technically responds, the result was never what
            # this route intended). Pull the actual results array out of
            # the Hash first.
            #
            # ALSO: `request.accept.include?("application/json")` never
            # actually matches - `request.accept` (Sinatra::Request)
            # returns an array of AcceptEntry objects, not strings, so
            # `.include?("application/json")` compares an AcceptEntry to a
            # String and is always false, even with a real
            # `Accept: application/json` header. The correct API is
            # `request.accept?(...)`. Same bug fixed identically in
            # routes/search_routes.rb, routes/trending_routes.rb, and
            # the /category/:name route below.
            search_result = SearchService.search(query, MemeExplorer::App::MEME_CACHE[:memes], MemeExplorer::App::POPULAR_SUBREDDITS)
            results = search_result[:results] || []
            content_type :json
            {
              query: query,
              # BUG FIX: called a `format_search_result` helper that
              # doesn't exist anywhere in the codebase - inlined the
              # formatting instead (same shape the now-dead duplicate
              # /search in routes/search_routes.rb already used).
              results: results.map { |m| {
                title: m["title"],
                url: m["url"] || m["file"],
                file: m["file"],
                subreddit: m["subreddit"],
                likes: m["likes"].to_i,
                views: m["views"].to_i,
                source: m["file"] ? "local" : "reddit"
              } },
              total: results.size
            }.to_json
          else
            search_result = ::SearchService.search(query, MemeExplorer::App::MEME_CACHE[:memes], MemeExplorer::App::POPULAR_SUBREDDITS)
            @results = search_result[:results] || []
            @query = query
            erb :search
          end
        end

        app.get "/api/search.json" do
          query = params[:q]
          # Same Hash-vs-Array bug fix as GET /search above.
          search_result = ::SearchService.search(query, MemeExplorer::App::MEME_CACHE[:memes], MemeExplorer::App::POPULAR_SUBREDDITS)
          results = search_result[:results] || []

          content_type :json
          {
            query: query,
            # Same missing-helper bug fix as GET /search above.
            results: results.map { |m| {
              title: m["title"],
              url: m["url"] || m["file"],
              file: m["file"],
              subreddit: m["subreddit"],
              likes: m["likes"].to_i,
              views: m["views"].to_i,
              source: m["file"] ? "local" : "reddit"
            } },
            total: results.size
          }.to_json
        end

        # NOTE: /trending and /api/v1/trending routes moved to routes/trending_routes.rb and routes/trending_api.rb

        app.get "/category/:name" do
          category_name = params[:name].to_sym
          categories = {
            funny: ["funny", "memes"],
            wholesome: ["wholesome", "aww"],
            dank: ["dank", "dankmemes"],
            selfcare: ["selfcare", "wellness"]
          }

          subreddits = categories[category_name]
          halt 404, { error: "Category not found" }.to_json unless subreddits && !subreddits.empty?

          local_memes = MemeExplorer::App::MEMES.is_a?(Hash) ? MemeExplorer::App::MEMES[category_name.to_s] || [] : []
          @memes = local_memes.empty? ? [app.helpers.fallback_meme.merge("subreddit" => category_name.to_s)] : local_memes

          if request.accept?("application/json")
            content_type :json
            @memes.to_json
          else
            @category_name = category_name
            erb :category, layout: :layout
          end
        end
    end

    def self.extract_reddit_path(meme, image_src)
        if meme["reddit_post_urls"]&.is_a?(Array)
          meme["reddit_post_urls"].find { |u| u.include?(image_src) }
        elsif meme["permalink"]
          meme["permalink"].to_s.strip != "" ? meme["permalink"] : nil
        end
      end

      def self.find_new_meme(memes, last_meme_url)
        return memes.sample if memes.size <= 1
        
        # Aggressively try to find a different meme
        attempts = 0
        max_attempts = [memes.size * 3, 50].max

        while attempts < max_attempts
          candidate = memes.sample
          candidate_id = candidate["url"] || candidate["file"]
          return candidate if candidate_id && candidate_id != last_meme_url
          attempts += 1
        end

        # Fallback: return any random meme if we can't find a different one
        memes.sample
      end

      def self.track_meme_view(meme, session)
        meme_identifier = meme["url"] || meme["file"]
        # Removed: using ViewingHistoryService instead
        # Removed: using ViewingHistoryService instead; # Removed: using ViewingHistoryService instead
        # Removed: using ViewingHistoryService instead
        session[:last_subreddit] = meme["subreddit"]&.downcase

        if !meme_identifier.start_with?("/")
          MemeService.track_view(meme_identifier, meme["title"], meme["subreddit"])
        end
      end

      def self.detect_media_type(file_path)
        return "image" unless file_path
        extension = File.extname(file_path).downcase
        case extension
        when ".mp4", ".webm", ".mov", ".avi", ".mkv"
          "video"
        when ".gif"
          "gif"
        else
          "image"
        end
      end

      def self.format_meme_response(meme)
        image_url = meme["url"] || meme["file"]
        media_type = detect_media_type(image_url)
        {
          title: meme["title"],
          subreddit: meme["subreddit"],
          file: meme["file"],
          url: image_url,
          media_type: media_type,
          reddit_path: extract_reddit_path(meme, image_url),
          likes: MemeService.get_likes(image_url)
        }.to_json
      end

    def self.format_search_result(m)
      {
        title: m["title"],
        url: m["url"] || m["file"],
        file: m["file"],
        subreddit: m["subreddit"],
        likes: m["likes"].to_i,
        views: m["views"].to_i,
        source: m["file"] ? "local" : "reddit",
        engagement_score: (m["likes"].to_i * 2 + m["views"].to_i)
      }
    end
  end
end
