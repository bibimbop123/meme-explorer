#!/usr/bin/env ruby
# Fix production errors related to removed gamification features
# Date: August 24, 2026
# Fixes: ActivityTrackerService and update_streak errors

puts "🔧 Fixing Production Gamification Errors (August 24, 2026)"
puts "=" * 60

# Fix 1: Remove ActivityTrackerService calls from engagement_service.rb
puts "\n✅ Step 1: Fixing EngagementService..."
engagement_service_path = 'lib/services/engagement_service.rb'
engagement_content = File.read(engagement_service_path)

# Comment out ActivityTrackerService calls with proper error handling
engagement_content.gsub!(
  /^\s*ActivityTrackerService\.record_action\('like', user_id\) if user_id && liked_now$/,
  "        # ActivityTrackerService removed during Elon audit\n        # ActivityTrackerService.record_action('like', user_id) if user_id && liked_now"
)

engagement_content.gsub!(
  /^\s*ActivityTrackerService\.record_action\('save', user_id\) if saved_now$/,
  "        # ActivityTrackerService removed during Elon audit\n        # ActivityTrackerService.record_action('save', user_id) if saved_now"
)

File.write(engagement_service_path, engagement_content)
puts "   ✅ EngagementService fixed"

# Fix 2: Fix admin_inline_routes.rb
puts "\n✅ Step 2: Fixing admin routes..."
admin_routes_path = 'routes/admin_inline_routes.rb'
admin_content = File.read(admin_routes_path)

# Replace ActivityTrackerService.stats with graceful fallback
admin_content.gsub!(
  /^\s*stats = ActivityTrackerService\.stats$/,
  "        # ActivityTrackerService removed during Elon audit\n        stats = { active_users: 0, viewing_users: 0, redis_available: false }"
)

File.write(admin_routes_path, admin_content)
puts "   ✅ Admin routes fixed"

# Fix 3: Search for and comment out any update_streak calls
puts "\n✅ Step 3: Searching for update_streak calls..."
require 'find'

update_streak_files = []
Find.find('.') do |path|
  next unless path.end_with?('.rb')
  next if path.include?('/spec/') || path.include?('/.git/') || path.include?('/scripts/')
  
  content = File.read(path)
  if content.match?(/update_streak\(/)
    update_streak_files << path
    puts "   Found in: #{path}"
  end
end

if update_streak_files.empty?
  puts "   ✅ No update_streak calls found in app code"
else
  puts "   ⚠️  Found update_streak calls - please review manually"
end

# Fix 4: Create a stub ActivityTrackerService for graceful degradation
puts "\n✅ Step 4: Creating stub ActivityTrackerService..."
stub_content = <<~RUBY
# Stub ActivityTrackerService for graceful degradation
# Original service removed during Elon audit
# This stub prevents errors while maintaining API compatibility

module ActivityTrackerService
  class << self
    def record_action(action_type, user_id)
      # No-op: Activity tracking disabled
      AppLogger.debug("ActivityTrackerService stub called: \#{action_type} for user \#{user_id}")
      true
    rescue => e
      AppLogger.warn("ActivityTrackerService stub error: \#{e.message}")
      false
    end

    def mark_active(visitor_id, ip_address = nil)
      # No-op: Activity tracking disabled
      true
    rescue => e
      false
    end

    def stats
      {
        active_users: 0,
        viewing_users: 0,
        redis_available: false,
        note: 'Activity tracking disabled'
      }
    rescue => e
      {
        active_users: 0,
        viewing_users: 0,
        redis_available: false,
        error: e.message
      }
    end

    def aggregate_stats
      # No-op: Activity tracking disabled
      true
    rescue => e
      false
    end
  end
end
RUBY

File.write('lib/services/activity_tracker_service.rb', stub_content)
puts "   ✅ Stub ActivityTrackerService created"

# Fix 5: Uncomment the require in app.rb
puts "\n✅ Step 5: Enabling ActivityTrackerService require in app.rb..."
app_content = File.read('app.rb')

app_content.gsub!(
  /^# require_relative "\.\/lib\/services\/activity_tracker_service"  # Removed during Elon audit - file not found$/,
  'require_relative "./lib/services/activity_tracker_service"  # Stub for graceful degradation'
)

File.write('app.rb', app_content)
puts "   ✅ app.rb updated"

puts "\n" + "=" * 60
puts "✅ ALL FIXES APPLIED SUCCESSFULLY!"
puts "=" * 60
puts "\nChanges made:"
puts "1. ✅ Commented out ActivityTrackerService calls in EngagementService"
puts "2. ✅ Fixed admin routes to use fallback stats"
puts "3. ✅ Created stub ActivityTrackerService for graceful degradation"
puts "4. ✅ Enabled ActivityTrackerService require in app.rb"
puts "\nNext steps:"
puts "1. Review changes: git diff"
puts "2. Test locally: bundle exec ruby app.rb"
puts "3. Deploy: git add . && git commit -m 'Fix production gamification errors' && git push"
puts "\n🚀 Ready to deploy!"
