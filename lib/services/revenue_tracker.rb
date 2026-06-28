# frozen_string_literal: true

# Revenue tracking service for monitoring monetization
class RevenueTracker
  class << self
    def record_ad_impression(user_id: nil, page: nil)
      DB.execute(
        "INSERT INTO ad_impressions (user_id, page, created_at) VALUES (?, ?, ?)",
        [user_id, page, Time.now]
      )
    rescue => e
      AppLogger.debug("Failed to record ad impression: #{e.message}")
    end

    def daily_stats(date: Date.today)
      {
        ad_impressions: count_ad_impressions(date),
        active_users: count_active_users(date),
        premium_users: count_premium_users(date),
        estimated_revenue: estimate_daily_revenue(date)
      }
    end

    def monthly_recurring_revenue
      result = DB.get_first_value(
        "SELECT COUNT(*) FROM users WHERE premium_until > ?", [Time.now]
      ).to_i
      result * 2.99
    rescue => e
      AppLogger.debug("Failed to query MRR: #{e.message}")
      0
    end

    def weekly_trend
      (0..6).map do |days_ago|
        date = Date.today - days_ago
        daily_stats(date: date).merge(date: date)
      end.reverse
    end

    def ad_frequency_stats(since: Time.now - 86400)
      impressions = DB.get_first_value(
        "SELECT COUNT(*) FROM ad_impressions WHERE created_at > ?", [since]
      ).to_i
      users = DB.get_first_value(
        "SELECT COUNT(DISTINCT user_id) FROM ad_impressions WHERE created_at > ?", [since]
      ).to_i
      {
        total_impressions: impressions,
        unique_users: users,
        impressions_per_user: users > 0 ? (impressions.to_f / users).round(2) : 0
      }
    rescue => e
      AppLogger.debug("Failed to query ad frequency stats: #{e.message}")
      {}
    end

    private

    def count_ad_impressions(date)
      DB.get_first_value(
        "SELECT COUNT(*) FROM ad_impressions WHERE DATE(created_at) = ?", [date.to_s]
      ).to_i
    rescue => e
      0
    end

    def count_active_users(date)
      DB.get_first_value(
        "SELECT COUNT(*) FROM users WHERE DATE(last_seen) = ?", [date.to_s]
      ).to_i
    rescue => e
      0
    end

    def count_premium_users(date)
      DB.get_first_value(
        "SELECT COUNT(*) FROM users WHERE premium_until > ?", [date.to_time]
      ).to_i
    rescue => e
      0
    end

    def estimate_daily_revenue(date)
      impressions    = count_ad_impressions(date)
      premium_users  = count_premium_users(date)
      ad_revenue     = impressions * 0.002       # $2 CPM
      premium_revenue = premium_users * 2.99 / 30 # Daily share of monthly
      ad_revenue + premium_revenue
    end
  end
end
