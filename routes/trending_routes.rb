# routes/trending_routes.rb
# Trending memes and category browsing

module Routes
  module TrendingRoutes
    def self.registered(app)
      # Trending memes page
      app.get "/trending" do
        @memes = begin
          TrendingService.curated_top_memes(limit: 20, fallback_pool: (random_memes_pool rescue []))
        rescue => e
          AppLogger.error("⚠️ [TRENDING] Error: #{e.class} - #{e.message}")
          []
        end
        
        erb :trending
      end

      # BUG FIX: documented in README.md ("GET /trending.json - Trending
      # memes API") and directly exercised by
      # spec/routes/trending_routes_spec.rb, but never actually
      # implemented as a route anywhere in the codebase - every request to
      # it 404'd. TrendingService.get_trending_memes already implements
      # exactly this (SQL-side scoring with time decay, see
      # lib/services/trending_service.rb); this route just exposes it.
      app.get "/trending.json" do
        content_type :json

        limit = params[:limit].to_i
        limit = 20 if limit <= 0

        hours = case params[:period]
                when '1h' then 1
                when '24h' then 24
                when '7d' then 168
                else 24 # invalid/unspecified period falls back to the default window
                end

        # Uses TrendingService's own Redis-backed cache (5min TTL) rather
        # than querying meme_stats fresh on every request - same caching
        # this service already implements for exactly this endpoint's
        # workload, just not previously wired up to a real route.
        memes = begin
          TrendingService.cached_trending(time_window: hours)
        rescue => e
          AppLogger.error("⚠️ [TRENDING.JSON] #{e.class}: #{e.message}")
          []
        end

        memes = memes.first(limit) if limit > 0
        memes.map { |m| m.transform_keys(&:to_s) }.to_json
      end

      # BUG FIX: same gap as /trending.json above - documented behavior
      # (README's API Endpoints list references trending JSON APIs) with
      # no actual route, only a disabled experimental
      # routes/api/v1/trending_optimized.rb (never registered in app.rb).
      # Wraps TrendingService.trending_memes, which already returns a
      # {memes:, pagination:} shape - this route just adds the top-level
      # `count`/`period` metadata callers reasonably expect from an
      # "/api/..." endpoint.
      app.get "/api/trending" do
        content_type :json

        result = begin
          TrendingService.trending_memes(
            time_window: params[:period] || '24h',
            sort_by: params[:sort_by] || 'trending',
            limit: (params[:limit].to_i > 0 ? params[:limit].to_i : 20)
          )
        rescue => e
          AppLogger.error("⚠️ [API/TRENDING] #{e.class}: #{e.message}")
          { memes: [], pagination: { has_more: false, next_cursor: nil, total: 0 } }
        end

        {
          memes: result[:memes].map { |m| m.transform_keys(&:to_s) },
          count: result[:memes].length,
          period: params[:period] || '24h',
          pagination: result[:pagination]
        }.to_json
      end
      
      # BUG FIX: the client-side controller for /trending
      # (public/js/trending.js) fetches from `/api/v1/trending` on every
      # single load (initial + infinite scroll) - but that route has
      # never existed anywhere in this codebase (only a disabled,
      # never-registered routes/api/v1/trending_optimized.rb). Every
      # request to /trending has silently failed to load ANY memes since
      # this frontend was written - not just missing ads, but missing all
      # content. Wired up the real route, in the exact shape
      # trending.js expects (`{data: [...], pagination: {next_cursor,
      # has_more}}` - note `data`, not `memes`, unlike /api/trending
      # above, which trending.js does NOT call).
      app.get "/api/v1/trending" do
        content_type :json

        result = begin
          TrendingService.trending_memes(
            time_window: params[:time_window] || '24h',
            sort_by: params[:sort_by] || 'trending',
            limit: (params[:limit].to_i > 0 ? params[:limit].to_i : 20),
            cursor: params[:cursor]
          )
        rescue => e
          AppLogger.error("⚠️ [API/V1/TRENDING] #{e.class}: #{e.message}")
          { memes: [], pagination: { has_more: false, next_cursor: nil, total: 0 } }
        end

        {
          data: result[:memes].map { |m| m.transform_keys(&:to_s) },
          pagination: result[:pagination]
        }.to_json
      end

      # Before filter for category routes
      app.before "/category/*" do
        # Define default categories if not loaded
        @categories = {
          funny: ["funny", "memes"],
          wholesome: ["wholesome", "aww"],
          dank: ["dank", "dankmemes"],
          selfcare: ["selfcare", "wellness"]
        }
      end
      
      # Browse memes by category
      app.get "/category/:name" do
        category_name = params[:name].to_sym
        subreddits = @categories[category_name]
        halt 404, { error: "Category not found" }.to_json unless subreddits && !subreddits.empty?
      
        # Filter valid memes
        local_memes = MemeExplorer::App::MEMES.is_a?(Hash) ? MemeExplorer::App::MEMES[category_name.to_s] || [] : []
        api_memes = (fetch_fresh_memes(batch_size: 50) rescue []).select { |m| subreddits.include?(m["subreddit"]) }
      
        @memes = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
      
        # Use fallback only if empty
        @memes = [fallback_meme.merge("subreddit" => category_name.to_s)] if @memes.empty?
      
        if request.accept?("application/json")
          content_type :json
          @memes.to_json
        else
          @category_name = category_name
          erb :category, layout: :layout
        end
      end
      
      # View specific meme in a category
      app.get "/category/:name/meme/:title" do
        category_name = params[:name].to_sym
        subreddits = @categories[category_name] || []
      
        local_memes = MemeExplorer::App::MEMES.is_a?(Hash) ? MemeExplorer::App::MEMES[category_name.to_s] || [] : []
        api_memes = (fetch_fresh_memes(batch_size: 50) rescue []).select { |m| subreddits.include?(m["subreddit"]) }
      
        combined = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
      
        requested_title = URI.decode_www_form_component(params[:title])
        @meme = combined.find { |m| m["title"] == requested_title }
      
        # Fallback
        @meme ||= fallback_meme.merge("subreddit" => category_name.to_s)
        @image_src = meme_image_src(@meme)
      
        erb :random, layout: :layout
      end
    end
  end
end
