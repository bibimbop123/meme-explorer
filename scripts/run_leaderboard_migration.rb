#!/usr/bin/env ruby
# Quick script to run leaderboard migrations
# Usage: ruby scripts/run_leaderboard_migration.rb

require 'sqlite3'

DB_PATH = 'memes.db'
MIGRATION_PATH = 'db/migrations/enhance_leaderboard_system.sql'

puts "🔄 Running leaderboard enhancement migrations..."
puts "Database: #{DB_PATH}"
puts "Migration: #{MIGRATION_PATH}"

begin
  # Read migration SQL
  sql = File.read(MIGRATION_PATH)
  
  # Connect to database
  db = SQLite3::Database.new(DB_PATH)
  db.results_as_hash = true
  
  # Execute migration
  puts "\n📋 Executing migration..."
  db.execute_batch(sql)
  
  puts "✅ Migration completed successfully!"
  puts "\n📊 Verifying tables..."
  
  # Verify tables were created
  tables_to_check = [
    'monthly_leaderboard',
    'category_leaderboard', 
    'achievements_log',
    'user_friendships',
    'user_challenges',
    'rank_change_history',
    'leaderboard_notifications',
    'leaderboard_snapshots'
  ]
  
  tables_to_check.each do |table|
    count = db.get_first_value("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?", [table])
    if count && count > 0
      puts "  ✓ #{table}"
    else
      puts "  ✗ #{table} - NOT FOUND"
    end
  end
  
  puts "\n🎉 Leaderboard enhancement complete!"
  puts "\nYou can now:"
  puts "  1. Restart your server"
  puts "  2. Visit /leaderboard"
  puts "  3. Try different types: ?type=monthly, ?type=all_time, ?type=streak"
  
rescue SQLite3::Exception => e
  puts "❌ Database error: #{e.message}"
  puts "\nTroubleshooting:"
  puts "  1. Make sure memes.db exists in the root directory"
  puts "  2. Check that the migration file exists: #{MIGRATION_PATH}"
  puts "  3. Ensure the database isn't locked by another process"
  exit 1
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
ensure
  db&.close
end
