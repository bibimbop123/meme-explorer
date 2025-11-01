# db/setup.rb
require "sqlite3"

DB = SQLite3::Database.new("db/memes.db")

# Enable results as hashes for easier access
DB.results_as_hash = true

# -----------------------
# Create table if not exists
# -----------------------
DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS meme_stats (
    url TEXT PRIMARY KEY,
    title TEXT,
    subreddit TEXT,
    views INTEGER DEFAULT 0,
    likes INTEGER DEFAULT 0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
SQL

# -----------------------
# Helper methods for views/likes
# -----------------------
def increment_view(url)
  DB.execute <<-SQL, [url]
    INSERT OR IGNORE INTO meme_stats (url, title, subreddit, views, likes)
    VALUES (?, 'Unknown', 'local', 0, 0);
  SQL

  DB.execute <<-SQL, [url]
    UPDATE meme_stats
    SET views = views + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE url = ?;
  SQL
end

def increment_like(url)
  DB.execute <<-SQL, [url]
    UPDATE meme_stats
    SET likes = likes + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE url = ?;
  SQL
end

# -----------------------
# Optional: Migration for existing tables
# -----------------------
begin
  DB.execute("SELECT updated_at FROM meme_stats LIMIT 1")
rescue SQLite3::SQLException
  puts "Migrating meme_stats table to add updated_at column..."

  # 1. Rename old table
  DB.execute("ALTER TABLE meme_stats RENAME TO meme_stats_old;")

  # 2. Create new table with updated_at
  DB.execute <<-SQL
    CREATE TABLE meme_stats (
      url TEXT PRIMARY KEY,
      title TEXT,
      subreddit TEXT,
      views INTEGER DEFAULT 0,
      likes INTEGER DEFAULT 0,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  SQL

  # 3. Copy data from old table
  DB.execute <<-SQL
    INSERT INTO meme_stats (url, title, subreddit, views, likes)
    SELECT url, title, subreddit, views, likes FROM meme_stats_old;
  SQL

  # 4. Drop old table
  DB.execute("DROP TABLE meme_stats_old;")
  puts "Migration complete."
end
