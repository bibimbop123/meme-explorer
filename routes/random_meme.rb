# routes/random_meme.rb
# Random meme routes - HTML and JSON endpoints

module Routes
  module RandomMeme
    def self.registered(app)
      # Render random meme page
      app.get "/random" do
        begin
          # FAST: Serve from pre-warmed cache (instant)
          # If cache is empty or only has local memes, fallback to fresh pool
          if app.class::MEME_CACHE[:memes].is_a?(Array) && !app.class::MEME_CACHE[:memes].empty?
            @meme = app.class::MEME_CACHE[:memes].sample
          else
            # Cache empty or invalid - rebuild from scratch
            @meme = random_memes_pool.sample
          end
          @meme ||= fallback_meme
        rescue => e
          puts "Error in /random route: #{e.class}: #{e.message}"
          @meme = fallback_meme
        end
        
        # GAMIFICATION: Works for everyone! (uses session, not user_id)
        begin
          # Increment view count for milestones
          session[:view_count] ||= 0
          session[:view_count] += 1
          
          # Check if milestone reached
          milestone = MemeExplorer::MilestoneService.check_milestone(session[:view_count])
          if milestone
            @milestone = milestone
            # Only award to DB if logged in
            if session[:user_id]
              MemeExplorer::MilestoneService.award_milestone(session[:user_id], milestone) rescue nil
            end
          end
          
          # Get progress to next milestone
          @progress = MemeExplorer::MilestoneService.get_progress(session[:view_count])
          
          # PHASE 3: Check for near-miss tease
          if defined?(MemeExplorer::NearMissService)
            pool = app.class::MEME_CACHE[:memes] || []
            if MemeExplorer::NearMissService.should_show_tease?(pool, session[:user_id])
              @tease = MemeExplorer::NearMissService.generate_tease(pool, session[:user_id])
              MemeExplorer::NearMissService.track_tease_shown(@tease, session[:user_id]) if @tease
            end
          end
          
          # Check for surprise rewards (10% chance)
          if rand < 0.10
            @surprise_reward = {
              icon: ["🎁", "⚡", "🛡️", "🔥", "💎"].sample,
              title: ["Bonus XP!", "Double XP!", "Streak Freeze!", "Lucky You!", "Jackpot!"].sample,
              message: ["You earned bonus points!", "Your next meme counts double!", "Your streak is protected!", "Keep the momentum going!", "Fortune favors the bold!"].sample
            }
          end
        rescue => e
          puts "⚠️  Gamification error: #{e.class} - #{e.message}"
          puts e.backtrace.first(5).join("\n")
        end
        
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
          puts "⚠️ Reddit path error: #{e.message}"
        end
        
        # ASYNC: Track analytics in background (non-blocking)
        Thread.new do
          begin
            user_id = session[:user_id] rescue nil
            meme_identifier = @meme["url"] || @meme["file"]
            return unless meme_identifier
            
            # Track view
            app.class::DB.execute(
              "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
              [meme_identifier, @meme["title"] || "Unknown", @meme["subreddit"] || "local"]
            ) rescue nil
            
            # Track exposure for spaced repetition
            if user_id
              app.class::DB.execute(
                "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
                [user_id, meme_identifier]
              ) rescue nil
            end
          rescue => e
            puts "⚠️ Background analytics error: #{e.message}"
          end
        end

        erb :random
      end
      
      # JSON API endpoint for random memes with validation
      app.get "/random.json" do
        puts "🔄 [/random.json] Request received"
        
        # Use random_memes_pool for ALL users (both auth and non-auth) to ensure API memes are always available
        # This fixes the OAuth issue where new users only saw local memes
        puts "🔄 [/random.json] Calling random_memes_pool..."
        memes = random_memes_pool
        puts "✅ [/random.json] Got #{memes.size} memes from pool"
        
        halt 404, { error: "No memes found" }.to_json if memes.empty?
        
        # Validate memes before serving - skip broken images
        max_validation_attempts = 5
        validated_meme = nil
        
        # CDN caching - 1 hour for meme data
        headers "Cache-Control" => "public, max-age=3600"
        headers "ETag" => Digest::MD5.hexdigest(memes.to_json)
        
        # Track in session history and pick from pool
        session[:meme_history] ||= []
        session[:last_subreddit] ||= nil
        last_meme_url = session[:meme_history].last
        
        # Find a new meme that's different from last shown AND has valid image
        @meme = nil
        attempts = 0
        max_attempts = [memes.size, 30].min
        
        while attempts < max_attempts
          candidate = memes.sample
          candidate_id = candidate["url"] || candidate["file"]
          
          # Check if different from last shown
          if candidate_id && candidate_id != last_meme_url
            # Validate image URL before serving
            if ImageValidationService.validate(candidate_id)
              @meme = candidate
              puts "✅ [/random.json] Found valid meme with working image: #{@meme['title']}"
              break
            else
              puts "⚠️ [/random.json] Skipping meme with broken image: #{candidate_id}"
            end
          end
          attempts += 1
        end
        
        # If validation is too slow or all fail, serve anyway (fallback to client-side handling)
        if @meme.nil? && attempts >= max_attempts
          @meme = memes.sample
          puts "⚠️ [/random.json] Using non-validated meme after #{attempts} attempts"
        end
        
        halt 404, { error: "No valid meme found" }.to_json if @meme.nil?
        
        # Track in session history
        meme_identifier = @meme["url"] || @meme["file"]
        session[:meme_history] << meme_identifier
        session[:meme_history] = session[:meme_history].last(100)
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
          app.class::DB.execute(
            "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
            [image_url, meme_title, meme_subreddit]
          ) rescue nil
        end
        
        # No more client-side fallback chains - backend validation ensures working images
        media_type = detect_media_type(image_url)
        
        response_data = {
          title: @meme["title"],
          subreddit: @meme["subreddit"],
          file: @meme["file"],
          url: image_url,
          reddit_path: reddit_path,
          likes: get_meme_likes(image_url),
          media_type: media_type
        }
        
        content_type :json
        puts "✅ [/random.json] Returning validated meme response"
        response_data.to_json
      end
    end
  end
end
