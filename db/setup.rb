require "redis"
require "connection_pool"

# Determine database type from environment
DATABASE_URL = ENV.fetch("DATABASE_URL", nil)

if DATABASE_URL&.start_with?("postgres")
  # PostgreSQL Configuration
  require "pg"
  
  puts "🐘 Connecting to PostgreSQL..."
  
  DB_POOL = ConnectionPool.new(size: 25, timeout: 5) do
    PG.connect(DATABASE_URL)
  end
  
  # Wrapper to make ConnectionPool behave like direct DB connection
  DB = Object.new
  
  class << DB
    def execute(sql, params = [])
      DB_POOL.with do |conn|
        # Convert SQLite-style ? placeholders to PostgreSQL-style $1, $2, etc.
        pg_sql = sql.gsub('?') { |_| "$#{params.index(params[Regexp.last_match.offset(0)[0]]) + 1}" }
        counter = 0
        pg_sql = sql.gsub('?') { counter += 1; "$#{counter}" }
        
        result = if params.empty?
          conn.exec(pg_sql)
        else
          conn.exec_params(pg_sql, params)
        end
        
        # Convert PG::Result to array of hashes (like SQLite)
        result.map { |row| row.transform_keys(&:to_s) }
      end
    end
    
    def transaction
      DB_POOL.with do |conn|
        conn.transaction do
          yield conn
        end
      end
    end
    
    def get_first_value(sql, params = [])
      result = execute(sql, params)
      result.first&.values&.first
    end
  end
  
  puts "✅ PostgreSQL connected (pool: 25 connections)"
  
  # Tables are managed by db/postgres_schema.sql - no CREATE TABLE here
  
else
  # SQLite Configuration (Development/Fallback)
  require "sqlite3"
  
  puts "🗄️  Using SQLite (development mode)..."
  FileUtils.mkdir_p("db") unless Dir.exist?("db")
  
  DB = begin
    db = SQLite3::Database.new("db/memes.db")
    db.results_as_hash = true
    db.busy_timeout = 5000
    db
  rescue => e
    puts "❌ SQLite error: #{e.message}"
    db = SQLite3::Database.new(":memory:")
    db.results_as_hash = true
    db
  end
  
  puts "✅ SQLite connected"
  
  # Create tables for SQLite
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

  DB.execute <<-SQL
    CREATE TABLE IF NOT EXISTS push_subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      subscription_data TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
  SQL

  # Create indexes for performance
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
    DB.execute("CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id)")
  rescue => e
    puts "⚠️ Index creation warning: #{e.message}"
  end
end

# Redis Configuration with Connection Pooling
# CRITICAL FIX: Use connection pool for thread safety (32 Puma threads)
# See: SENIOR_DEV_REDIS_AUDIT_2026.md

REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

REDIS_POOL = ConnectionPool.new(size: 40, timeout: 5) do
  Redis.new(
    url: REDIS_URL,
    driver: :ruby,
    reconnect_attempts: 3,
    reconnect_delay: 0.5,
    reconnect_delay_max: 5
  )
end

# Legacy REDIS constant for backward compatibility during migration
# TODO: Gradually migrate all code to use REDIS_POOL.with { |r| r.method }
REDIS = REDIS_POOL.with { |conn| conn } rescue nil

puts "✅ Redis Pool initialized (size: 40, timeout: 5s, URL: #{REDIS_URL ? 'configured' : 'not set'})"

# Test connection
begin
  REDIS_POOL.with { |r| r.ping }
  puts "✅ Redis connection verified"
rescue => e
  puts "⚠️  Redis connection warning: #{e.message}"
end
