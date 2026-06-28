# frozen_string_literal: true
# routes/utility_routes.rb - extracted from app.rb

module Routes
  module UtilityRoutes
    def self.registered(app)
    app.get "/ads.txt" do
      content_type 'text/plain'
      File.read('ads.txt')
    end

    # GET "/" and GET "/random" live in routes/home.rb and routes/random_meme.rb
    # (registered via  and )


    app.get "/random.json" do
      AppLogger.debug("🔄 [/random.json] Request received")

      # Use random_memes_pool for ALL users (both auth and non-auth) to ensure API memes are always available
      # This fixes the OAuth issue where new users only saw local memes
      AppLogger.debug("🔄 [/random.json] Calling random_memes_pool...")
      memes = random_memes_pool
      AppLogger.info("✅ [/random.json] Got #{memes.size} memes from pool")

      halt 404, { error: "No memes found" }.to_json if memes.empty?

      # CDN caching - 1 hour for meme data
      headers "Cache-Control" => "public, max-age=3600"
      headers "ETag" => Digest::MD5.hexdigest(memes.to_json)

      # Track in session history and pick from pool
      session[:meme_history] ||= []
      session[:last_subreddit] ||= nil
      last_meme_url = session[:meme_history].last

      # Find a new meme that's different from last shown
      @meme = nil
      attempts = 0
      max_attempts = [memes.size, 30].min

      while attempts < max_attempts
        candidate = memes.sample
        candidate_id = candidate["url"] || candidate["file"]

        if candidate_id && candidate_id != last_meme_url
          @meme = candidate
          break
        end
        attempts += 1
      end

      halt 404, { error: "No valid meme found" }.to_json if @meme.nil?
      AppLogger.info("✅ [/random.json] Found valid meme: #{@meme['title']}")

      # Track in session history
      meme_identifier = @meme["url"] || @meme["file"]
      session[:meme_history] << meme_identifier
      session[:meme_history] = session[:meme_history].last(10)  # Hard cap: 50 (reduced from 100)
      session[:last_subreddit] = @meme["subreddit"]&.downcase

      image_url = @meme["url"] || @meme["file"]

      reddit_path = nil
      if @meme["reddit_post_urls"]&.is_a?(Array)
        post_url = @meme["reddit_post_urls"].find { |u| u.include?(image_url) }
        reddit_path = post_url
      end

      # Try to get permalink from meme
      if !reddit_path && @meme["permalink"].to_s.strip != ""
        reddit_path = @meme["permalink"]
      end

      # Strip domain if full URL
      if reddit_path&.start_with?("http")
        uri = URI.parse(reddit_path)
        reddit_path = uri.path
      end

      # Track view in meme_stats if it's an API meme (not local file)
      if !image_url.start_with?("/")
        meme_title = @meme["title"] || "Unknown"
        meme_subreddit = @meme["subreddit"] || "reddit"
        DB.execute(
          "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
          [image_url, meme_title, meme_subreddit]
        ) rescue nil
      end

      # Extract preview images for client-side fallback chain
      preview_images = extract_preview_images(@meme)
      media_type = detect_media_type(image_url)

      response_data = {
        title: @meme["title"],
        subreddit: @meme["subreddit"],
        file: @meme["file"],
        url: image_url,
        reddit_path: reddit_path,
        likes: get_meme_likes(image_url),
        preview_images: preview_images,
        media_type: media_type
      }

      content_type :json
      AppLogger.info("✅ [/random.json] Returning response with #{preview_images.size} preview images...")
      response_data.to_json
    end

    # ========================================================================
    # P2 WEEK 2: REFACTORED ROUTES - Old implementations below (commented out)
    # NEW MODULAR ROUTES: routes/meme_stats.rb, routes/trending_routes.rb, routes/search_routes.rb
    # ========================================================================

    # post "/like" - NOW IN routes/meme_stats.rb
    # post "/report-broken-image" - NOW IN routes/meme_stats.rb
    # get "/trending" - NOW IN routes/trending_routes.rb
    # before "/category/*" - NOW IN routes/trending_routes.rb
    # get "/category/:name" - NOW IN routes/trending_routes.rb
    # get "/category/:name/meme/:title" - NOW IN routes/trending_routes.rb

    # Smart Hybrid Search helper method - KEPT for use by route modules
    def search_memes(query)
      return [] unless query

      # SECURITY FIX: Use Validators to prevent SQL injection


      begin


        sanitized_query = Validators.validate_search_query(query, min_length: 1, max_length: 200)


      rescue Validators::ValidationError => e


        AppLogger.warn("Invalid search query", query: query, error: e.message)


        return []


      end

      query_lower = sanitized_query.downcase

      # Tier 1: Search in-memory cache (instant, fresh Reddit memes)
      cache_results = (MEME_CACHE[:memes] || []).select do |m|
        (m["title"]&.downcase&.include?(query_lower) ||
         m["subreddit"]&.downcase&.include?(query_lower))
      end

      # Tier 2: If too few results, hit API for niche queries
      if cache_results.size < 3
        api_results = (fetch_reddit_memes(POPULAR_SUBREDDITS, 30) rescue []).select do |m|
          m["title"]&.downcase&.include?(query_lower) ||
          m["subreddit"]&.downcase&.include?(query_lower)
        end
        cache_results = (cache_results + api_results).uniq { |m| m["url"] }
      end

      # Tier 3: Fall back to DB + YAML if still empty
      # SECURITY FIX: Proper parameterized query with ESCAPE clause
      if cache_results.empty?
        db_results = (DB.execute(
          "SELECT * FROM meme_stats WHERE title ILIKE ? LIMIT 100",
          ["%#{sanitized_query}%"]
        ) rescue []).map { |r| r.transform_keys(&:to_s) }
        yaml_results = flatten_memes.select { |m| m["title"]&.downcase&.include?(query_lower) }
        cache_results = (db_results + yaml_results).uniq { |m| m["url"] || m["file"] }
      end

      # Rank results: exact match > title match > subreddit match, then by engagement
      ranked = cache_results.sort_by do |m|
        title = m["title"]&.downcase || ""
        subreddit = m["subreddit"]&.downcase || ""
        likes = m["likes"].to_i
        views = m["views"].to_i

        exact_match = title == query_lower ? 0 : 1
        title_match = title.include?(query_lower) ? 0 : 1
        subreddit_match = subreddit.include?(query_lower) ? 2 : 3
        engagement = -(likes * 2 + views) # Negative to sort descending

        [exact_match, title_match, subreddit_match, engagement]
      end

      ranked
    end

    # get "/search" - NOW IN routes/search_routes.rb
    # get "/api/search.json" - NOW IN routes/search_routes.rb

    end
  end
end
