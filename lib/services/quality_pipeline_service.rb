# Quality Pipeline Service - Phase 1
# 6-stage quality validation pipeline for meme content
# Created: June 3, 2026

class QualityPipelineService
  STAGES = [
    :technical_validation,
    :engagement_validation,
    :content_safety,
    :visual_quality,
    :user_feedback_score,
    :novelty_check
  ].freeze
  
  class << self
    # Main entry point - validates meme through all quality gates
    def passes_all_gates?(meme)
      return false unless meme.is_a?(Hash)
      
      STAGES.all? { |stage| send("#{stage}_passes?", meme) }
    rescue => e
      log_error("Quality pipeline error for #{meme['url']}", e)
      false
    end
    
    # Get detailed quality report for a meme
    def quality_report(meme)
      return { passed: false, stages: {}, score: 0.0 } unless meme.is_a?(Hash)
      
      stage_results = {}
      STAGES.each do |stage|
        stage_results[stage] = send("#{stage}_passes?", meme)
      end
      
      passed_count = stage_results.values.count(true)
      quality_score = (passed_count.to_f / STAGES.size * 100).round(2)
      
      {
        passed: stage_results.values.all?,
        stages: stage_results,
        score: quality_score,
        total_stages: STAGES.size,
        passed_stages: passed_count
      }
    rescue => e
      log_error("Quality report error for #{meme['url']}", e)
      { passed: false, stages: {}, score: 0.0, error: e.message }
    end
    
    private
    
    # STAGE 1: Technical Validation
    # Ensures meme has all required fields and valid URLs
    def technical_validation_passes?(meme)
      return false unless meme["url"].to_s.strip.length > 0
      return false unless meme["title"].to_s.strip.length > 0
      return false unless meme["subreddit"].to_s.strip.length > 0
      
      # Validate URL format
      url = meme["url"]
      return false unless url =~ /^https?:\/\//
      
      # Check for known bad patterns
      return false if url.include?('reddit.com/gallery/') && !meme["is_gallery"]
      return false if url.include?('v.redd.it') # Video links
      return false if url.end_with?('.mp4', '.webm', '.mov')
      
      true
    end
    
    # STAGE 2: Engagement Validation
    # Ensures meme has minimum engagement metrics
    def engagement_validation_passes?(meme)
      likes = meme["likes"].to_i
      
      # Minimum 10 upvotes to ensure it's not spam
      # Popular subreddits should have higher threshold
      min_likes = popular_subreddit?(meme["subreddit"]) ? 50 : 10
      
      likes >= min_likes
    end
    
    # STAGE 3: Content Safety
    # Basic content safety checks
    def content_safety_passes?(meme)
      title = meme["title"].to_s.downcase
      url = meme["url"].to_s.downcase
      
      # Block NSFW indicators
      nsfw_keywords = ['nsfw', 'nsfl', 'xxx', 'porn', 'nude', 'naked']
      return false if nsfw_keywords.any? { |kw| title.include?(kw) || url.include?(kw) }
      
      # Block spam patterns
      spam_patterns = ['click here', 'buy now', 'limited offer', 'act now']
      return false if spam_patterns.any? { |pattern| title.include?(pattern) }
      
      # Block excessively long titles (usually spam)
      return false if title.length > 300
      
      true
    end
    
    # STAGE 4: Visual Quality
    # Checks for image format and quality indicators
    def visual_quality_passes?(meme)
      url = meme["url"].to_s.downcase
      
      # Accept common image formats
      valid_formats = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
      has_valid_extension = valid_formats.any? { |ext| url.include?(ext) }
      
      # Also accept Reddit image URLs (i.redd.it, i.imgur.com, etc.)
      is_reddit_image = url.include?('i.redd.it') || 
                        url.include?('i.imgur.com') || 
                        url.include?('imgur.com') ||
                        meme["is_gallery"]
      
      has_valid_extension || is_reddit_image
    end
    
    # STAGE 5: User Feedback Score
    # Checks historical user feedback if available
    def user_feedback_score_passes?(meme)
      url = meme["url"]
      
      # Check if meme is in broken images list
      if defined?(ImageHealthService)
        return false if ImageHealthService.blacklisted?(url)
      end
      
      # Check meme stats if available
      if defined?(DB)
        stats = DB.execute(
          "SELECT likes, views, failure_count FROM meme_stats WHERE url = ? LIMIT 1",
          [url]
        ).first
        
        if stats
          # Reject if failure count is too high
          return false if stats['failure_count'].to_i >= 3
          
          # Reject if like rate is too low (less than 5%)
          views = stats['views'].to_i
          likes = stats['likes'].to_i
          return false if views > 100 && (likes.to_f / views) < 0.05
        end
      end
      
      true
    rescue => e
      # If database check fails, don't reject the meme
      log_error("User feedback score check error", e)
      true
    end
    
    # STAGE 6: Novelty Check
    # Ensures meme hasn't been seen too recently
    def novelty_check_passes?(meme)
      url = meme["url"]
      
      # Check Redis cache for recent appearances
      if defined?(RedisService)
        key = "meme:seen:#{url}"
        last_seen = RedisService.get(key)
        
        if last_seen
          last_seen_time = Time.parse(last_seen) rescue nil
          if last_seen_time
            # Reject if seen within last 24 hours
            hours_since_seen = (Time.now - last_seen_time) / 3600
            return false if hours_since_seen < 24
          end
        end
        
        # Mark as seen
        RedisService.setex(key, 86400, Time.now.to_s) # 24 hour expiry
      end
      
      true
    rescue => e
      # If Redis check fails, don't reject the meme
      log_error("Novelty check error", e)
      true
    end
    
    # Helper: Check if subreddit is in popular tier
    def popular_subreddit?(subreddit)
      return false unless subreddit
      
      popular_subs = YAML.load_file('data/subreddits.yml')['tier_1'] rescue []
      popular_subs.include?(subreddit.downcase)
    rescue
      false
    end
    
    # Centralized error logging
    def log_error(context, error)
      message = error.is_a?(String) ? error : error.message
      puts "⚠️  [QualityPipeline] #{context}: #{message}"
      
      # Send to Sentry if available
      if defined?(Sentry) && error.is_a?(Exception)
        Sentry.capture_exception(error, extra: { context: context })
      end
    end
  end
end
