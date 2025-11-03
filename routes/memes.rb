# Meme Routes
module MemeExplorer
  module Routes
    class Memes
      def self.register(app)
        app.get "/" do
          @meme = app.helpers.navigate_meme_unified(direction: "next")
          @image_src = app.helpers.meme_image_src(@meme)
          erb :random
        end

        app.get "/random" do
          memes = app.class::MEME_CACHE[:memes] || []
          halt 404, "No memes found!" if memes.empty?

          @meme = memes.sample
          @image_src = app.helpers.meme_image_src(@meme)
          @likes = MemeService.get_likes(@image_src)
          @reddit_path = extract_reddit_path(@meme, @image_src)

          erb :random
        end

        app.get "/random.json" do
          memes = app.class::MEME_CACHE[:memes] || []
          halt 404, { error: "No memes found" }.to_json if memes.empty?

          headers "Cache-Control" => "public, max-age=60"

          session[:meme_history] ||= []
          session[:last_subreddit] ||= nil
          last_meme_url = session[:meme_history].last

          @meme = find_new_meme(memes, last_meme_url)
          halt 404, { error: "No valid meme found" }.to_json if @meme.nil?

          track_meme_view(@meme, session)

          content_type :json
          format_meme_response(@meme)
        end

        app.post "/like" do
          url = params[:url]
          halt 400, { error: "No URL provided" }.to_json unless url

          session[:liked_memes] ||= []

          liked_now = if session[:liked_memes].include?(url)
                        session[:liked_memes].delete(url)
                        false
                      else
                        session[:liked_memes] << url
                        true
                      end

          likes = MemeService.toggle_like(url, liked_now, session, DB)

          content_type :json
          { liked: liked_now, likes: likes }.to_json
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
            results = SearchService.search(query, MemeService.cached_memes, app.class::POPULAR_SUBREDDITS)
            content_type :json
            {
              query: query,
              results: results.map { |m| format_search_result(m) },
              total: results.size
            }.to_json
          else
            @results = SearchService.search(query, MemeService.cached_memes, app.class::POPULAR_SUBREDDITS)
            @query = query
            erb :search
          end
        end

        app.get "/api/search.json" do
          query = params[:q]
          results = SearchService.search(query, MemeService.cached_memes, app.class::POPULAR_SUBREDDITS)

          content_type :json
          {
            query: query,
            results: results.map { |m| format_search_result(m) },
            total: results.size
          }.to_json
        end

        app.get "/trending" do
          db_memes = DB.execute("SELECT url, title, subreddit, views, likes, (likes * 2 + views) AS score FROM meme_stats")
          @memes = db_memes.sort_by { |m| -(m["score"].to_i) }.first(20)
          erb :trending
        end

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

          local_memes = app.class::MEMES.is_a?(Hash) ? app.class::MEMES[category_name.to_s] || [] : []
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

      private

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
end
