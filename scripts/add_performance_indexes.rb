#!/usr/bin/env ruby
# Add Performance Indexes Script
# Run this to apply performance indexes from audit

require 'sqlite3'
require 'pg'

puts "🔧 Adding Performance Indexes..."
puts "================================"

# Determine which database to use
db_path = ENV['DATABASE_URL'] || 'memes.db'

if db_path.start_with?('postgres')
  puts "📊 Detected PostgreSQL database"
  require 'pg'
  
  begin
    db = PG.connect(db_path)
    
    # Read and execute migration
    sql = File.read(File.join(__dir__, '../db/migrations/add_performance_indexes.sql'))
    
    # Execute each statement
    sql.split(';').each do |statement|
      next if statement.strip.empty? || statement.strip.start_with?('--')
      
      begin
        db.exec(statement)
        puts "✅ Executed: #{statement.strip[0..60]}..."
      rescue => e
        puts "⚠️  Warning: #{e.message}"
      end
    end
    
    db.close
    puts "\n✅ PostgreSQL indexes added successfully!"
    
  rescue => e
    puts "❌ Error: #{e.message}"
    exit 1
  end
  
else
  puts "📊 Detected SQLite database"
  
  begin
    db = SQLite3::Database.new(db_path)
    
    # SQLite-compatible version
    indexes = [
      "CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_user_meme ON user_meme_exposure(user_id, meme_url)",
      "CREATE INDEX IF NOT EXISTS idx_user_streaks_user_date ON user_streaks(user_id, last_visit_date)",
      "CREATE INDEX IF NOT EXISTS idx_saved_memes_user_saved ON saved_memes(user_id, saved_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_meme_stats_trending ON meme_stats((likes * 2 + views) DESC)",
      "CREATE INDEX IF NOT EXISTS idx_meme_stats_fresh ON meme_stats(updated_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_liked ON user_meme_stats(user_id, liked, liked_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_broken_images_cleanup ON broken_images(failure_count, first_failed_at)",
      "CREATE INDEX IF NOT EXISTS idx_weekly_leaderboard_week_rank ON weekly_leaderboard(week_number, rank)"
    ]
    
    indexes.each do |sql|
      begin
        db.execute(sql)
        puts "✅ Created index: #{sql[0..60]}..."
      rescue => e
        puts "⚠️  Warning: #{e.message}"
      end
    end
    
    # Analyze for query optimization
    db.execute("ANALYZE")
    
    db.close
    puts "\n✅ SQLite indexes added successfully!"
    
  rescue => e
    puts "❌ Error: #{e.message}"
    exit 1
  end
end

puts "\n📊 Performance indexes complete!"
puts "   Query performance should improve significantly."
