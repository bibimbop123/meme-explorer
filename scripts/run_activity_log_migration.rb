#!/usr/bin/env ruby
# Run activity log migration for accurate time-based metrics

require_relative '../app'

puts "🔧 Starting meme_activity_log migration..."

begin
  # Read and execute migration
  migration_sql = File.read(File.join(__dir__, '..', 'db', 'migrations', 'add_meme_activity_log.sql'))
  
  DB.execute_batch(migration_sql)
  
  puts "✅ Migration completed successfully!"
  puts ""
  puts "📊 Verifying tables..."
  
  # Verify table exists
  result = DB.execute("SELECT COUNT(*) as count FROM information_schema.tables WHERE table_name = 'meme_activity_log'")
  if result.first['count'] > 0
    puts "  ✓ meme_activity_log table created"
  else
    puts "  ✗ meme_activity_log table NOT found"
  end
  
  # Check indexes
  indexes = DB.execute("SELECT indexname FROM pg_indexes WHERE tablename = 'meme_activity_log'")
  puts "  ✓ Created #{indexes.length} indexes on meme_activity_log"
  
  # Check meme_stats schema update
  columns = DB.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'meme_stats' AND column_name = 'created_at'")
  if columns.length > 0
    puts "  ✓ created_at column added to meme_stats"
  else
    puts "  ✗ created_at column NOT found in meme_stats"
  end
  
  puts ""
  puts "🎉 Migration complete! Time-based metrics will now be accurate."
  puts ""
  puts "📝 Next steps:"
  puts "  1. Restart your server to load updated code"
  puts "  2. Visit /metrics to see accurate time-based filtering"
  puts "  3. New views/likes will be logged to activity table"
  
rescue => e
  puts "❌ Migration failed: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
