# Meme Routes
module Routes
  module Memes
    def self.registered(app)
        app.get "/" do
          @meme = app.helpers.navigate_meme_unified(direction: "next")
          @image_src = app.helpers.meme_image_src(@meme)
          erb :random
        end

        app.get "/random" do
          # Check if this is from trending page (cleaner approach)
          trending_url = params[:trending]
          
          if trending_url && !trending_url.empty?
            puts "🔍 [TRENDING CLICK] Looking for URL: #{trending_url}"
            
            # Get memes from cache
            memes = ApiCacheService.fetch_and_cache_memes(MemeExplorer::App::POPULAR_SUBREDDITS)
            memes = MemeExplorer::App::MEME_CACHE[:memes] || [] if memes.empty?
            memes = MemeExplorer::App::MEMES.values.flatten if memes.empty?
            
            # Find exact URL match (most reliable for trending)
            @meme = memes.find { |m| 
              meme_url = m['url'] || m['file']
              meme_url == trending_url || 
              meme_url&.include?(trending_url) || 
              trending_url&.include?(meme_url.to_s)
            }
            
            if @meme
              puts "✅ [TRENDING] Found meme:"
              puts "   Title: #{@meme['title']}"
              puts "   URL: #{@meme['url']}"
            else
              puts "⚠️ [TRENDING] Meme not found in cache, creating minimal object"
              @meme = {
                'url' => trending_url,
                'title' => 'Trending Meme',
                'subreddit' => 'trending'
              }
            end
          end
          
          # If no specific meme requested or not found, pick a random one
          if @meme.nil?
            # Try to get fresh memes from API cache first
            memes = ApiCacheService.fetch_and_cache_memes(MemeExplorer::App::POPULAR_SUBREDDITS)
            
            # Fallback to MEME_CACHE if API returns empty
            memes = MemeExplorer::App::MEME_CACHE[:memes] || [] if memes.empty?
            
            # Final fallback to local memes
            memes = MemeExplorer::App::MEMES.values.flatten if memes.empty?
            
            halt 404, "No memes available" if memes.empty?

            # Use weighted random selector with session tracking
            # FIX: Use consistent session ID (not object_id which changes every request!)
            session_id = session[:visitor_id] || session[:user_id] || request.session_options[:id]
            session[:visitor_id] ||= session_id  # Persist for consistency
            
            # NOTE: Content filtering removed - users should have choice, not hard-coded exclusions
            user_prefs = {}
            @meme = RandomSelectorService.select_random_meme(memes, session_id: session_id, preferences: user_prefs)
            
            halt 404, "No suitable memes available" unless @meme
          end
          
          @image_src = app.helpers.meme_image_src(@meme)
          @likes = ::MemeService.get_likes(@image_src)
          @reddit_path = extract_reddit_path(@meme, @image_src)

          # Debug logging
          if params[:trending]
            puts "✅ [TRENDING] Final display:"
            puts "   Title: #{@meme['title']}"
            puts "   Image src: #{@image_src}"
          end

          # ✅ ACCURATE VIEW TRACKING: Use ViewTrackerService
          # Tracks with proper deduplication and atomic database operations
          visitor_id = session[:visitor_id] || session[:user_id] || request.session_options[:id]
          client_ip = request.ip
          user_id = session[:user_id]
          
          # Track view with comprehensive deduplication
          view_result = ViewTrackerService.track_view(
            @image_src,
            visitor_id,
            ip_address: client_ip,
            user_id: user_id,
            meme_metadata: {
              title: @meme['title'],
              subreddit: @meme['subreddit']
            }
          )
          
          # Also track as viewing for real-time stats
          ActivityTrackerService.mark_viewing(visitor_id, @image_src, ip_address: client_ip) if visitor_id

          erb :random
        end

        app.post "/like" do
          content_type :json
          url = params[:url]
          halt 400, { error: "No URL provided" }.to_json unless url

          # For anonymous users: use session (temporary)
          unless session[:user_id]
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
          user_id = session[:user_id]
          
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
            puts "✅ [XP] Awarded #{result[:xp_awarded]} XP for like"
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
          session_id = session[:visitor_id] || session[:user_id] || request.session_options[:id]
          session[:visitor_id] ||= session_id  # Persist for consistency
          
          # NOTE: Content filtering removed - users should have choice, not hard-coded exclusions
          user_prefs = {}
          meme = RandomSelectorService.select_random_meme(memes, session_id: session_id, preferences: user_prefs)
          
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
        session[:meme_history] << meme_identifier
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
