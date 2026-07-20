# Image Health Worker
# Proactively validates cached memes every 30 minutes
# Removes broken URLs before users encounter them

class ImageHealthWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :low_priority, retry: 2, backtrace: true
  
  def perform
    AppLogger.info("🏥 [IMAGE HEALTH] Starting proactive validation at #{Time.now}")
    
    start_time = Time.now
    
    # Get current meme cache
    cached_memes = MEME_CACHE.get(:memes) || []
    
    if cached_memes.empty?
    AppLogger.info("⚠️ [IMAGE HEALTH] No memes in cache to validate")
      return
    end
    AppLogger.info("🔍 [IMAGE HEALTH] Validating #{cached_memes.size} cached memes...")
    
    validated_count = 0
    failed_count = 0
    blacklisted_count = 0
    
    cached_memes.each_with_index do |meme, index|
      url = meme["url"] || meme["file"]
      next unless url
      next if url.start_with?('/') # Skip local files
      
      # Check if already blacklisted (skip validation)
      if defined?(ImageHealthService) && ImageHealthService.blacklisted?(url)
        blacklisted_count += 1
        next
      end
      
      # Validate URL
      is_valid = ImageValidationService.validate(url, use_cache: false) # Force fresh check
      
      if is_valid
        validated_count += 1
      else
        failed_count += 1
      end
      
      # Log progress every 50 memes
      if (index + 1) % 50 == 0
    AppLogger.info("   Progress: #{index + 1}/#{cached_memes.size} checked")
      end
      
      # Be nice to external servers - small delay
      sleep 0.1 if index % 10 == 0
    end
    
    duration = (Time.now - start_time).round(2)
    
    # Remove blacklisted memes from cache
    if defined?(ImageHealthService)
      before_filter = cached_memes.size
      clean_memes = ImageHealthService.filter_blacklisted(cached_memes)
      removed = before_filter - clean_memes.size
      
      if removed > 0
        MEME_CACHE.set(:memes, clean_memes.shuffle)
    AppLogger.info("🧹 [IMAGE HEALTH] Removed #{removed} blacklisted memes from cache")
      end
    end
    AppLogger.info("✅ [IMAGE HEALTH] Validation complete in #{duration}s:")
    AppLogger.info("   - Validated: #{validated_count}")
    AppLogger.info("   - Failed: #{failed_count}")
    AppLogger.info("   - Already blacklisted: #{blacklisted_count}")
    
    # Clean up old records
    if defined?(ImageHealthService)
      cleaned = ImageHealthService.cleanup_old_records
    AppLogger.info("🧹 [IMAGE HEALTH] Cleaned up #{cleaned} old tracking records") if cleaned > 0
    end
    
    # Log statistics
    if defined?(ImageHealthService)
      stats = ImageHealthService.stats
    AppLogger.info("📊 [IMAGE HEALTH] Current stats: #{stats.inspect}")
    end
    
  rescue => e
    AppLogger.info("❌ [IMAGE HEALTH] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry
  end
end
