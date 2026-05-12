#!/usr/bin/env ruby
# Migration Script: Create broken_images table
# Run this to add image health tracking to your database

require 'sqlite3'

# Determine database path
DB_PATH = File.exist?('memes.db') ? 'memes.db' : 'db/memes.db'

puts "🔄 [MIGRATION] Running broken_images table migration..."
puts "📂 [MIGRATION] Database: #{DB_PATH}"

begin
  db = SQLite3::Database.new(DB_PATH)
  db.results_as_hash = true
  
  # Read and execute migration SQL
  migration_sql = File.read('db/migrations/add_broken_images_table.sql')
  
  # Execute each statement (SQLite doesn't support multiple statements in one execute)
  migration_sql.split(';').each do |statement|
    next if statement.strip.empty? || statement.strip.start_with?('--')
    
    begin
      db.execute(statement)
      puts "✅ [MIGRATION] Executed: #{statement.strip[0..60]}..."
    rescue SQLite3::Exception => e
      # Ignore "already exists" errors
      if e.message.include?("already exists")
        puts "⚠️  [MIGRATION] Skipping (already exists): #{statement.strip[0..60]}..."
      else
        raise e
      end
    end
  end
  
  # Verify table was created
  tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='broken_images'")
  
  if tables.any?
    puts "✅ [MIGRATION] broken_images table verified"
    
    # Show table structure
    schema = db.execute("PRAGMA table_info(broken_images)")
    puts "\n📋 [MIGRATION] Table structure:"
    schema.each do |col|
      puts "   - #{col['name']} (#{col['type']})"
    end
    
    # Show indexes
    indexes = db.execute("PRAGMA index_list(broken_images)")
    if indexes.any?
      puts "\n📊 [MIGRATION] Indexes:"
      indexes.each do |idx|
        puts "   - #{idx['name']}"
      end
    end
    
    puts "\n🎉 [MIGRATION] Migration completed successfully!"
    puts "💡 [MIGRATION] The ImageHealthService is now ready to track broken images"
  else
    puts "❌ [MIGRATION] Failed to create broken_images table"
    exit 1
  end
  
rescue SQLite3::Exception => e
  puts "❌ [MIGRATION] Database error: #{e.message}"
  exit 1
rescue => e
  puts "❌ [MIGRATION] Error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
ensure
  db&.close
end
