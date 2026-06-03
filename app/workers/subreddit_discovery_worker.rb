# Subreddit Discovery Worker - Phase 2
# Runs weekly to discover new quality subreddits
# Created: June 3, 2026

require 'sidekiq'

class SubredditDiscoveryWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :low, retry: 2, backtrace: true
  
  def perform
    puts "🔍 [SubredditDiscovery] Starting auto-discovery at #{Time.now}"
    
    require_relative '../../lib/services/subreddit_discovery_service'
    
    result = SubredditDiscoveryService.auto_discover_and_save!
    
    if result[:saved]
      puts "✅ [SubredditDiscovery] Success: #{result[:discovered]} new candidates found"
      puts "   Total candidates: #{result[:total]}"
    else
      puts "⚠️  [SubredditDiscovery] No new subreddits found"
    end
    
  rescue => e
    puts "❌ [SubredditDiscovery] Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry
  end
end
