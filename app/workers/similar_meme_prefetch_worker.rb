# Similar Meme Prefetch Worker - Phase 1
# Prefetches similar memes for popular subreddits
# Runs every 10 minutes via Sidekiq
# Created: June 3, 2026

require 'sidekiq'

class SimilarMemePrefetchWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 2, backtrace: true
  
  def perform
    AppLogger.info("🔄 [SimilarMemePrefetch] Starting prefetch job at #{Time.now}")
    
    # Load and prefetch similar memes
    require_relative '../../lib/services/similar_meme_cache'
    
    result = SimilarMemeCache.prefetch_all_popular!
    AppLogger.info("✅ [SimilarMemePrefetch] Job complete: #{result[:prefetched]} cached, #{result[:failed]} failed")
    
  rescue => e
    AppLogger.info("❌ [SimilarMemePrefetch] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry
  end
end
