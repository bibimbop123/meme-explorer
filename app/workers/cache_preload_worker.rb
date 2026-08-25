# Cache Preload Worker
# Warms MEME_CACHE with memes on application startup (Sidekiq @reboot job).
# Referenced by app.rb (triggered via perform_async on boot) and
# config/sidekiq.yml (scheduled cron: '@reboot'), but was previously missing
# entirely, so both the direct on-boot trigger and the schedule were dead.
# Restored/created: August 25, 2026
#
# Delegates to CacheRefreshWorker's logic so there's a single source of truth
# for how the meme cache gets populated (local + Reddit memes, validated).
require_relative 'cache_refresh_worker'

class CachePreloadWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3, backtrace: true

  def perform
    AppLogger.info("🚀 [CACHE PRELOAD] Warming cache on startup at #{Time.now}")
    CacheRefreshWorker.new.perform
    AppLogger.info("✅ [CACHE PRELOAD] Startup cache warm complete")
  rescue => e
    AppLogger.error("❌ [CACHE PRELOAD] Error: #{e.message}")
    AppLogger.error(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    raise # Re-raise for Sidekiq retry
  end
end
