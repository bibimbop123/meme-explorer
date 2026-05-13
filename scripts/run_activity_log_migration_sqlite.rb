#!/usr/bin/env ruby
# Migration runner for SQLite activity log
# This creates the meme_activity_log table for accurate time-based metrics

require_relative '../db/setup'

puts "🔧 Starting meme_activity_log migration (SQLite)..."

begin
  # Read and execute migration
  migration_sql = File.read(File.join(__dir__, '..', 'db', 'migrations', 'add_meme_activity_log_sqlite.sql'))
  
  # Execute each statement separately (SQLite doesn't support multi-statement execution well)
  migration_sql.split(';').each do |statement|
    statement = statement.strip
    next if statement.empty? || statement.start_with?('--')
    
    begin
      DB.execute(statement)
    rescue SQLite3::Exception => e
      # Ignore "duplicate column" or "table already exists" errors
      unless e.message.include?("already exists") || e.message.include?("duplicate column")
        puts "  ⚠️  Warning: #{e.message}"
      end
    end
  end
  
  # Check if created_at column exists in meme_stats
  has_created_at = DB.execute("PRAGMA table_info(meme_stats)").any? { |col| col[1] == 'created_at' }
  
  unless has_created_at
    puts "  Adding created_at column to meme_stats..."
    # SQLite doesn't allow CURRENT_TIMESTAMP in ALTER TABLE, so use NULL then backfill
    DB.execute("ALTER TABLE meme_stats ADD COLUMN created_at DATETIME")
    
    # Backfill with updated_at (or current time if updated_at is NULL)
    DB.execute("UPDATE meme_stats SET created_at = COALESCE(updated_at, CURRENT_TIMESTAMP) WHERE created_at IS NULL")
  end
  
  puts "✅ Migration completed successfully!"
  
  # Verify
  puts "\n📊 Verifying tables..."
  
  tables = DB.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='meme_activity_log'")
  if tables.any?
    puts "  ✓ meme_activity_log table created"
  else
    puts "  ✗ meme_activity_log table NOT found"
    exit 1
  end
  
  indexes = DB.execute("SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_activity_log%'")
  puts "  ✓ Created #{indexes.length} indexes on meme_activity_log"
  
  columns = DB.execute("PRAGMA table_info(meme_stats)")
  if columns.any? { |col| col[1] == 'created_at' }
    puts "  ✓ created_at column added to meme_stats"
  end
  
  puts "\n🎉 Migration complete! Time-based metrics will now be accurate."
  puts "\n📝 Next steps:"
  puts "  1. Restart your server to load updated code"
  puts "  2. Visit /metrics?period=24h to see accurate data"
  puts "  3. Monitor server logs for any issues"
  
rescue => e
  puts "❌ Migration failed: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
