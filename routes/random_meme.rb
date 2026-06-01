# routes/random_meme.rb
# Random meme routes - HTML and JSON endpoints

module Routes
  module RandomMeme
    def self.registered(app)
      # Render random meme page
      app.get "/random" do
        begin
          # Initialize session history
          session[:meme_history] ||= []
          
          # Get meme pool
          meme_pool = if app.class::MEME_CACHE[:memes].is_a?(Array) && !app.class::MEME_CACHE[:memes].empty?
            app.class::MEME_CACHE[:memes]
          else
            random_memes_pool
          end
          
          # 🎯 NEW: Use Diversity Engine for intelligent, non-repetitive selection
          require_relative '../lib/services/diversity_engine_service'
          
          session_id = session[:session_id] || session.id || "anonymous_#{request.ip}"
          user_prefs = {}
          
          # Use sophisticated diversity system
          @meme = MemeExplorer::DiversityEngineService.select_diverse_meme(
            meme_pool,
            session_id: session_id,
            preferences: user_prefs
          )
          
          # Fallback if something goes wrong
          @meme ||= fallback_meme
          
          # Track in session history
          if @meme
            meme_identifier = @meme["url"] || @meme["file"]
            session[:meme_history] << meme_identifier if meme_identifier
            session[:meme_history] = session[:meme_history].last(100) # Keep last 100
            
            # Track subreddit for diversity tracking
            if defined?(REDIS) && REDIS && @meme["subreddit"]
              key = "recent_subreddits:#{session_id}"
              recent_subs = (JSON.parse(REDIS.get(key) || '[]') rescue [])
              recent_subs << @meme["subreddit"].downcase
              REDIS.setex(key, 3600, recent_subs.last(20).to_json)
            end
          end
        rescue => e
          puts "Error in /random route: #{e.class}: #{e.message}"
          puts e.backtrace.first(5).join("\n")
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
          
          # PHASE 6: Track daily streak for retention
          if session[:user_id] && defined?(MemeExplorer::RetentionService)
            current_streak = MemeExplorer::RetentionService.track_daily_streak(session[:user_id]) rescue nil
            @streak_status = MemeExplorer::RetentionService.get_streak_status(session[:user_id]) rescue nil
            @social_proof = MemeExplorer::RetentionService.get_social_proof rescue nil
          end
          
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
      
      # JSON API endpoint for similar memes (more like this)
      app.get "/similar.json" do
        content_type :json
        puts "✨ [/similar.json] Request received"
        
        begin
          # Require subreddit parameter
          subreddit = params[:subreddit]&.strip&.downcase
          halt 400, { error: "Subreddit parameter required" }.to_json if subreddit.nil? || subreddit.empty?
          
          # Get meme pool
          meme_pool = if app.class::MEME_CACHE[:memes].is_a?(Array) && !app.class::MEME_CACHE[:memes].empty?
            app.class::MEME_CACHE[:memes]
          else
            random_memes_pool
          end
          
          halt 404, { error: "No memes available" }.to_json if meme_pool.empty?
          
          # Load Similar Meme Service
          require_relative '../lib/services/similar_meme_service'
          
          # Create source meme representation
          source_meme = { 'subreddit' => subreddit }
          session_id = session[:session_id] || session.id || "anonymous_#{request.ip}"
          
          # Find similar meme
          @meme = MemeExplorer::SimilarMemeService.find_similar(
            source_meme,
            meme_pool,
            session_id: session_id
          )
          
          halt 404, { error: "No similar memes found for #{subreddit}" }.to_json if @meme.nil?
          
          # Track the request for learning
          MemeExplorer::SimilarMemeService.track_similar_request(subreddit, session_id)
          
          # Track in session history
          meme_identifier = @meme["url"] || @meme["file"]
          session[:meme_history] ||= []
          session[:meme_history] << meme_identifier
          session[:meme_history] = session[:meme_history].last(100)
          
          image_url = @meme["url"] || @meme["file"]
          
          # Get reddit path
          reddit_path = nil
          if @meme["reddit_post_urls"]&.is_a?(Array)
            post_url = @meme["reddit_post_urls"].find { |u| u.include?(image_url) }
            reddit_path = post_url
          end
          
          if !reddit_path && @meme["permalink"].to_s.strip != ""
            reddit_path = @meme["permalink"]
          end
          
          if reddit_path&.start_with?("http")
            uri = URI.parse(reddit_path)
            reddit_path = uri.path
          end
          
          # Track view
          if !image_url.start_with?("/")
            meme_title = @meme["title"] || "Unknown"
            meme_subreddit = @meme["subreddit"] || "reddit"
            app.class::DB.execute(
              "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
              [image_url, meme_title, meme_subreddit]
            ) rescue nil
          end
          
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
          
          # Add gallery data if present
          if @meme["is_gallery"] && @meme["gallery_images"]
            response_data[:is_gallery] = true
            response_data[:gallery_images] = @meme["gallery_images"]
            response_data[:total_images] = @meme["gallery_images"].size
          end
          
          puts "✅ [/similar.json] Returning meme from #{@meme['subreddit']}"
          response_data.to_json
        rescue => e
          puts "❌ [/similar.json] Error: #{e.class}: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          halt 500, { error: "Internal server error", message: e.message }.to_json
        end
      end
      
      # JSON API endpoint for random memes with validation
      app.get "/random.json" do
        puts "🔄 [/random.json] Request received"
        
        # Use random_memes_pool for ALL users (both auth and non-auth) to ensure API memes are always available
        puts "🔄 [/random.json] Calling random_memes_pool..."
        memes = random_memes_pool
        puts "✅ [/random.json] Got #{memes.size} memes from pool"
        
        halt 404, { error: "No memes found" }.to_json if memes.empty?
        
        # CDN caching - 1 hour for meme data
        headers "Cache-Control" => "public, max-age=3600"
        headers "ETag" => Digest::MD5.hexdigest(memes.to_json)
        
        # 🎯 NEW: Use Diversity Engine for intelligent, non-repetitive selection
        require_relative '../lib/services/diversity_engine_service'
        
        session_id = session[:session_id] || session.id || "anonymous_#{request.ip}"
        user_prefs = {}
        
        # Use sophisticated diversity system
        @meme = MemeExplorer::DiversityEngineService.select_diverse_meme(
          memes,
          session_id: session_id,
          preferences: user_prefs
        )
        
        halt 404, { error: "No valid meme found" }.to_json if @meme.nil?
        
        puts "✅ [/random.json] Selected meme via Diversity Engine: #{@meme['title']} (Pool: #{@meme['diversity_pool']})"
        
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

        # Add gallery data if present
        if @meme["is_gallery"] && @meme["gallery_images"]
          response_data[:is_gallery] = true
          response_data[:gallery_images] = @meme["gallery_images"]
          response_data[:total_images] = @meme["gallery_images"].size
        end
        
        content_type :json
        puts "✅ [/random.json] Returning validated meme response#{@meme['is_gallery'] ? ' (GALLERY with ' + @meme['gallery_images'].size.to_s + ' images)' : ''}"
        response_data.to_json
      end
    end
  end
end
