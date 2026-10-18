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
          halt 400, { error: 'Expected a JSON object' }.to_json unless data.is_a?(Hash)
          url = data['url'] || data['meme_url'] || params[:url]
          
          unless url
            AppLogger.warn("⚠️  [Like] No URL provided in request")
            halt 400, { error: "No URL provided" }.to_json
          end
          unless url.is_a?(String) && !url.strip.empty? && url.bytesize <= 4096
            halt 400, { error: 'Invalid URL' }.to_json
          end
          if data.key?('liked') && ![true, false].include?(data['liked'])
            halt 400, { error: 'liked must be a boolean' }.to_json
          end
          
          AppLogger.debug("✅ [Like] Request for URL: #{url}")

          # For anonymous users: use session (temporary)
          unless current_user_id
            session[:liked_memes] ||= []
            previous = session[:liked_memes].include?(url)
            liked_now = data.key?('liked') ? data['liked'] : !previous
            if liked_now == previous
              likes = ::DB.get_first_value('SELECT likes FROM meme_stats WHERE url = ?', [url]).to_i
              EngagementService.invalidate_like_cache(url)
              return { success: true, liked: liked_now, likes: likes, persistent: false }.to_json
            end
            liked_now ? session[:liked_memes] << url : session[:liked_memes].delete(url)
            
            likes = ::MemeService.toggle_like(url, liked_now, session, ::DB)
            EngagementService.invalidate_like_cache(url)
            return { success: true, liked: liked_now, likes: likes, persistent: false }.to_json
          end

          # For logged-in users: use database with FULL INTEGRATION
          user_id = current_user_id
          
          result = ::EngagementService.set_like(
            user_id: user_id,
            meme_url: url,
            desired: data.key?('liked') ? data['liked'] : nil,
            session: session,
            db: ::DB
          )
          halt 503, { success: false, error: result[:error] }.to_json unless result[:success]
          
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

        # ROADMAP.md Phase 1: real, new "skip" signal - a user navigating
        # past a meme without liking/saving it is real preference data
        # (see EngagementService.track_skip's own comment for the
        # calibration rationale), and no prior code anywhere even
        # attempted to capture it. Deliberately fire-and-forget from the
        # client (public/js/modules/meme-navigation.js) - a failed skip
        # tracking call must never block or delay loading the next meme.
        app.post "/api/skip-meme" do
          content_type :json

          begin
            request.body.rewind
            data = JSON.parse(request.body.read)
          rescue JSON::ParserError
            data = {}
          end

          subreddit = data['subreddit'] || params[:subreddit]
          dwell_ms = data['dwell_ms'] || params[:dwell_ms]

          # ROADMAP.md Phase 1's "dwell time" signal: captured and logged
          # for observability (queryable via log aggregation/AppLogger's
          # backend) rather than added as a new meme_activity_log column
          # in this pass - the real schema has no dwell_ms column, and
          # adding one is a live migration this session has no way to
          # verify actually ran in production, unlike every other change
          # here (all tested against the real, already-existing schema).
          # `EngagementService.track_skip` doesn't use dwell_ms for
          # preference weighting yet either - see
          # public/js/modules/meme-navigation.js#trackSkip's own comment
          # for why that's a deliberate "capture first, calibrate once
          # there's real data" choice, not an oversight.
          if dwell_ms
            AppLogger.info("[SKIP] dwell_ms=#{dwell_ms} subreddit=#{subreddit} user_id=#{current_user_id || 'anonymous'}")
          end

          result = EngagementService.track_skip(
            user_id: current_user_id,
            subreddit: subreddit,
            db: ::DB
          )

          result.to_json
        end

        # NOTE (found while adding the route above): this /random.json is
        # a dead duplicate - routes/random_meme.rb registers a real,
        # different /random.json (richer response shape: includes
        # media_type, file, is_gallery/gallery_images for galleries) and
        # Routes::RandomMeme is registered before Routes::Memes in
        # app.rb, so Sinatra's first-registered-route-wins means this
        # definition below has never actually been reachable. Confirmed
        # via a real request: the live response always matches
        # random_meme.rb's shape, never this one's. Left in place rather
        # than deleted in this pass - it's out of scope for the skip-
        # signal feature being added here - but flagged so the next
        # session doesn't spend time debugging "changes to this route
        # don't seem to do anything."
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
          json_search = request.preferred_type('text/html', 'application/json') == 'application/json'
          if query.nil? && !json_search
            @query = nil
            @results = []
            next erb :search
          end

          if json_search
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
            if search_result[:success] == false
              halt 400, { success: false, error: search_result[:error], query: query, results: [], total: 0 }.to_json
            end
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
            begin
              @page = Validators.validate_pagination(params[:page] || 1, 24)[:page]
            rescue Validators::ValidationError => e
              @query, @results, @search_error = query, [], e.message
              status 400
              next erb :search
            end
            search_result = ::SearchService.search(query, MemeExplorer::App::MEME_CACHE[:memes], MemeExplorer::App::POPULAR_SUBREDDITS)
            @results = search_result[:results] || []
            @result_total = @results.size
            @page_count = [(@result_total / 24.0).ceil, 1].max
            @page = [@page, @page_count].min
            @results = @results.slice((@page - 1) * 24, 24) || []
            @results = @results.each_with_index.map do |meme, index|
              begin
                id = MemeIdentityService.register(meme)
                context = URI.encode_www_form(search_q: query, search_page: @page, search_result: index)
                id ? meme.merge('detail_path' => "/meme/#{id}?#{context}") : meme
              rescue => e
                AppLogger.warn('Search detail registration unavailable', error: e.class.name)
                meme
              end
            end
            @query = query
            @search_error = search_result[:error] if search_result[:success] == false
            status 400 if @search_error
            erb :search
          end
        end

        app.get "/api/search.json" do
          query = params[:q]
          # Same Hash-vs-Array bug fix as GET /search above.
          search_result = ::SearchService.search(query, MemeExplorer::App::MEME_CACHE[:memes], MemeExplorer::App::POPULAR_SUBREDDITS)
          if search_result[:success] == false
            content_type :json
            halt 400, { success: false, error: search_result[:error], query: query, results: [], total: 0 }.to_json
          end
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
