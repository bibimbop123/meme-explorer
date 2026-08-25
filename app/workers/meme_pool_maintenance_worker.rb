# Meme Pool Maintenance Worker - Phase 2
# Proactively refreshes the shared meme pool on a schedule (every 5 minutes,
# see config/sidekiq.yml) so the pool is replenished BEFORE it runs dry,
# instead of reactively bootstrapping (and re-hitting Reddit) on request.
# Restored: August 25, 2026 (was archived/unused, never actually scheduled)

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
      # Don't raise/retry on a plain "no-op" or rate-limited maintenance run —
      # only genuine unexpected errors should trigger Sidekiq retries.
      AppLogger.warn("⚠️  [PoolMaintenance] Not fully successful: #{result[:error]}")
    end
  rescue => e
    AppLogger.error("❌ [PoolMaintenance] Error: #{e.message}")
    AppLogger.error(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry
  end
end
