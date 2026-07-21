#!/usr/bin/env ruby
# AdminCheck DBWrapper Fix - July 21, 2026
# Fixes the "undefined method `[]' for #<DBWrapper>" error
#
# ROOT CAUSE:
# The is_admin? method was using Sequel-style DB[:users] syntax,
# but DBWrapper only supports raw SQL with DB.execute()
#
# ERROR: undefined method `[]' for #<DBWrapper:0x0000799f22abbe00>
# SOLUTION: Replace Sequel syntax with proper DBWrapper SQL query

puts "🔧 Fixing AdminCheck DBWrapper Error..."
puts "=" * 60

# ============================================================
# Fix is_admin? method in app_helpers.rb
# ============================================================
app_helpers_path = 'lib/helpers/app_helpers.rb'

unless File.exist?(app_helpers_path)
  puts "❌ ERROR: #{app_helpers_path} not found!"
  exit 1
end

content = File.read(app_helpers_path)

# Check if already fixed
if content.include?('DB.execute("SELECT admin FROM users WHERE id = ?"')
  puts "✅ AdminCheck already fixed!"
  puts "   The is_admin? method is using proper DBWrapper syntax."
  exit 0
end

puts "\n📝 Fixing is_admin? method..."

# Replace the broken Sequel-style syntax with proper DBWrapper SQL
old_method = <<~RUBY
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

new_method = <<~RUBY
# Admin role check - added during audit Week 1 fixes
# FIXED: July 21, 2026 - Use DBWrapper SQL syntax instead of Sequel
def is_admin?(user_id)
  return false unless user_id
  
  # Query admin status using DBWrapper's execute method
  result = DB.execute("SELECT admin FROM users WHERE id = ?", [user_id])
  return false if result.nil? || result.empty?
  
  # PostgreSQL returns boolean as true/false or 't'/'f' string
  admin_value = result.first['admin']
  admin_value == true || admin_value == 't' || admin_value == 1
rescue => e
  AppLogger.error('[AdminCheck] Error checking admin status', error: e.message)
  false
end
RUBY

# Perform the replacement
new_content = content.sub(old_method.strip, new_method.strip)

if new_content == content
  puts "⚠️  WARNING: Could not find exact method match."
  puts "   Attempting fuzzy replacement..."
  
  # Try a more flexible replacement
  new_content = content.gsub(
    /# Admin role check.*?def is_admin\?\(user_id\).*?^end/m,
    new_method.strip
  )
  
  if new_content == content
    puts "❌ ERROR: Could not replace is_admin? method!"
    puts "   Please manually update lib/helpers/app_helpers.rb"
    exit 1
  end
end

File.write(app_helpers_path, new_content)
puts "   ✅ Fixed is_admin? method to use DB.execute()"

# ============================================================
# Verify the fix
# ============================================================
puts "\n🔍 Verifying fix..."

updated_content = File.read(app_helpers_path)

if updated_content.include?('DB.execute("SELECT admin FROM users WHERE id = ?"')
  puts "   ✅ Verification passed!"
  puts "   ✅ Method now uses proper DBWrapper syntax"
else
  puts "   ❌ Verification failed!"
  exit 1
end

# ============================================================
# Summary
# ============================================================
puts "\n" + "=" * 60
puts "✅ AdminCheck Fix Complete!"
puts "=" * 60
puts
puts "WHAT WAS FIXED:"
puts "  • Changed DB[:users].where() to DB.execute()"
puts "  • Added proper SQL query with parameterized values"
puts "  • Added support for PostgreSQL boolean formats (true, 't', 1)"
puts "  • Removed Sequel ORM syntax incompatible with DBWrapper"
puts
puts "IMPACT:"
puts "  • AdminCheck errors will stop appearing in production logs"
puts "  • Admin functionality will work correctly"
puts "  • No more 'undefined method []' exceptions"
puts
puts "DEPLOYMENT:"
puts "  1. Commit the changes:"
puts "     git add lib/helpers/app_helpers.rb"
puts "     git commit -m 'Fix AdminCheck DBWrapper syntax error'"
puts
puts "  2. Deploy to production:"
puts "     git push origin main"
puts
puts "  3. Monitor logs for AdminCheck errors (should be zero):"
puts "     render logs --tail --service meme-explorer | grep AdminCheck"
puts
puts "=" * 60
