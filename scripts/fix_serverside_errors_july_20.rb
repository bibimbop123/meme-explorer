#!/usr/bin/env ruby
# Server-Side Production Error Fixes - July 20, 2026
# Fixes 3 critical production errors:
# 1. AdminCheck DBWrapper error
# 2. PostgreSQL "shown_count" ambiguous column
# 3. Milestone achievement_data column missing

require_relative '../config/application'

puts "🔧 Fixing 3 Critical Server-Side Errors..."
puts "=" * 60

# ============================================================
# ERROR 1: AdminCheck - DBWrapper method error
# ============================================================
puts "\n1️⃣  Fixing AdminCheck DBWrapper Error..."

app_helpers_path = 'lib/helpers/app_helpers.rb'
content = File.read(app_helpers_path)

# Fix the is_admin? method to properly use DBWrapper
fixed_content = content.gsub(
  /def is_admin\?\(user_id\)\s+return false unless user_id\s+result = DB\["SELECT role FROM users WHERE id = \?", user_id\]\s+result\[:role\] == 'admin'\s+rescue => e/m,
  <<~RUBY.chomp
  def is_admin?(user_id)
    return false unless user_id
    result = DB.execute("SELECT role FROM users WHERE id = ?", [user_id])
    return false if result.nil? || result.empty?
    result.first['role'] == 'admin'
  rescue => e
  RUBY
)

File.write(app_helpers_path, fixed_content)
puts "   ✅ Fixed is_admin? to use DB.execute properly"

# ============================================================
# ERROR 2: PostgreSQL shown_count ambiguous column
# ============================================================
puts "\n2️⃣  Fixing PostgreSQL 'shown_count' Ambiguous Column..."

analytics_path = 'lib/helpers/analytics_tracking.rb'
content = File.read(analytics_path)

# Fix the ambiguous column reference with proper table alias
fixed_content = content.gsub(
  'shown_count = shown_count + 1,',
  'shown_count = user_meme_exposure.shown_count + 1,'
)

File.write(analytics_path, fixed_content)
puts "   ✅ Fixed analytics_tracking.rb"

# Also fix all other files with the same issue
files_to_fix = [
  'routes/home.rb',
  'routes/random_meme.rb',
  'lib/helpers/meme_navigation_helpers.rb',
  'lib/helpers/meme_helpers.rb'
]

files_to_fix.each do |file|
  next unless File.exist?(file)
  content = File.read(file)
  if content.include?('shown_count = shown_count + 1')
    fixed = content.gsub(
      'shown_count = shown_count + 1,',
      'shown_count = user_meme_exposure.shown_count + 1,'
    )
    File.write(file, fixed)
    puts "   ✅ Fixed #{file}"
  end
end

# ============================================================
# ERROR 3: Milestone achievement_data column missing
# ============================================================
puts "\n3️⃣  Fixing Milestone Service achievement_data Column..."

milestone_path = 'lib/services/milestone_service.rb'
content = File.read(milestone_path)

# Fix the milestone award method to match PostgreSQL schema
fixed_content = content.gsub(
  /"INSERT INTO user_achievements \(user_id, achievement_type, achievement_data, earned_at\) VALUES \(\?, \?, \?, \?\)",\s+\[user_id, 'milestone', milestone_data\.to_json, Time\.now\]/m,
  <<~RUBY.chomp
  "INSERT INTO user_achievements (user_id, achievement_type, earned_at) VALUES (?, ?, ?)",
            [user_id, 'milestone', Time.now]
  RUBY
)

# Also fix the retrieval query
fixed_content = fixed_content.gsub(
  /"SELECT achievement_data, earned_at FROM user_achievements WHERE user_id = \? AND achievement_type = 'milestone' ORDER BY earned_at DESC",/,
  '"SELECT earned_at FROM user_achievements WHERE user_id = ? AND achievement_type = \'milestone\' ORDER BY earned_at DESC",'
)

# Fix the data mapping
fixed_content = fixed_content.gsub(
  /data = JSON\.parse\(row\['achievement_data'\]\)\s+data\['earned_at'\] = row\['earned_at'\]\s+data/m,
  <<~RUBY.chomp
  {
            'earned_at' => row['earned_at'],
            'milestone' => milestone
          }
  RUBY
)

File.write(milestone_path, fixed_content)
puts "   ✅ Fixed milestone_service.rb to match PostgreSQL schema"

puts "\n" + "=" * 60
puts "✅ ALL 3 SERVER-SIDE ERRORS FIXED!"
puts "=" * 60
puts "\n📋 Summary:"
puts "   1. ✅ AdminCheck DBWrapper - Fixed DB.execute usage"
puts "   2. ✅ shown_count ambiguous - Added table alias"
puts "   3. ✅ achievement_data - Removed non-existent column"
puts "\n🚀 Deploy with: git add . && git commit -m 'Fix 3 server-side errors' && git push"
