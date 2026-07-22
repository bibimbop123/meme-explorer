#!/usr/bin/env ruby
# Make specific user an admin

require_relative '../app'

# Support both email and username lookups
identifier = ARGV[0] || 'bibimbop123'

puts "🔧 Making #{identifier} an admin..."

# Check if user exists (try both email and username)
user = MemeExplorer::App::DB.execute(
  "SELECT id, email, reddit_username, role FROM users WHERE email = ? OR reddit_username = ?", 
  [identifier, identifier]
).first

if user
  # Update existing user to admin  
  MemeExplorer::App::DB.execute(
    "UPDATE users SET role = 'admin' WHERE id = ?", 
    [user['id']]
  )
  puts "✅ User #{user['email'] || user['reddit_username']} is now an admin!"
else
  # Create new admin user with temporary password
  require 'bcrypt'
  temp_password = 'TempAdmin123!'
  password_hash = BCrypt::Password.create(temp_password)
  
  MemeExplorer::App::DB.execute(
    "INSERT INTO users (email, password_hash, role, created_at) VALUES (?, ?, 'admin', CURRENT_TIMESTAMP)",
    [identifier.include?('@') ? identifier : "#{identifier}@temp.com", password_hash]
  )
  
  puts "✅ Created new admin user: #{identifier}"
  puts "🔑 Temporary password: #{temp_password}"
  puts "⚠️  Please login and change your password!"
end

# Verify
user = MemeExplorer::App::DB.execute(
  "SELECT id, email, reddit_username, role FROM users WHERE email = ? OR reddit_username = ?",
  [identifier, identifier]
).first
puts "\n📋 User details:"
puts "   ID: #{user['id']}"
puts "   Email: #{user['email']}"
puts "   Role: #{user['role']}"
puts "\n✅ Done! You can now access /admin"
