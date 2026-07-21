# Meme Routes
# NOTE: GET "/" lives in routes/home.rb (registered via Routes::Home)
# NOTE: GET "/random" lives in routes/random_meme.rb (registered via Routes::RandomMeme)
module Routes
  module Memes
    def self.registered(app)
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
            MemeService.report_broken_image(url)
            content_type :json
            { reported: true, message: "Broken image tracked" }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { url: url }, :warning)
            halt 500, { error: "Failed to report" }.to_json
          end
        end

        app.get "/search" do
          query = params[:q]

          if request.accept.include?("application/json")
            results = SearchService.search(query, MemeService.cached_memes, MemeExplorer::App::POPULAR_SUBREDDITS)
            content_type :json
            {
              query: query,
              results: results.map { |m| format_search_result(m) },
              total: results.size
            }.to_json
          else
            @results = ::SearchService.search(query, ::MemeService.cached_memes, MemeExplorer::App::POPULAR_SUBREDDITS)
            @query = query
            erb :search
          end
        end

        app.get "/api/search.json" do
          query = params[:q]
          results = ::SearchService.search(query, ::MemeService.cached_memes, MemeExplorer::App::POPULAR_SUBREDDITS)

          content_type :json
          {
            query: query,
            results: results.map { |m| format_search_result(m) },
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

          if request.accept.include?("application/json")
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
        session[:meme_history] ||= []
        session[:meme_history] ||= []; session[:meme_history] << meme_identifier
        session[:meme_history] = session[:meme_history].last(100)
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
