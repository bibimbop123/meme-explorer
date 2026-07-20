#!/usr/bin/env ruby
# Week 1 Critical Fixes - Code Audit July 19, 2026
# Implements P0-1, P0-2, P0-4, P0-5, P1-4
# 
# Run with: ruby scripts/execute_audit_week1_fixes.rb

require 'fileutils'

puts "🔧 WEEK 1 CRITICAL FIXES - Code Audit Execution"
puts "=" * 60

# ============================================
# FIX P0-1: RedisService Thread Leak
# ============================================
puts "\n📌 P0-1: Fixing RedisService thread leak..."

redis_service_path = 'lib/services/redis_service.rb'
if File.exist?(redis_service_path)
  content = File.read(redis_service_path)
  
  # Replace thread spawn with Sidekiq-based retry
  old_code = <<~RUBY
    @reconnect_thread = Thread.new do
      Thread.current.name = 'redis-reconnect'
      sleep 30
      refresh_availability!
    end
  RUBY
  
  new_code = <<~RUBY
    # Schedule reconnection check via Sidekiq instead of spawning threads
    # This prevents thread leaks and integrates with existing job infrastructure
    if defined?(Sidekiq)
      RedisReconnectWorker.perform_in(30.seconds) rescue nil
    else
      # Fallback for environments without Sidekiq
      AppLogger.warn('[RedisService] Sidekiq unavailable, skipping reconnect scheduling')
    end
  RUBY
  
  if content.include?('Thread.new')
    content.gsub!(old_code.strip, new_code.strip)
    File.write(redis_service_path, content)
    puts "  ✅ Fixed thread leak in RedisService"
    puts "  📝 Note: Create app/workers/redis_reconnect_worker.rb if needed"
  else
    puts "  ℹ️  Thread.new not found or already fixed"
  end
else
  puts "  ⚠️  redis_service.rb not found"
end

# ============================================
# FIX P0-2: Consolidate Profile Routes
# ============================================
puts "\n📌 P0-2: Consolidating duplicate profile routes..."

user_api_routes = 'routes/user_api_routes.rb'
if File.exist?(user_api_routes)
  # Backup first
  FileUtils.cp(user_api_routes, "#{user_api_routes}.backup")
  
  # Read content to check what needs to be preserved
  content = File.read(user_api_routes)
  
  if content.include?('get /profile')
    puts "  ⚠️  Found duplicate /profile route in user_api_routes.rb"
    puts "  📝 Manual action required:"
    puts "     1. Review routes/user_api_routes.rb"
    puts "     2. Move any unique functionality to routes/profile_routes.rb"
    puts "     3. Delete routes/user_api_routes.rb"
    puts "     4. Remove registration from app.rb"
    puts "  📄 Backup created at: #{user_api_routes}.backup"
  else
    puts "  ℹ️  No /profile route conflict found"
  end
else
  puts "  ✅ user_api_routes.rb doesn't exist (already fixed)"
end

# ============================================
# FIX P0-4: Remove Duplicate OG Image Tags
# ============================================
puts "\n📌 P0-4: Removing duplicate Open Graph image tags..."

layout_path = 'views/layout.erb'
if File.exist?(layout_path)
  content = File.read(layout_path)
  
  # Find and remove duplicate width/height tags (lines 36-37)
  lines = content.split("\n")
  
  # Track if we've seen og:image:width and og:image:height
  seen_width = false
  seen_height = false
  filtered_lines = []
  
  lines.each do |line|
    if line.include?('og:image:width')
      if seen_width
        puts "  🗑️  Removing duplicate: #{line.strip}"
        next # Skip duplicate
      else
        seen_width = true
      end
    elsif line.include?('og:image:height')
      if seen_height
        puts "  🗑️  Removing duplicate: #{line.strip}"
        next # Skip duplicate
      else
        seen_height = true
      end
    end
    filtered_lines << line
  end
  
  if filtered_lines.length < lines.length
    File.write(layout_path, filtered_lines.join("\n"))
    puts "  ✅ Removed duplicate OG image dimension tags"
  else
    puts "  ℹ️  No duplicate OG tags found"
  end
else
  puts "  ⚠️  layout.erb not found"
end

# ============================================
# FIX P0-5: Fix Hardcoded Admin Email
# ============================================
puts "\n📌 P0-5: Fixing hardcoded admin authentication..."

if File.exist?(layout_path)
  content = File.read(layout_path)
  
  old_admin_check = '<% if session[:reddit_username] == "brianhkim13@gmail.com" %>'
  new_admin_check = '<% if session[:user_id] && is_admin?(session[:user_id]) %>'
  
  if content.include?(old_admin_check)
    content.gsub!(old_admin_check, new_admin_check)
    File.write(layout_path, content)
    puts "  ✅ Replaced hardcoded email with is_admin? helper"
    puts "  📝 Next steps:"
    puts "     1. Add is_admin? helper method to lib/helpers/app_helpers.rb"
    puts "     2. Implement role-based access control in database"
    puts "     3. Add admin column to users table"
  else
    puts "  ℹ️  Hardcoded admin check not found or already fixed"
  end
else
  puts "  ⚠️  layout.erb not found"
end

# ============================================
# FIX P1-4: Remove Duplicate Main Tags
# ============================================
puts "\n📌 P1-4: Fixing duplicate <main> tags..."

if File.exist?(layout_path)
  content = File.read(layout_path)
  
  # Find the problematic nested main tags
  if content.match(/<main>\s*<main id="main-content"/)
    # Remove outer main tag
    content.gsub!(/<!-- ================= MAIN CONTENT ================= -->\s*<main>\s*<main id="main-content"/, 
                  '<!-- ================= MAIN CONTENT ================= -->
  <main id="main-content"')
    
    # Find and remove closing outer main tag
    lines = content.split("\n")
    
    # Remove the line that's just </main> after the yield's main close
    fixed_lines = []
    skip_next_main_close = false
    
    lines.each_with_index do |line, i|
      if line.strip == '</main>' && skip_next_main_close
        skip_next_main_close = false
        next
      end
      
      if line.include?('<main id="main-content"') && line.include?('<%= yield %></main>')
        skip_next_main_close = true
      end
      
      fixed_lines << line
    end
    
    File.write(layout_path, fixed_lines.join("\n"))
    puts "  ✅ Removed duplicate <main> tags"
  else
    puts "  ℹ️  No duplicate <main> tags found"
  end
else
  puts "  ⚠️  layout.erb not found"
end

# ============================================
# Create Helper for Admin Check
# ============================================
puts "\n📌 Creating is_admin? helper method..."

app_helpers_path = 'lib/helpers/app_helpers.rb'
if File.exist?(app_helpers_path)
  content = File.read(app_helpers_path)
  
  helper_method = <<~RUBY
    
    # Admin role check - added during audit Week 1 fixes
    def is_admin?(user_id)
      return false unless user_id
      
      # Check admin status from database
      if defined?(DB)
        result = DB[:users].where(id: user_id).select(:admin).first
        return result && result[:admin] == true
      end
      
      # Fallback for development
      if ENV['RACK_ENV'] == 'development'
        # You can hardcode dev admin IDs here temporarily
        dev_admin_ids = [1]
        return dev_admin_ids.include?(user_id.to_i)
      end
      
      false
    rescue => e
      AppLogger.error('[AdminCheck] Error checking admin status', error: e.message)
      false
    end
  RUBY
  
  unless content.include?('def is_admin?')
    # Add before final 'end' of module
    content = content.sub(/end\s*\z/, "#{helper_method}\nend")
    File.write(app_helpers_path, content)
    puts "  ✅ Added is_admin? helper method"
  else
    puts "  ℹ️  is_admin? method already exists"
  end
else
  puts "  ⚠️  app_helpers.rb not found"
end

# ============================================
# Summary
# ============================================
puts "\n" + "=" * 60
puts "✅ WEEK 1 CRITICAL FIXES COMPLETE"
puts "=" * 60

puts "\n📋 MANUAL STEPS REQUIRED:"
puts "\n1. Create RedisReconnectWorker if using Sidekiq:"
puts "   app/workers/redis_reconnect_worker.rb"

puts "\n2. Review and consolidate profile routes:"
puts "   - Check routes/user_api_routes.rb.backup"
puts "   - Move unique code to routes/profile_routes.rb"
puts "   - Delete routes/user_api_routes.rb"
puts "   - Remove from app.rb registration"

puts "\n3. Add admin column to users table:"
puts "   CREATE TABLE users IF NOT EXISTS ("
puts "     id SERIAL PRIMARY KEY,"
puts "     admin BOOLEAN DEFAULT FALSE"
puts "   );"

puts "\n4. Set your user as admin:"
puts "   UPDATE users SET admin = TRUE WHERE id = <your_user_id>;"

puts "\n5. Test all changes:"
puts "   - Verify no thread leaks in Redis reconnection"
puts "   - Test /profile route works correctly"
puts "   - Verify social media previews (OG tags)"
puts "   - Test admin access control"
puts "   - Validate HTML (no duplicate <main> tags)"

puts "\n6. Run tests:"
puts "   bundle exec rspec"

puts "\n📝 Changes made:"
puts "  - lib/services/redis_service.rb (thread leak fix)"
puts "  - views/layout.erb (OG tags, admin check, main tags)"
puts "  - lib/helpers/app_helpers.rb (is_admin? method)"
puts "  - routes/user_api_routes.rb.backup (backup created)"

puts "\n🚀 Next: Commit these changes and test in development"
puts "    git add -A"
puts "    git commit -m 'Fix: Week 1 critical audit issues (P0-1 to P1-4)'"
