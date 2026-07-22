#!/usr/bin/env ruby
# Complete admin access fix - adds role column and makes user admin
# Date: July 22, 2026

require_relative '../app'

puts "🔧 Complete Admin Access Fix"
puts "=" * 50

# Step 1: Add role column
puts "\n📋 Step 1: Adding role column to users table..."

begin
  MemeExplorer::App::DB.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'user' NOT NULL")
  puts "✅ Role column added"
  
  MemeExplorer::App::DB.execute("CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)")
  puts "✅ Index created"
  
  MemeExplorer::App::DB.execute("UPDATE users SET role = 'user' WHERE role IS NULL")
  puts "✅ Default roles set"
  
rescue => e
  puts "⚠️  Column might already exist: #{e.message}"
end

# Step 2: Make user admin
identifier = ARGV[0] || 'bibimbop123'

puts "\n📋 Step 2: Making #{identifier} an admin..."

begin
  # Check if user exists
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
    temp_password = 'Bkimosabi13$'
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
  puts "   Username: #{user['reddit_username']}" if user['reddit_username']
  puts "   Role: #{user['role']}"
  puts "\n✅ Done! You can now access /admin"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
