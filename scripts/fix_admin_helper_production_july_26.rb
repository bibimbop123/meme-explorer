#!/usr/bin/env ruby
# frozen_string_literal: true

# Production Hotfix: Fix admin? helper method
# July 26, 2026

puts "🚨 PRODUCTION HOTFIX: Fixing admin? helper method"
puts "=" * 80

# Fix the navigation partial to use a safe admin check
nav_file = 'views/partials/_simplified_nav.erb'

puts "\n📝 Fixing navigation partial..."

content = File.read(nav_file)

# Replace the admin? check with a safe inline check
fixed_content = content.gsub(
  '<% if session[:user_id] && admin? %>',
  '<% if session[:user_id] && session[:role] == "admin" %>'
)

File.write(nav_file, fixed_content)

puts "   ✅ Fixed admin check in navigation"

puts "\n" + "=" * 80
puts "✅ PRODUCTION HOTFIX COMPLETE!"
puts "=" * 80
puts "\n🔄 The app should now work without the NoMethodError"
puts "📊 Changes made:"
puts "   • Updated navigation to use session[:role] instead of admin? method"
puts "\n💡 Next: Deploy this fix to production"
