# Premium Service - Handles premium subscription logic
class PremiumService
  MONTHLY_PRICE_CENTS = 299  # $2.99
  YEARLY_PRICE_CENTS = 2999  # $29.99
  
  # Check if a username has an active premium subscription
  def self.is_premium?(username)
    return false unless username
    
    begin
      db = DBWrapper.new
      result = db.execute(
        "SELECT id, status, expires_at FROM premium_subscriptions 
         WHERE reddit_username = ? 
         AND status = 'active' 
         AND (expires_at IS NULL OR expires_at > ?)
         LIMIT 1",
        [username, Time.now.to_i]
      )
      
      !result.empty?
    rescue => e
      AppLogger.error("Error checking premium status for #{username}: #{e.message}")
      false
    ensure
      db&.close
    end
  end
  
  # Get subscription details for a username
  def self.get_subscription(username)
    return nil unless username
    
    begin
      db = DBWrapper.new
      result = db.execute(
        "SELECT * FROM premium_subscriptions 
         WHERE reddit_username = ? 
         AND status = 'active'
         ORDER BY created_at DESC 
         LIMIT 1",
        [username]
      )
      
      return nil if result.empty?
      
      row = result.first
      {
        id: row['id'],
        plan: row['plan_type'],
        status: row['status'],
        stripe_subscription_id: row['stripe_subscription_id'],
        current_period_end: row['current_period_end'],
        expires_at: row['expires_at'],
        created_at: row['created_at']
      }
    rescue => e
      AppLogger.error("Error getting subscription for #{username}: #{e.message}")
      nil
    ensure
      db&.close
    end
  end
  
  # Create a new premium subscription
  def self.create_subscription(username, plan_type, stripe_subscription_id, stripe_customer_id)
    begin
      db = DBWrapper.new
      
      expires_at = if plan_type == 'monthly'
        Time.now.to_i + (30 * 24 * 60 * 60)  # 30 days
      else
        Time.now.to_i + (365 * 24 * 60 * 60)  # 365 days
      end
      
      db.execute(
        "INSERT INTO premium_subscriptions 
         (reddit_username, plan_type, status, stripe_subscription_id, stripe_customer_id, 
          current_period_end, expires_at, created_at, updated_at)
         VALUES (?, ?, 'active', ?, ?, ?, ?, ?, ?)",
        [username, plan_type, stripe_subscription_id, stripe_customer_id,
         expires_at, expires_at, Time.now.to_i, Time.now.to_i]
      )
      
      AppLogger.info("✅ Created #{plan_type} subscription for #{username}")
      true
    rescue => e
      AppLogger.error("Error creating subscription for #{username}: #{e.message}")
      false
    ensure
      db&.close
    end
  end
  
  # Cancel a subscription
  def self.cancel_subscription(username)
    begin
      db = DBWrapper.new
      db.execute(
        "UPDATE premium_subscriptions 
         SET status = 'cancelled', cancel_at_period_end = 1, updated_at = ?
         WHERE reddit_username = ? AND status = 'active'",
        [Time.now.to_i, username]
      )
      
      AppLogger.info("✅ Cancelled subscription for #{username}")
      true
    rescue => e
      AppLogger.error("Error cancelling subscription for #{username}: #{e.message}")
      false
    ensure
      db&.close
    end
  end
  
  # Get pricing info
  def self.pricing
    {
      monthly: {
        price_cents: MONTHLY_PRICE_CENTS,
        price_display: "$2.99",
        period: "month"
      },
      yearly: {
        price_cents: YEARLY_PRICE_CENTS,
        price_display: "$29.99",
        period: "year",
        savings: "Save $6 per year!"
      }
    }
  end
end
