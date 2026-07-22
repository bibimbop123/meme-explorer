#!/usr/bin/env ruby
# Make bibimbop123 (user_id 1) an admin

require_relative '../app'

puts "🔧 Making bibimbop123 an admin..."
puts "=" * 50

begin
  # Update user ID 1 to admin
  MemeExplorer::App::DB.execute(
    "UPDATE users SET role = 'admin' WHERE id = 1"
  )
  
  # Verify
  user = MemeExplorer::App::DB.execute(
    "SELECT id, reddit_username, email, role FROM users WHERE id = 1"
  ).first
  
  if user && user['role'] == 'admin'
    puts "✅ SUCCESS!"
    puts ""
    puts "User: #{user['reddit_username'] || user['email']}"
    puts "ID: #{user['id']}"
    puts "Role: #{user['role']}"
    puts ""
    puts "You can now access /admin"
  else
    puts "❌ User not found or update failed"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
