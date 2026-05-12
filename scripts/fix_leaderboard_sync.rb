#!/usr/bin/env ruby
# Fix Leaderboard Synchronization
# Recalculates leaderboard scores from user_levels table
# Run this after XP is awarded to sync leaderboard

require_relative '../db/setup'
require 'date'

puts "🔄 Starting leaderboard synchronization..."

begin
  # Get current week and month
  current_week = Time.now.strftime('%Y%U').to_i
  current_month = Time.now.strftime('%Y%m').to_i
  
  puts "📅 Current Week: #{current_week}"
  puts "📅 Current Month: #{current_month}"
  
  # Get all users with XP
  users = DB.execute("SELECT user_id, total_xp FROM user_levels WHERE total_xp > 0")
  
  puts "👥 Found #{users.size} users with XP"
  
  # Clear existing leaderboard entries for current period
  DB.execute("DELETE FROM weekly_leaderboard WHERE week_number = ?", [current_week])
  DB.execute("DELETE FROM monthly_leaderboard WHERE month_number = ?", [current_month]) rescue nil
  
  puts "🗑️  Cleared existing leaderboard entries"
  
  # Populate weekly leaderboard
  users.each do |user|
    user_id = user['user_id']
    total_xp = user['total_xp']
    
    DB.execute(
      "INSERT INTO weekly_leaderboard (user_id, week_number, metric_value, updated_at) 
       VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
      [user_id, current_week, total_xp]
    )
  end
  
  puts "✅ Populated weekly leaderboard with #{users.size} users"
  
  # Recalculate ranks
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
  
  puts "🏆 Recalculated ranks"
  
  # Show top 10
  top_10 = DB.execute("
    SELECT wl.rank, wl.user_id, wl.metric_value, u.reddit_username, u.email
    FROM weekly_leaderboard wl
    JOIN users u ON wl.user_id = u.id
    WHERE wl.week_number = ?
    ORDER BY wl.rank ASC
    LIMIT 10
  ", [current_week])
  
  puts "\n🏆 TOP 10 LEADERBOARD:"
  puts "=" * 60
  top_10.each do |entry|
    username = entry['reddit_username'] || entry['email'] || "User #{entry['user_id']}"
    puts "#{entry['rank']}. #{username} - #{entry['metric_value']} XP"
  end
  
  puts "\n✅ Leaderboard synchronization complete!"
  puts "🔄 Restart your server to see the updated leaderboard"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
