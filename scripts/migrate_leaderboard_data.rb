#!/usr/bin/env ruby
# Migrate old weekly_leaderboard data to new LeaderboardService system

require_relative '../db/setup'
require_relative '../lib/services/leaderboard_service'

puts "🔄 Migrating weekly_leaderboard data to new system..."

# Get all existing weekly leaderboard entries
old_entries = DB.execute("SELECT * FROM weekly_leaderboard ORDER BY week_number DESC, rank ASC")

puts "Found #{old_entries.size} entries to migrate"

migrated = 0
old_entries.each do |entry|
  # Convert to new format
  period_id = entry['week_number']  # e.g., 202619
  user_id = entry['user_id']
  score = entry['metric_value']
  
  # Insert into new system
  DB.execute(
    "INSERT OR IGNORE INTO leaderboard_rankings 
     (user_id, leaderboard_type, period_id, total_score, rank, created_at, updated_at)
     VALUES (?, 'weekly', ?, ?, ?, datetime('now'), datetime('now'))",
    [user_id, period_id, score, entry['rank']]
  )
  
  migrated += 1
rescue => e
  puts "⚠️ Error migrating entry: #{e.message}"
  puts "  Entry: #{entry.inspect}"
end

puts "✅ Migrated #{migrated} entries to new system"

# Initialize config
begin
  DB.execute(
    "INSERT OR IGNORE INTO leaderboard_config (leaderboard_type, setting_key, setting_value)
     VALUES 
     ('weekly', 'activity_weights', '{\"view\":1,\"like\":5,\"save\":10,\"share\":15,\"streak\":50}'),
     ('monthly', 'activity_weights', '{\"view\":1,\"like\":5,\"save\":10,\"share\":15,\"streak\":50}'),
     ('all_time', 'activity_weights', '{\"view\":1,\"like\":5,\"save\":10,\"share\":15,\"streak\":50}')"
  )
  puts "✅ Leaderboard config initialized"
rescue => e
  puts "⚠️ Config initialization skipped (may already exist): #{e.message}"
end

puts "\n✅ Leaderboard migration complete!"
puts "Next step: Run 'ruby scripts/calculate_leaderboard_scores.rb' to calculate scores"
