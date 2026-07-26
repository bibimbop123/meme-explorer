#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 2: Authorization System Deployment
# Date: July 26, 2026
# Purpose: Deploy RBAC permissions system

require_relative '../config/environment'
require_relative '../lib/services/authorization_service'

puts "🔐 Phase 2: Authorization System Deployment"
puts "=" * 60

# Step 1: Run migrations
puts "\n📦 Step 1: Running database migrations..."
begin
  migration_path = File.expand_path('../../db/migrations/add_permissions_system_july_26_2026.sql', __FILE__)
  sql = File.read(migration_path)
  
  # Split by semicolon and execute each statement
  sql.split(';').each do |statement|
    next if statement.strip.empty? || statement.strip.start_with?('--')
    DB.execute(statement.strip)
  end
  
  puts "✅ Database migrations complete"
rescue => e
  puts "❌ Migration failed: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

# Step 2: Verify tables exist
puts "\n📊 Step 2: Verifying tables..."
begin
  permissions_count = DB.execute("SELECT COUNT(*) as count FROM permissions").first['count']
  audit_count = DB.execute("SELECT COUNT(*) as count FROM permission_audit_log").first['count']
  
  puts "✅ permissions table: #{permissions_count} records"
  puts "✅ permission_audit_log table: #{audit_count} records"
rescue => e
  puts "❌ Table verification failed: #{e.message}"
  exit 1
end

# Step 3: Test AuthorizationService
puts "\n🧪 Step 3: Testing AuthorizationService..."
begin
  # Test admin check
  test_result = AuthorizationService.admin?(1)
  puts "✅ admin? method: #{test_result.inspect}"
  
  # Test can? method
  can_result = AuthorizationService.can?(1, 'read', 'users')
  puts "✅ can? method: #{can_result.inspect}"
  
  # Test get_role
  role = AuthorizationService.get_role(1)
  puts "✅ get_role method: #{role.inspect}"
  
  puts "✅ AuthorizationService working correctly"
rescue => e
  puts "❌ Service test failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Step 4: Show permissions breakdown
puts "\n📋 Step 4: Current permissions:"
begin
  roles = ['admin', 'moderator', 'premium', 'user']
  roles.each do |role|
    perms = AuthorizationService.get_role_permissions(role)
    puts "\n#{role.upcase}:"
    if perms.empty?
      puts "  No specific permissions (#{perms.length})"
    else
      perms.each do |perm|
        puts "  • #{perm['action']} on #{perm['resource']}"
      end
    end
  end
rescue => e
  puts "⚠️  Could not fetch permissions: #{e.message}"
end

puts "\n" + "=" * 60
puts "✅ Phase 2: Authorization System Deployment Complete!"
puts "=" * 60

puts "\n📝 Next Steps:"
puts "1. Add 'use AuthorizationMiddleware' to config.ru"
puts "2. Test admin routes are protected"
puts "3. Verify permission checks work"
puts "4. Review audit logs"
puts "\n💡 Tip: Use AuthorizationService.change_role(user_id, 'admin', admin_id) to promote users"
