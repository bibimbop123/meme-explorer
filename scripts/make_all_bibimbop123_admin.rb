#!/usr/bin/env ruby
# Make ALL bibimbop123 accounts admin (both email and Reddit accounts)

require_relative '../app'

puts "🔧 Making all bibimbop123 accounts admin..."
puts "=" * 50

begin
  # Update ALL users with reddit_username containing 'bibimbop123'
  result1 = MemeExplorer::App::DB.execute(
    "UPDATE users SET role = 'admin' WHERE reddit_username ILIKE '%bibimbop123%'"
  )
  
  # Update ALL users with email containing 'bibimbop123'
  result2 = MemeExplorer::App::DB.execute(
    "UPDATE users SET role = 'admin' WHERE email ILIKE '%bibimbop123%'"
  )
  
  # Verify - show all bibimbop123 users
  users = MemeExplorer::App::DB.execute(
    "SELECT id, reddit_username, email, role FROM users WHERE reddit_username ILIKE '%bibimbop123%' OR email ILIKE '%bibimbop123%'"
  )
  
  if users.any?
    puts "✅ SUCCESS! Updated #{users.length} account(s):"
    puts ""
    users.each do |user|
      puts "  ID: #{user['id']}"
      puts "  Reddit: #{user['reddit_username']}" if user['reddit_username']
      puts "  Email: #{user['email']}" if user['email']
      puts "  Role: #{user['role']}"
      puts "  ---"
    end
    puts ""
    puts "You can now access /admin with ANY of these accounts!"
  else
    puts "⚠️  No bibimbop123 accounts found"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
