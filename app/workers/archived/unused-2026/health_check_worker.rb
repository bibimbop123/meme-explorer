# frozen_string_literal: true

# Worker for periodic health checks
class HealthCheckWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :critical, retry: 3
  
  def perform
    AppLogger.info('[HEALTH] Starting health check')
    
    alerts = AlertService.check_health
    
    if alerts.any?
      alerts.each do |alert|
        AlertService.send_alert(alert, level: :warning)
      end
      AppLogger.warn("[HEALTH] #{alerts.count} alerts found")
    else
      AppLogger.info('[HEALTH] All systems nominal')
    end
  rescue => e
    AppLogger.error("[HEALTH] Health check failed: #{e.message}")
    AppLogger.error(e.backtrace.first(5).join("\n"))
  end
end
