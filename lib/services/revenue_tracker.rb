# frozen_string_literal: true

# Revenue tracking service for monitoring monetization
class RevenueTracker
  class << self
    def record_ad_impression(user_id: nil, page: nil)
      DB[:ad_impressions].insert(
        user_id: user_id,
        page: page,
        created_at: Time.now
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
      return 0 unless DB.table_exists?(:users) && DB[:users].columns.include?(:premium_until)
      
      DB[:users]
        .where('premium_until > ?', Time.now)
        .count * 2.99 # Assuming $2.99/month
    end
    
    def weekly_trend
      (0..6).map do |days_ago|
        date = Date.today - days_ago
        daily_stats(date: date).merge(date: date)
      end.reverse
    end
    
    def ad_frequency_stats(since: Time.now - 86400)
      return {} unless DB.table_exists?(:ad_impressions)
      
      impressions = DB[:ad_impressions]
        .where('created_at > ?', since)
        .count
      
      users = DB[:ad_impressions]
        .where('created_at > ?', since)
        .select(:user_id)
        .distinct
        .count
      
      {
        total_impressions: impressions,
        unique_users: users,
        impressions_per_user: users > 0 ? (impressions.to_f / users).round(2) : 0
      }
    end
    
    private
    
    def count_ad_impressions(date)
      return 0 unless DB.table_exists?(:ad_impressions)
      
      DB[:ad_impressions]
        .where(Sequel.lit("DATE(created_at) = ?", date))
        .count
    end
    
    def count_active_users(date)
      return 0 unless DB.table_exists?(:users) && DB[:users].columns.include?(:last_seen)
      
      DB[:users]
        .where(Sequel.lit("DATE(last_seen) = ?", date))
        .count
    end
    
    def count_premium_users(date)
      return 0 unless DB.table_exists?(:users) && DB[:users].columns.include?(:premium_until)
      
      DB[:users]
        .where('premium_until > ?', date.to_time)
        .count
    end
    
    def estimate_daily_revenue(date)
      impressions = count_ad_impressions(date)
      premium_users = count_premium_users(date)
      
      # Rough estimates
      ad_revenue = (impressions * 0.002) # $2 CPM
      premium_revenue = (premium_users * 2.99 / 30) # Daily from monthly
      
      ad_revenue + premium_revenue
    end
  end
end
