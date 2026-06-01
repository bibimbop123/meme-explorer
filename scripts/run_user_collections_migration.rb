#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sqlite3'

# Run user collections migration
db_file = ENV['DATABASE_URL'] || 'memes.db'
db = SQLite3::Database.new(db_file)

puts "Running user collections migration..."

# Create tables
tables_sql = <<~SQL
  CREATE TABLE IF NOT EXISTS user_collections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    slug VARCHAR(255) NOT NULL UNIQUE,
    is_public BOOLEAN DEFAULT 1,
    meme_count INTEGER DEFAULT 0,
    total_likes INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS collection_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    collection_id INTEGER NOT NULL,
    meme_url VARCHAR(500) NOT NULL,
    position INTEGER DEFAULT 0,
    note TEXT,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (collection_id) REFERENCES user_collections(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS collection_followers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    collection_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    followed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (collection_id) REFERENCES user_collections(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(collection_id, user_id)
  );

  CREATE TABLE IF NOT EXISTS collection_likes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    collection_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    liked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (collection_id) REFERENCES user_collections(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(collection_id, user_id)
  );
SQL

begin
  db.execute_batch(tables_sql)
  puts "✅ Tables created successfully"
rescue => e
  puts "⚠️  Table creation: #{e.message}"
end

# Create indexes
indexes = [
  "CREATE INDEX IF NOT EXISTS idx_user_collections_user ON user_collections(user_id);",
  "CREATE INDEX IF NOT EXISTS idx_user_collections_slug ON user_collections(slug);",
  "CREATE INDEX IF NOT EXISTS idx_collection_items_collection ON collection_items(collection_id);",
  "CREATE INDEX IF NOT EXISTS idx_collection_items_position ON collection_items(collection_id, position);",
  "CREATE INDEX IF NOT EXISTS idx_collection_followers_collection ON collection_followers(collection_id);",
  "CREATE INDEX IF NOT EXISTS idx_collection_followers_user ON collection_followers(user_id);",
  "CREATE INDEX IF NOT EXISTS idx_collection_likes_collection ON collection_likes(collection_id);",
  "CREATE INDEX IF NOT EXISTS idx_collection_likes_user ON collection_likes(user_id);"
]

indexes.each do |index_sql|
  begin
    db.execute(index_sql)
  rescue => e
    puts "⚠️  Index creation: #{e.message}"
  end
end

puts "✅ Indexes created successfully"

# Verify tables exist
tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%collection%';")
puts "\n📊 Collections tables:"
tables.each do |table|
  count = db.execute("SELECT COUNT(*) FROM #{table[0]}").first[0]
  puts "  - #{table[0]} (#{count} rows)"
end

db.close
puts "\n✅ Migration complete!"
