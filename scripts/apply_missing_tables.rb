#!/usr/bin/env ruby
# Apply Missing Tables Migration
# Run this on production to create meme_activity_log and user_achievements tables

require_relative '../db/setup'

puts "🔧 Applying Missing Tables Migration..."
puts "Database: #{ENV['DATABASE_URL'] ? 'PostgreSQL (Production)' : 'SQLite (Development)'}"

migration_sql = File.read(File.join(__DIR__, '../db/migrations/create_missing_tables_postgresql.sql'))

# PostgreSQL doesn't support CREATE INDEX inside CREATE TABLE
# So we need to modify the SQL for PostgreSQL
if ENV['DATABASE_URL']  # PostgreSQL
  puts "📊 Creating tables for PostgreSQL..."
  
  # Create meme_activity_log
  begin
    DB.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS meme_activity_log (
        id SERIAL PRIMARY KEY,
        meme_url VARCHAR(500) NOT NULL,
        activity_type VARCHAR(50) NOT NULL,
        user_id INTEGER,
        session_id VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    SQL
    puts "✅ Created meme_activity_log table"
    
    # Create indexes separately for PostgreSQL
    DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_activity_url ON meme_activity_log(meme_url);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_activity_user ON meme_activity_log(user_id);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_activity_type ON meme_activity_log(activity_type);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_activity_created ON meme_activity_log(created_at);")
    puts "✅ Created indexes for meme_activity_log"
  rescue => e
    puts "⚠️  meme_activity_log error: #{e.message}"
  end
  
  # Create user_achievements
  begin
    DB.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS user_achievements (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        achievement_type VARCHAR(100) NOT NULL,
        achievement_name VARCHAR(200) NOT NULL,
        achievement_description TEXT,
        xp_awarded INTEGER DEFAULT 0,
        awarded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, achievement_type, achievement_name)
      );
    SQL
    puts "✅ Created user_achievements table"
    
    # Create indexes separately for PostgreSQL
    DB.execute("CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_user_achievements_type ON user_achievements(achievement_type);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_user_achievements_awarded ON user_achievements(awarded_at);")
    puts "✅ Created indexes for user_achievements"
  rescue => e
    puts "⚠️  user_achievements error: #{e.message}"
  end
  
  puts "🎉 PostgreSQL migration complete!"
  
else  # SQLite
  puts "📊 Creating tables for SQLite..."
  
  # SQLite version
  begin
    DB.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS meme_activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meme_url VARCHAR(500) NOT NULL,
        activity_type VARCHAR(50) NOT NULL,
        user_id INTEGER,
        session_id VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    SQL
    
    DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_activity_url ON meme_activity_log(meme_url);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_activity_user ON meme_activity_log(user_id);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_activity_type ON meme_activity_log(activity_type);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_activity_created ON meme_activity_log(created_at);")
    puts "✅ Created meme_activity_log table"
  rescue => e
    puts "⚠️  meme_activity_log error: #{e.message}"
  end
  
  begin
    DB.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS user_achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        achievement_type VARCHAR(100) NOT NULL,
        achievement_name VARCHAR(200) NOT NULL,
        achievement_description TEXT,
        xp_awarded INTEGER DEFAULT 0,
        awarded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, achievement_type, achievement_name)
      );
    SQL
    
    DB.execute("CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_user_achievements_type ON user_achievements(achievement_type);")
    DB.execute("CREATE INDEX IF NOT EXISTS idx_user_achievements_awarded ON user_achievements(awarded_at);")
    puts "✅ Created user_achievements table"
  rescue => e
    puts "⚠️  user_achievements error: #{e.message}"
  end
  
  puts "🎉 SQLite migration complete!"
end

# Verify tables exist
begin
  count = DB.execute("SELECT COUNT(*) FROM meme_activity_log").first[0]
  puts "✅ Verified meme_activity_log exists (#{count} rows)"
rescue => e
  puts "❌ meme_activity_log verification failed: #{e.message}"
end

begin
  count = DB.execute("SELECT COUNT(*) FROM user_achievements").first[0]
  puts "✅ Verified user_achievements exists (#{count} rows)"
rescue => e
  puts "❌ user_achievements verification failed: #{e.message}"
end

puts "\n🚀 Migration complete! You can now:"
puts "1. Test engagement tracking (likes/saves will log to meme_activity_log)"
puts "2. Test achievement system (milestones will save to user_achievements)"
puts "3. Monitor production logs for any remaining errors"
