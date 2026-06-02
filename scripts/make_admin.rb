#!/usr/bin/env ruby
# Make specific user an admin

require_relative '../app'

email = 'brianhkim13@gmail.com'

puts "🔧 Making #{email} an admin..."

# Check if user exists
user = MemeExplorer::App::DB.execute("SELECT id, email, role FROM users WHERE email = ?", [email]).first

if user
  # Update existing user to admin
  MemeExplorer::App::DB.execute("UPDATE users SET role = 'admin' WHERE email = ?", [email])
  puts "✅ User #{email} is now an admin!"
else
  # Create new admin user with temporary password
  require 'bcrypt'
  temp_password = Bkimosabi13$
  password_hash = BCrypt::Password.create(temp_password)
  
  MemeExplorer::App::DB.execute(
    "INSERT INTO users (email, password_hash, role, created_at) VALUES (?, ?, 'admin', CURRENT_TIMESTAMP)",
    [email, password_hash]
  )
  
  puts "✅ Created new admin user: #{email}"
  puts "🔑 Temporary password: #{temp_password}"
  puts "⚠️  Please login and change your password!"
end

# Verify
user = MemeExplorer::App::DB.execute("SELECT id, email, role FROM users WHERE email = ?", [email]).first
puts "\n📋 User details:"
puts "   ID: #{user['id']}"
puts "   Email: #{user['email']}"
puts "   Role: #{user['role']}"
puts "\n✅ Done! You can now access /admin"
