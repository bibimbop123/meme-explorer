# frozen_string_literal: true

require_relative '../app_logger'
require_relative '../services/diversity_engine_service'
require_relative '../services/viewing_history_service'
require_relative '../services/milestone_service'
require_relative '../services/retention_service'
require_relative '../services/near_miss_service'

module MemeExplorer
  # Controller for handling random meme selection and display
  # Extracted from routes/random_meme.rb to improve maintainability
  class RandomMemeController
    # Result object to return data to the route
    class Result
      attr_accessor :meme, :milestone, :surprise_reward, :streak_status,
                    :social_proof, :tease, :progress, :image_src, :reddit_path, :likes
      
      def initialize
        @likes = 0
      end
    end
    
    # Main entry point for controller
    def self.handle(session:, user_id:, request_ip:)
      new.handle(session: session, user_id: user_id, request_ip: request_ip)
    end
    
    def handle(session:, user_id:, request_ip:)
      result = Result.new
      
      # 1. Initialize session
      session[:meme_history] ||= []
      session_id = session[:session_id]
      
      # 2. Get meme pool
      meme_pool = get_meme_pool
      
      # 3. Select meme with diversity engine
      result.meme = select_meme(meme_pool, session_id)
      
      # 4. Track viewing history
      track_viewing(result.meme, session_id)
      
      # 5. Handle gamification
      handle_gamification(result, session, user_id)
      
      # 6. Prepare display data
      prepare_display_data(result)
      
      # 7. Track analytics (async)
      track_analytics(result.meme, user_id)
      
      result
    rescue => e
      handle_error(e, session)
    end
    
    private
    
    def get_meme_pool
      # Use unified MemePool service (Day 7)
      if defined?(MemeExplorer::MemePool)
        MemeExplorer::MemePool.get
      else
        # Fallback to old logic
        if defined?(MemeExplorer::App::MEME_CACHE) && 
           MemeExplorer::App::MEME_CACHE[:memes].is_a?(Array) && 
           !MemeExplorer::App::MEME_CACHE[:memes].empty?
          MemeExplorer::App::MEME_CACHE[:memes]
        else
          random_memes_pool
        end
      end
    end
      
      # Emergency fallback
      random_memes_pool
    end
    
    def from_pool_manager
      return nil unless defined?(MemeExplorer::MemePoolManager)
      
      result = MemeExplorer::MemePoolManager.get_pool
      result[:success] ? result[:memes] : nil
    rescue => e
      AppLogger.warn("MemePoolManager error", error: e.message)
      nil
    end
    
    def random_memes_pool
      # Load from various sources
      if defined?(MEMES)
        if MEMES.is_a?(Hash)
          MEMES.values.flatten.compact
        elsif MEMES.is_a?(Array)
          MEMES
        else
          []
        end
      else
        []
      end
    rescue => e
      AppLogger.error("Random memes pool error", error: e.message)
      []
    end
    
    def select_meme(pool, session_id)
      return fallback_meme if pool.nil? || pool.empty?
      
      meme = MemeExplorer::DiversityEngineService.select_diverse_meme(
        pool,
        session_id: session_id,
        preferences: {}
      )
      
      meme || fallback_meme
    rescue => e
      AppLogger.error("Meme selection error", error: e.message)
      fallback_meme
    end
    
    def fallback_meme
      {
        "title" => "Welcome to Meme Explorer!",
        "file" => "/images/meme-placeholder.svg",
        "subreddit" => "local",
        "type" => "image"
      }
    end
    
    def track_viewing(meme, session_id)
      return unless meme
      
      meme_identifier = meme["url"] || meme["file"]
      return unless meme_identifier
      
      MemeExplorer::ViewingHistoryService.mark_seen(session_id, meme_identifier)
      
      # Track recent subreddits
      if defined?(REDIS) && REDIS && meme["subreddit"]
        key = "recent_subreddits:#{session_id}"
        recent_subs = (JSON.parse(REDIS.get(key) || '[]') rescue [])
        recent_subs << meme["subreddit"].downcase
        REDIS.setex(key, 3600, recent_subs.last(20).to_json)
      end
    rescue => e
      AppLogger.warn("Viewing tracking error", error: e.message)
    end
    
    def handle_gamification(result, session, user_id)
      # View count
      session[:view_count] ||= 0
      session[:view_count] += 1
      
      # Milestone check
      if defined?(MemeExplorer::MilestoneService)
        milestone = MemeExplorer::MilestoneService.check_milestone(session[:view_count])
        if milestone
          result.milestone = milestone
          if user_id
            begin
              MemeExplorer::MilestoneService.award_milestone(user_id, milestone)
            rescue => e
              AppLogger.warn("Failed to award milestone", error: e.message, user_id: user_id)
            end
          end
        end
        
        result.progress = MemeExplorer::MilestoneService.get_progress(session[:view_count])
      end
      
      # Streak tracking
      if user_id && defined?(MemeExplorer::RetentionService)
        begin
          result.streak_status = MemeExplorer::RetentionService.get_streak_status(user_id)
        rescue => e
          AppLogger.warn("Failed to get streak status", error: e.message, user_id: user_id)
          result.streak_status = nil
        end
        
        begin
          result.social_proof = MemeExplorer::RetentionService.get_social_proof
        rescue => e
          AppLogger.warn("Failed to get social proof", error: e.message)
          result.social_proof = nil
        end
      end
      
      # Near-miss tease
      if defined?(MemeExplorer::NearMissService)
        pool = get_meme_pool
        if MemeExplorer::NearMissService.should_show_tease?(pool, user_id)
          result.tease = MemeExplorer::NearMissService.generate_tease(pool, user_id) rescue nil
        end
      end
      
      # Surprise rewards (10% chance)
      if rand < 0.10
        result.surprise_reward = generate_surprise_reward
      end
    rescue => e
      AppLogger.error("Gamification error", error: e.message)
    end
    
    def generate_surprise_reward
      {
        icon: ["🎁", "⚡", "🛡️", "🔥", "💎"].sample,
        title: ["Bonus XP!", "Double XP!", "Streak Freeze!", "Lucky You!", "Jackpot!"].sample,
        message: ["You earned bonus points!", "Your next meme counts double!", 
                  "Your streak is protected!", "Keep the momentum going!", 
                  "Fortune favors the bold!"].sample
      }
    end
    
    def prepare_display_data(result)
      result.image_src = meme_image_src(result.meme)
      result.reddit_path = extract_reddit_path(result.meme, result.image_src)
      result.likes = 0  # Will be loaded by JavaScript
    end
    
    def meme_image_src(meme)
      return "/images/meme-placeholder.svg" unless meme
      
      if meme["file"]
        meme["file"]
      elsif meme["url"]
        meme["url"]
      else
        "/images/meme-placeholder.svg"
      end
    end
    
    def extract_reddit_path(meme, image_src)
      return nil unless meme
      
      # Try reddit_post_urls
      if meme["reddit_post_urls"]&.is_a?(Array)
        post_url = meme["reddit_post_urls"].find { |u| u.include?(image_src) }
        return post_url if post_url
      end
      
      # Try permalink
      if meme["permalink"].to_s.strip != ""
        path = meme["permalink"]
        path = URI.parse(path).path if path.start_with?("http")
        return path
      end
      
      nil
    rescue => e
      AppLogger.error("Reddit path extraction error", error: e.message)
      nil
    end
    
    def track_analytics(meme, user_id)
      return unless meme
      
      meme_identifier = meme["url"] || meme["file"]
      return unless meme_identifier
      
      # Use Sidekiq worker for async writes (Day 6)
      if defined?(MemeStatsWriter)
        MemeStatsWriter.perform_async(
          meme_identifier,
          meme["title"] || "Unknown",
          meme["subreddit"] || "local",
          user_id
        )
      else
        # Fallback to thread pool
        if defined?(ANALYTICS_POOL)
          ANALYTICS_POOL.post do
            write_analytics(meme_identifier, meme["title"], meme["subreddit"], user_id)
          end
        else
          write_analytics(meme_identifier, meme["title"], meme["subreddit"], user_id) rescue nil
        end
      end
    rescue => e
      AppLogger.warn("Analytics tracking error", error: e.message)
    end
      else
        # Synchronous fallback
        write_analytics(meme_identifier, meme["title"], meme["subreddit"], user_id) rescue nil
      end
    rescue => e
      AppLogger.warn("Analytics tracking error", error: e.message)
    end
    
    def write_analytics(meme_identifier, title, subreddit, user_id)
      return unless defined?(MemeExplorer::App::DB)
      
      MemeExplorer::App::DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) 
         VALUES (?, ?, ?, 1, 0) 
         ON CONFLICT(url) DO UPDATE SET 
         views = meme_stats.views + 1, 
         updated_at = CURRENT_TIMESTAMP",
        [meme_identifier, title || "Unknown", subreddit || "local"]
      )
      
      if user_id
        MemeExplorer::App::DB.execute(
          "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) 
           VALUES (?, ?, 1) 
           ON CONFLICT(user_id, meme_url) DO UPDATE SET 
           shown_count = shown_count + 1, 
           last_shown = CURRENT_TIMESTAMP",
          [user_id, meme_identifier]
        )
      end
    rescue => e
      AppLogger.warn("Background analytics failed", error: e.message)
    end
    
    def handle_error(error, session)
      AppLogger.error("Random meme controller error", 
        error: error.message,
        backtrace: error.backtrace.first(5)
      )
      
      result = Result.new
      result.meme = fallback_meme
      result.image_src = meme_image_src(result.meme)
      result.likes = 0
      result
    end
  end
end
