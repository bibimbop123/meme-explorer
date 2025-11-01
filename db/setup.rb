require "sqlite3"
require "redis"

# SQLite
DB = SQLite3::Database.new("db/memes.db")
DB.results_as_hash = true

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

# Redis
REDIS = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
