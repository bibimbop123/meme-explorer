# Push Notification Service for Meme Explorer
# Created: May 11, 2026
# Part of: Priority 1 Entertainment Enhancements
# 
# Handles browser push notifications for:
# - Streak reminders
# - Level up celebrations
# - Achievement unlocks
# - Weekly challenge alerts

require 'web-push'

class PushNotificationService
  # Send streak reminder to user
  def self.send_streak_reminder(user_id, streak_days)
    subscriptions = get_user_subscriptions(user_id)
    return if subscriptions.empty?
    
    message = {
      title: "🔥 Don't lose your #{streak_days}-day streak!",
      body: "Quick! View a meme to keep your streak alive! ⚡",
      url: "/random"
    }
    
    send_to_subscriptions(subscriptions, message)
  end
  
  # Send milestone celebration
  def self.send_milestone_celebration(user_id, milestone_type, details = {})
    subscriptions = get_user_subscriptions(user_id)
    return if subscriptions.empty?
    
    message = case milestone_type
    when :level_up
      {
        title: "🎉 LEVEL UP!",
        body: "You're now Level #{details[:level]}! Come see your rewards!",
        url: "/profile"
      }
    when :streak_milestone
      {
        title: "🔥 #{details[:days]}-DAY STREAK!",
        body: "You're on fire! Keep the momentum going!",
        url: "/leaderboard"
      }
    when :achievement
      {
        title: "🏆 Achievement Unlocked!",
        body: "#{details[:name]} - #{details[:description]}",
        url: "/profile"
      }
    when :referral
      {
        title: "🎁 Friend Joined!",
        body: details[:message] || "Your referral worked! +200 XP",
        url: "/profile"
      }
    else
      {
        title: "✨ Meme Explorer",
        body: details[:message] || "Something awesome happened!",
        url: "/random"
      }
    end
    
    send_to_subscriptions(subscriptions, message)
  end
  
  # Send weekly challenge reminder
  def self.send_weekly_challenge_reminder(user_id, challenge)
    subscriptions = get_user_subscriptions(user_id)
    return if subscriptions.empty?
    
    message = {
      title: "⏰ Challenge Ending Soon!",
      body: "#{challenge[:description]} - Last chance to win!",
      url: "/leaderboard"
    }
    
    send_to_subscriptions(subscriptions, message)
  end
  
  # Send custom notification
  def self.send_custom(user_id, title, body, url = "/random")
    subscriptions = get_user_subscriptions(user_id)
    return if subscriptions.empty?
    
    message = { title: title, body: body, url: url }
    send_to_subscriptions(subscriptions, message)
  end
  
  private
  
  # Get all active subscriptions for a user
  def self.get_user_subscriptions(user_id)
    DB.execute(
      "SELECT subscription_data FROM push_subscriptions WHERE user_id = ?",
      [user_id]
    ).map do |row|
      data = row["subscription_data"]
      # Handle both string and already-parsed JSON
      data.is_a?(String) ? JSON.parse(data) : data
    end
  rescue => e
    puts "❌ Error fetching subscriptions: #{e.message}"
    []
  end
  
  # Send message to all user subscriptions
  def self.send_to_subscriptions(subscriptions, message)
    successful = 0
    failed = 0
    
    subscriptions.each do |subscription|
      begin
        WebPush.payload_send(
          message: message.to_json,
          endpoint: subscription["endpoint"],
          p256dh: subscription["keys"]["p256dh"],
          auth: subscription["keys"]["auth"],
          vapid: {
            subject: ENV['VAPID_SUBJECT'] || 'mailto:support@memeexplorer.com',
            public_key: ENV['VAPID_PUBLIC_KEY'],
            private_key: ENV['VAPID_PRIVATE_KEY']
          },
          ttl: 24 * 60 * 60 # 24 hours
        )
        successful += 1
      rescue WebPush::InvalidSubscription => e
        puts "⚠️  Invalid subscription, should clean up: #{e.message}"
        failed += 1
        # TODO: Remove invalid subscription from database
      rescue => e
        puts "❌ Push send error: #{e.message}"
        failed += 1
      end
    end
    
    puts "✅ Push notifications sent: #{successful} successful, #{failed} failed" if successful > 0 || failed > 0
    { successful: successful, failed: failed }
  end
end
