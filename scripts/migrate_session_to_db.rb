#!/usr/bin/env ruby
# Migrate existing session-based likes to database
# Run ONCE before deploying the fix

require_relative '../db/setup'

puts "🔄 Migrating session data to database..."

# Create user_liked_memes table
DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS user_liked_memes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    meme_url TEXT NOT NULL,
    liked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, meme_url),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );
SQL

DB.execute <<-SQL
  CREATE INDEX IF NOT EXISTS idx_user_liked_memes_user_id 
  ON user_liked_memes(user_id);
SQL

DB.execute <<-SQL
  CREATE INDEX IF NOT EXISTS idx_user_liked_memes_url 
  ON user_liked_memes(meme_url);
SQL

puts "✅ user_liked_memes table created"

# Create user_saved_memes table
DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS user_saved_memes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    meme_url TEXT NOT NULL,
    saved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    UNIQUE(user_id, meme_url),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );
SQL

DB.execute <<-SQL
  CREATE INDEX IF NOT EXISTS idx_user_saved_memes_user_id 
  ON user_saved_memes(user_id);
SQL

puts "✅ user_saved_memes table created"

puts "⚠️  Note: Existing session data cannot be migrated (sessions are ephemeral)"
puts "   Users will need to re-like memes after this update"
puts "✅ Migration complete"
