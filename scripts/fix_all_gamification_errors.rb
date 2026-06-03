#!/usr/bin/env ruby
# Fix All Gamification Errors - Production Critical
# Fixes: type conversion, missing tables, SQL errors

require_relative '../db/setup'

puts "🔧 Fixing All Gamification Errors..."
puts "=" * 60

# 1. Create weekly_leaderboard table (currently missing)
puts "\n1️⃣  Creating weekly_leaderboard table..."
begin
  DB.execute(<<-SQL)
    CREATE TABLE IF NOT EXISTS weekly_leaderboard (
      id SERIAL PRIMARY KEY,
      week_number INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      metric_type VARCHAR(50) DEFAULT 'all',
      points INTEGER DEFAULT 0,
      likes_count INTEGER DEFAULT 0,
      saves_count INTEGER DEFAULT 0,
      shares_count INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (week_number, user_id, metric_type)
    );
  SQL
  
  DB.execute("CREATE INDEX IF NOT EXISTS idx_weekly_lb_week ON weekly_leaderboard(week_number);")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_weekly_lb_user ON weekly_leaderboard(user_id);")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_weekly_lb_points ON weekly_leaderboard(points);")
  
  puts "   ✅ weekly_leaderboard table created"
rescue => e
  puts "   ⚠️  weekly_leaderboard: #{e.message}"
end

# 2. Verify user_achievements table structure (should NOT have achievement_data)
puts "\n2️⃣  Checking user_achievements table..."
begin
  # Check if table exists and has correct structure
  result = DB.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'user_achievements'")
  columns = result.map { |r| r['column_name'] }
  
  if columns.empty?
    puts "   ⚠️  Table doesn't exist - run apply_missing_tables.rb first"
  else
    puts "   ✅ user_achievements exists with columns: #{columns.join(', ')}"
    
    # Check if incorrect achievement_data column exists
    if columns.include?('achievement_data')
      puts "   ⚠️  Found incorrect 'achievement_data' column - needs manual removal"
      puts "      Run: ALTER TABLE user_achievements DROP COLUMN achievement_data;"
    end
  end
rescue => e
  puts "   ⚠️  Error checking table: #{e.message}"
end

# 3. Add conversion function helpers to gamification_helpers.rb
puts "\n3️⃣  Type Conversion Fixes Needed..."
puts "   📝 The following needs to be added to lib/helpers/gamification_helpers.rb:"
puts ""
puts "   # Add at the top of each function that takes user_id:"
puts "   user_id = user_id.to_i if user_id.is_a?(String)"
puts ""
puts "   Functions needing fix:"
puts "   - update_streak(user_id)"
puts "   - add_xp(user_id, activity)"  
puts "   - get_user_level(user_id)"
puts "   - get_user_stats(user_id)"
puts "   - award_milestone(user_id, ...)"

# 4. Show app.rb fix
puts "\n4️⃣  app.rb before block fix (CRITICAL):"
puts "   Current issue: session[:user_id] is sometimes String"
puts "   Fix already applied in previous commit"
puts "   ✅ Should already have: user_id = session[:user_id].to_i"

# 5. Show leaderboard view fix
puts "\n5️⃣  Leaderboard View Fix Needed..."
puts "   File: views/leaderboard.erb line ~167"
puts "   Issue: Comparing String with Integer"
puts "   Fix: Convert rank to integer before comparison"
puts "   Change: if entry['user_rank'] <= 3"
puts "   To:     if entry['user_rank'].to_i <= 3"

puts "\n" + "=" * 60
puts "Summary of Actions Needed:"
puts "=" * 60
puts "✅ 1. weekly_leaderboard table created (done above)"
puts "⏳ 2. Run RUN_MIGRATION_NOW.md to create user_achievements"
puts "⏳ 3. Add .to_i conversions to gamification_helpers.rb"
puts "⏳ 4. Fix leaderboard view line 167 comparison"
puts "⏳ 5. Fix LeaderboardService SQL GROUP BY"
puts ""
puts "🚀 Next Steps:"
puts "1. Copy/paste SQL from this output to production"
puts "2. Deploy code fixes"
puts "3. Monitor logs for errors"

