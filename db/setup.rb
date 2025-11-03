require "sqlite3"
require "redis"

# SQLite - Create db directory if it doesn't exist
FileUtils.mkdir_p("db") unless Dir.exist?("db")

# Initialize DB with safe connection handling
DB = begin
  db = SQLite3::Database.new("db/memes.db")
  db.results_as_hash = true
  db.busy_timeout = 5000  # Wait up to 5 seconds for database locks
  db
rescue => e
  puts "❌ Database initialization error: #{e.message}"
  puts "Creating fallback SQLite database..."
  
  # Fallback: use in-memory database
  db = SQLite3::Database.new ":memory:"
  db.results_as_hash = true
  db
end

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

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS broken_images (
    url TEXT PRIMARY KEY,
    failure_count INTEGER DEFAULT 1,
    first_failed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_failed_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reddit_id TEXT UNIQUE,
    reddit_username TEXT,
    reddit_email TEXT,
    email TEXT UNIQUE,
    password_hash TEXT,
    role TEXT DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS saved_memes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    meme_url TEXT NOT NULL,
    meme_title TEXT,
    meme_subreddit TEXT,
    saved_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(user_id, meme_url)
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS user_meme_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    meme_url TEXT NOT NULL,
    liked INTEGER DEFAULT 0,
    liked_at DATETIME,
    unliked_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(user_id, meme_url)
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS user_subreddit_preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    subreddit TEXT NOT NULL,
    preference_score REAL DEFAULT 1.0,
    times_liked INTEGER DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(user_id, subreddit)
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS user_meme_exposure (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    meme_url TEXT NOT NULL,
    shown_count INTEGER DEFAULT 1,
    last_shown DATETIME DEFAULT CURRENT_TIMESTAMP,
    liked INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(user_id, meme_url)
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS user_category_preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    category TEXT NOT NULL,
    preference_score REAL DEFAULT 1.0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(user_id, category)
  );
SQL

# Create indexes for performance - CRITICAL for query optimization
begin
  DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_stats_url ON meme_stats(url)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit ON meme_stats(subreddit)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_user_meme_stats_user_id ON user_meme_stats(user_id)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_user_meme_stats_meme_url ON user_meme_stats(meme_url)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_saved_memes_user_id ON saved_memes(user_id)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_user_subreddit_pref ON user_subreddit_preferences(user_id, subreddit)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_broken_images_url ON broken_images(url)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_user_meme_exposure_composite ON user_meme_exposure(user_id, meme_url)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_meme_stats_score ON meme_stats(likes, views)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_user_subreddit_prefs ON user_subreddit_preferences(user_id)")
  DB.execute("CREATE INDEX IF NOT EXISTS idx_user_category_prefs ON user_category_preferences(user_id)")
rescue => e
  puts "⚠️ Index creation warning: #{e.message}"
end

# Redis
REDIS = begin
  Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
rescue => e
  puts "⚠️ Redis connection warning: #{e.message}"
  nil
end
