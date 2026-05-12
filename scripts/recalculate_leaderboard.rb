#!/usr/bin/env ruby
# Recalculate Leaderboard Script
# Purpose: Manually recalculate all leaderboard entries to ensure accuracy
# Run: ruby scripts/recalculate_leaderboard.rb

require_relative '../app'

puts "🏆 Starting Leaderboard Recalculation"
puts "=" * 60

# Get current periods
current_week = Time.now.strftime('%Y%U').to_i
current_month = Time.now.strftime('%Y%m').to_i

puts "Current Week: #{current_week}"
puts "Current Month: #{current_month}"
puts ""

# ============================================
# 1. RECALCULATE WEEKLY LEADERBOARD
# ============================================
puts "📅 Recalculating Weekly Leaderboard..."

# Get all users with XP
users = DB.execute("SELECT user_id, total_xp FROM user_levels WHERE total_xp > 0")
puts "Found #{users.length} users with XP"

weekly_updates = 0
users.each do |user|
  user_id = user['user_id']
  total_xp = user['total_xp']
  
  # Insert or update weekly leaderboard
  DB.execute(
    "INSERT INTO weekly_leaderboard (user_id, week_number, metric_value, updated_at) 
     VALUES (?, ?, ?, CURRENT_TIMESTAMP)
     ON CONFLICT(user_id, week_number) 
     DO UPDATE SET 
       metric_value = excluded.metric_value,
       updated_at = CURRENT_TIMESTAMP",
    [user_id, current_week, total_xp]
  )
  weekly_updates += 1
  print "." if weekly_updates % 10 == 0
end

puts "\n✅ Updated #{weekly_updates} weekly leaderboard entries"

# Recalculate weekly ranks
puts "Recalculating weekly ranks..."
DB.execute("
  UPDATE weekly_leaderboard
  SET rank = (
    SELECT COUNT(*) + 1
    FROM weekly_leaderboard w2
    WHERE w2.week_number = weekly_leaderboard.week_number
    AND w2.metric_value > weekly_leaderboard.metric_value
  )
  WHERE week_number = ?
", [current_week])

puts "✅ Weekly ranks recalculated"
puts ""

# ============================================
# 2. RECALCULATE MONTHLY LEADERBOARD
# ============================================
puts "📆 Recalculating Monthly Leaderboard..."

begin
  monthly_updates = 0
  users.each do |user|
    user_id = user['user_id']
    total_xp = user['total_xp']
    
    # Insert or update monthly leaderboard
    DB.execute(
      "INSERT INTO monthly_leaderboard (user_id, month_number, total_xp, updated_at) 
       VALUES (?, ?, ?, CURRENT_TIMESTAMP)
       ON CONFLICT(user_id, month_number) 
       DO UPDATE SET 
         total_xp = excluded.total_xp,
         updated_at = CURRENT_TIMESTAMP",
      [user_id, current_month, total_xp]
    )
    monthly_updates += 1
    print "." if monthly_updates % 10 == 0
  end

  puts "\n✅ Updated #{monthly_updates} monthly leaderboard entries"

  # Recalculate monthly ranks
  puts "Recalculating monthly ranks..."
  DB.execute("
    UPDATE monthly_leaderboard
    SET rank = (
      SELECT COUNT(*) + 1
      FROM monthly_leaderboard m2
      WHERE m2.month_number = monthly_leaderboard.month_number
      AND m2.total_xp > monthly_leaderboard.total_xp
    )
    WHERE month_number = ?
  ", [current_month])

  puts "✅ Monthly ranks recalculated"
rescue SQLite3::SQLException => e
  puts "⚠️  Monthly leaderboard table not found - run migration:"
  puts "   sqlite3 memes.db < db/migrations/enhance_leaderboard_system.sql"
end
puts ""

# ============================================
# 3. CLEAR CACHE
# ============================================
puts "🔄 Clearing leaderboard cache..."

begin
  if defined?(MEME_CACHE)
    # Clear all leaderboard cache keys
    MEME_CACHE.delete_matched('leaderboard:*')
    puts "✅ Cache cleared"
  else
    puts "⚠️  Cache not available (running outside Rails context)"
  end
rescue => e
  puts "⚠️  Cache clearing failed: #{e.message}"
end

puts ""

# ============================================
# 4. SHOW TOP 10 RESULTS
# ============================================
puts "=" * 60
puts "🏆 TOP 10 WEEKLY LEADERBOARD"
puts "=" * 60

top_10_weekly = DB.execute("
  SELECT 
    wl.rank,
    wl.user_id,
    wl.metric_value,
    u.reddit_username,
    u.email
  FROM weekly_leaderboard wl
  JOIN users u ON wl.user_id = u.id
  WHERE wl.week_number = ?
  ORDER BY wl.rank ASC
  LIMIT 10
", [current_week])

if top_10_weekly.any?
  top_10_weekly.each do |entry|
    username = entry['reddit_username'] || entry['email']&.split('@')&.first || "User ##{entry['user_id']}"
    puts "#{entry['rank']}. #{username} - #{entry['metric_value']} XP"
  end
else
  puts "No entries found"
end

puts ""
puts "=" * 60
puts "🏆 TOP 10 MONTHLY LEADERBOARD"
puts "=" * 60

begin
  top_10_monthly = DB.execute("
    SELECT 
      ml.rank,
      ml.user_id,
      ml.total_xp,
      u.reddit_username,
      u.email
    FROM monthly_leaderboard ml
    JOIN users u ON ml.user_id = u.id
    WHERE ml.month_number = ?
    ORDER BY ml.rank ASC
    LIMIT 10
  ", [current_month])

  if top_10_monthly.any?
    top_10_monthly.each do |entry|
      username = entry['reddit_username'] || entry['email']&.split('@')&.first || "User ##{entry['user_id']}"
      puts "#{entry['rank']}. #{username} - #{entry['total_xp']} XP"
    end
  else
    puts "No entries found"
  end
rescue SQLite3::SQLException => e
  puts "⚠️  Table not found - run migration first"
end

puts ""
puts "=" * 60
puts "✅ LEADERBOARD RECALCULATION COMPLETE"
puts "=" * 60
puts ""
puts "Next steps:"
puts "1. Visit /leaderboard to verify the changes"
puts "2. The background worker will keep it updated going forward"
puts ""
