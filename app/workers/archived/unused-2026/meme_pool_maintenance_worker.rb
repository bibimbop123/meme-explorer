# Meme Pool Maintenance Worker - Phase 2
# Runs every 5 minutes to maintain 5,000-meme pool
# Created: June 3, 2026

require 'sidekiq'

class MemePoolMaintenanceWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 3, backtrace: true
  
  def perform
    AppLogger.info("🔄 [PoolMaintenance] Starting pool maintenance at #{Time.now}")
    
    require_relative '../../lib/services/meme_pool_manager'
    
    result = MemePoolManager.maintain_pool!
    
    if result[:success]
    AppLogger.info("✅ [PoolMaintenance] Success: Pool at #{result[:pool_size]} memes")
    else
    AppLogger.info("❌ [PoolMaintenance] Failed: #{result[:error]}")
    end
    
  rescue => e
    AppLogger.info("❌ [PoolMaintenance] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry
  end
end
