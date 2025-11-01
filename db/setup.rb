require "sqlite3"
require "redis"

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
# Add rowid column for navigation (SQLite has implicit rowid)
# -----------------------
# Note: rowid exists automatically unless you declare WITHOUT ROWID

# -----------------------
# Helper methods for views/likes
# -----------------------
def increment_view(url, title: "Unknown", subreddit: "local")
  DB.execute(
    "INSERT OR IGNORE INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 0, 0)",
    [url, title, subreddit]
  )
  DB.execute("UPDATE meme_stats SET views = views + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])
end

def increment_like(url)
  DB.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])
end

# -----------------------
# Optional: Migration for existing tables
# -----------------------
begin
  DB.execute("SELECT updated_at FROM meme_stats LIMIT 1")
rescue SQLite3::SQLException
  puts "Migrating meme_stats table to add updated_at column..."

  DB.execute("ALTER TABLE meme_stats RENAME TO meme_stats_old;")

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

  DB.execute <<-SQL
    INSERT INTO meme_stats (url, title, subreddit, views, likes)
    SELECT url, title, subreddit, views, likes FROM meme_stats_old;
  SQL

  DB.execute("DROP TABLE meme_stats_old;")
  puts "Migration complete."
end
