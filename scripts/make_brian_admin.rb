#!/usr/bin/env ruby
# Make brianhkim13@gmail.com admin (Reddit account email)

require_relative '../app'

puts "🔧 Making brianhkim13@gmail.com admin..."
puts "=" * 50

begin
  # Update ALL users with this email
  MemeExplorer::App::DB.execute(
    "UPDATE users SET role = 'admin' WHERE email ILIKE '%brianhkim13@gmail.com%'"
  )
  
  # Also update bibimbop123 accounts
  MemeExplorer::App::DB.execute(
    "UPDATE users SET role = 'admin' WHERE reddit_username ILIKE '%bibimbop123%' OR email ILIKE '%bibimbop123%'"
  )
  
  # Show all admin users
  users = MemeExplorer::App::DB.execute(
    "SELECT id, reddit_username, email, role FROM users WHERE email ILIKE '%brianhkim13@gmail.com%' OR reddit_username ILIKE '%bibimbop123%' OR email ILIKE '%bibimbop123%'"
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
    puts "🎉 You can now access /admin!"
  else
    puts "⚠️  No accounts found. Login with Reddit first to create the account."
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
