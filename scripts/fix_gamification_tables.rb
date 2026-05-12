#!/usr/bin/env ruby
# Fix Gamification Tables Script
# Ensures all gamification tables exist and are properly structured

# Load the app environment
require_relative '../app'

puts "🔧 Fixing Gamification Tables..."
puts "=" * 60

begin
  # Check database type
  db_type = ENV['DATABASE_URL'] ? 'postgresql' : 'sqlite'
  puts "📊 Database type: #{db_type}"
  
  if db_type == 'postgresql'
    # PostgreSQL version
    puts "\n🐘 Creating PostgreSQL tables..."
    
    # User achievements table
    DB.execute <<-SQL
      CREATE TABLE IF NOT EXISTS user_achievements (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        achievement_type VARCHAR(50) NOT NULL,
        achievement_data TEXT NOT NULL,
        earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
    SQL
    puts "✅ user_achievements table ready"
    
    # User XP log table
    DB.execute <<-SQL
      CREATE TABLE IF NOT EXISTS user_xp_log (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        xp_amount INTEGER NOT NULL,
        reason VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
    SQL
    puts "✅ user_xp_log table ready"
    
    # Create indexes
    DB.execute "CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);"
    DB.execute "CREATE INDEX IF NOT EXISTS idx_user_achievements_type ON user_achievements(achievement_type);"
    DB.execute "CREATE INDEX IF NOT EXISTS idx_user_xp_log_user_id ON user_xp_log(user_id);"
    puts "✅ Indexes created"
    
  else
    # SQLite version
    puts "\n💾 Creating SQLite tables..."
    
    # User achievements table
    DB.execute <<-SQL
      CREATE TABLE IF NOT EXISTS user_achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        achievement_type TEXT NOT NULL,
        achievement_data TEXT NOT NULL,
        earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
    SQL
    puts "✅ user_achievements table ready"
    
    # User XP log table
    DB.execute <<-SQL
      CREATE TABLE IF NOT EXISTS user_xp_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        xp_amount INTEGER NOT NULL,
        reason TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
    SQL
    puts "✅ user_xp_log table ready"
    
    # Create indexes
    DB.execute "CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);"
    DB.execute "CREATE INDEX IF NOT EXISTS idx_user_achievements_type ON user_achievements(achievement_type);"
    DB.execute "CREATE INDEX IF NOT EXISTS idx_user_xp_log_user_id ON user_xp_log(user_id);"
    puts "✅ Indexes created"
  end
  
  # Verify tables exist
  puts "\n🔍 Verifying tables..."
  tables = DB.execute("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('user_achievements', 'user_xp_log')").map { |r| r['name'] } rescue []
  
  if db_type == 'postgresql'
    tables = DB.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('user_achievements', 'user_xp_log')").map { |r| r['table_name'] } rescue []
  end
  
  puts "Found tables: #{tables.join(', ')}"
  
  if tables.include?('user_achievements') && tables.include?('user_xp_log')
    puts "\n✅ SUCCESS! All gamification tables are ready!"
  else
    puts "\n⚠️  WARNING: Some tables may be missing"
  end
  
rescue => e
  puts "\n❌ ERROR: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

puts "\n" + "=" * 60
puts "🎮 Gamification tables fixed! Restart your server."
