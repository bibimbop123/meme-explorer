# Streak Reminder Worker
# Created: May 11, 2026
# Part of: Priority 1 Entertainment Enhancements
#
# Sends push notifications to users whose streaks are about to break
# Scheduled to run daily at 8 PM

class StreakReminderWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :notifications, retry: 3
  
  def perform
    start_time = Time.now
    AppLogger.info("🔔 [Streak Reminder] Starting daily streak reminder job at #{start_time}")
    
    # Get users who haven't visited today but have active streaks
    users_to_remind = DB.execute("
      SELECT u.id, u.reddit_username, u.email, us.current_streak, us.last_visit_date
      FROM users u
      JOIN user_streaks us ON u.id = us.user_id
      WHERE us.last_visit_date < CURRENT_DATE
      AND us.current_streak > 0
      AND EXISTS (
        SELECT 1 FROM push_subscriptions ps WHERE ps.user_id = u.id
      )
      ORDER BY us.current_streak DESC
    ")
    
    if users_to_remind.empty?
    AppLogger.info("✅ [Streak Reminder] No users need reminders today")
      return
    end
    AppLogger.info("📨 [Streak Reminder] Found #{users_to_remind.size} users to remind")
    
    # Send notifications
    sent_count = 0
    error_count = 0
    
    users_to_remind.each do |user|
      begin
        PushNotificationService.send_streak_reminder(
          user["id"],
          user["current_streak"]
        )
        sent_count += 1
        
        # Small delay to avoid rate limits
        sleep 0.1 if users_to_remind.size > 100
      rescue => e
    AppLogger.info("❌ [Streak Reminder] Error sending to user #{user['id']}: #{e.message}")
        error_count += 1
      end
    end
    
    duration = Time.now - start_time
    AppLogger.info("✅ [Streak Reminder] Complete! Sent #{sent_count} reminders (#{error_count} errors) in #{duration.round(2)}s")
    
    # Log to Sentry if too many errors
    if error_count > sent_count * 0.1 # More than 10% error rate
      Sentry.capture_message(
        "High error rate in streak reminders: #{error_count}/#{users_to_remind.size}",
        level: :warning
      ) if defined?(Sentry)
    end
  rescue => e
    AppLogger.info("❌ [Streak Reminder] Job failed: #{e.message}")
    AppLogger.info(e.backtrace.first(5))
    
    Sentry.capture_exception(e) if defined?(Sentry)
    raise e
  end
end
