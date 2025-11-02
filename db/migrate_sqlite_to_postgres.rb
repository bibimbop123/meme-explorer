#!/usr/bin/env ruby
# SQLite to PostgreSQL Migration Script
# Usage: ruby db/migrate_sqlite_to_postgres.rb

require 'sqlite3'
require 'pg'
require 'date'
require 'json'
require 'fileutils'

class SqliteToPostgresMigrator
  def initialize(sqlite_path, pg_connection_string)
    @sqlite_path = sqlite_path
    @pg_connection_string = pg_connection_string
    @sqlite_db = nil
    @pg_conn = nil
    @errors = []
    @migrated_counts = {}
  end

  def run
    puts "=" * 80
    puts "SQLite → PostgreSQL Migration for Meme Explorer"
    puts "=" * 80
    puts

    begin
      connect_to_databases
      backup_sqlite
      create_postgresql_schema
      migrate_data
      verify_migration
      print_summary
    ensure
      disconnect_databases
    end
  end

  private

  def connect_to_databases
    puts "📡 Connecting to databases..."
    
    # SQLite
    @sqlite_db = SQLite3::Database.new(@sqlite_path)
    @sqlite_db.results_as_hash = true
    puts "  ✓ Connected to SQLite: #{@sqlite_path}"

    # PostgreSQL
    @pg_conn = PG.connect(@pg_connection_string)
    puts "  ✓ Connected to PostgreSQL"
    puts
  end

  def backup_sqlite
    puts "💾 Creating backup..."
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    backup_path = File.join(File.dirname(@sqlite_path), "memes.db.backup_#{timestamp}")
    FileUtils.cp(@sqlite_path, backup_path)
    puts "  ✓ Backup created: #{backup_path}"
    puts
  end

  def create_postgresql_schema
    puts "🏗️  Creating PostgreSQL schema..."
    
    # Drop existing tables (fresh migration)
    tables = %w[broken_images saved_memes user_subreddit_preferences user_meme_exposure user_meme_stats meme_stats users]
    tables.each do |table|
      @pg_conn.exec("DROP TABLE IF EXISTS #{table} CASCADE")
    end
    
    # Create tables
    @pg_conn.exec(%{
      CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        reddit_id VARCHAR(255) UNIQUE,
        reddit_username VARCHAR(255),
        reddit_email VARCHAR(255),
        email VARCHAR(255) UNIQUE,
        password_hash VARCHAR(255),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      )
    })
    puts "  ✓ Created users table"

    @pg_conn.exec(%{
      CREATE TABLE meme_stats (
        id SERIAL PRIMARY KEY,
        url TEXT UNIQUE NOT NULL,
        title TEXT,
        subreddit VARCHAR(255),
        likes INTEGER DEFAULT 0,
        views INTEGER DEFAULT 0,
        failure_count INTEGER DEFAULT 0,
        first_failed_at TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      )
    })
    puts "  ✓ Created meme_stats table"

    @pg_conn.exec(%{
      CREATE INDEX idx_meme_stats_likes_views ON meme_stats(likes DESC, views DESC)
    })
    @pg_conn.exec(%{
      CREATE INDEX idx_meme_stats_subreddit ON meme_stats(subreddit)
    })
    @pg_conn.exec(%{
      CREATE INDEX idx_meme_stats_updated_at ON meme_stats(updated_at DESC)
    })

    @pg_conn.exec(%{
      CREATE TABLE user_meme_stats (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        meme_url TEXT NOT NULL,
        liked INTEGER DEFAULT 0,
        liked_at TIMESTAMP,
        unliked_at TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, meme_url)
      )
    })
    puts "  ✓ Created user_meme_stats table"

    @pg_conn.exec(%{
      CREATE TABLE user_meme_exposure (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        meme_url TEXT NOT NULL,
        shown_count INTEGER DEFAULT 1,
        last_shown TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, meme_url)
      )
    })
    puts "  ✓ Created user_meme_exposure table"

    @pg_conn.exec(%{
      CREATE TABLE user_subreddit_preferences (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        subreddit VARCHAR(255) NOT NULL,
        preference_score DOUBLE PRECISION DEFAULT 1.0,
        times_liked INTEGER DEFAULT 1,
        last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, subreddit)
      )
    })
    puts "  ✓ Created user_subreddit_preferences table"

    @pg_conn.exec(%{
      CREATE TABLE saved_memes (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        meme_url TEXT NOT NULL,
        meme_title TEXT,
        meme_subreddit VARCHAR(255),
        saved_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, meme_url)
      )
    })
    puts "  ✓ Created saved_memes table"

    @pg_conn.exec(%{
      CREATE TABLE broken_images (
        id SERIAL PRIMARY KEY,
        url TEXT UNIQUE NOT NULL,
        failure_count INTEGER DEFAULT 1,
        first_failed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        last_failed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      )
    })
    puts "  ✓ Created broken_images table"
    puts
  end

  def migrate_data
    puts "📦 Migrating data..."

    migrate_users
    migrate_meme_stats
    migrate_user_meme_stats
    migrate_user_meme_exposure
    migrate_user_subreddit_preferences
    migrate_saved_memes
    migrate_broken_images

    puts
  end

  def migrate_users
    rows = @sqlite_db.execute("SELECT * FROM users")
    
    rows.each do |row|
      @pg_conn.exec_params(%{
        INSERT INTO users (id, reddit_id, reddit_username, reddit_email, email, password_hash, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id) DO NOTHING
      }, [
        row['id'],
        row['reddit_id'],
        row['reddit_username'],
        row['reddit_email'],
        row['email'],
        row['password_hash'],
        parse_timestamp(row['created_at']),
        parse_timestamp(row['updated_at'])
      ])
    end

    @migrated_counts['users'] = rows.size
    puts "  ✓ Migrated #{rows.size} users"
  rescue => e
    @errors << "Users migration failed: #{e.message}"
    @migrated_counts['users'] = 0
  end

  def migrate_meme_stats
    rows = @sqlite_db.execute("SELECT * FROM meme_stats")
    
    rows.each do |row|
      @pg_conn.exec_params(%{
        INSERT INTO meme_stats (id, url, title, subreddit, likes, views, failure_count, first_failed_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (url) DO NOTHING
      }, [
        row['id'],
        row['url'],
        row['title'],
        row['subreddit'],
        row['likes'].to_i,
        row['views'].to_i,
        row['failure_count'].to_i,
        parse_timestamp(row['first_failed_at']),
        parse_timestamp(row['updated_at'])
      ])
    end

    @migrated_counts['meme_stats'] = rows.size
    puts "  ✓ Migrated #{rows.size} meme_stats"
  rescue => e
    @errors << "Meme stats migration failed: #{e.message}"
    @migrated_counts['meme_stats'] = 0
  end

  def migrate_user_meme_stats
    rows = @sqlite_db.execute("SELECT * FROM user_meme_stats")
    
    rows.each do |row|
      @pg_conn.exec_params(%{
        INSERT INTO user_meme_stats (id, user_id, meme_url, liked, liked_at, unliked_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT DO NOTHING
      }, [
        row['id'],
        row['user_id'].to_i,
        row['meme_url'],
        row['liked'].to_i,
        parse_timestamp(row['liked_at']),
        parse_timestamp(row['unliked_at']),
        parse_timestamp(row['updated_at'])
      ])
    end

    @migrated_counts['user_meme_stats'] = rows.size
    puts "  ✓ Migrated #{rows.size} user_meme_stats"
  rescue => e
    @errors << "User meme stats migration failed: #{e.message}"
    @migrated_counts['user_meme_stats'] = 0
  end

  def migrate_user_meme_exposure
    rows = @sqlite_db.execute("SELECT * FROM user_meme_exposure")
    
    rows.each do |row|
      @pg_conn.exec_params(%{
        INSERT INTO user_meme_exposure (id, user_id, meme_url, shown_count, last_shown)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT DO NOTHING
      }, [
        row['id'],
        row['user_id'].to_i,
        row['meme_url'],
        row['shown_count'].to_i,
        parse_timestamp(row['last_shown'])
      ])
    end

    @migrated_counts['user_meme_exposure'] = rows.size
    puts "  ✓ Migrated #{rows.size} user_meme_exposure"
  rescue => e
    @errors << "User meme exposure migration failed: #{e.message}"
    @migrated_counts['user_meme_exposure'] = 0
  end

  def migrate_user_subreddit_preferences
    rows = @sqlite_db.execute("SELECT * FROM user_subreddit_preferences")
    
    rows.each do |row|
      @pg_conn.exec_params(%{
        INSERT INTO user_subreddit_preferences (id, user_id, subreddit, preference_score, times_liked, last_updated)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT DO NOTHING
      }, [
        row['id'],
        row['user_id'].to_i,
        row['subreddit'],
        row['preference_score'].to_f,
        row['times_liked'].to_i,
        parse_timestamp(row['last_updated'])
      ])
    end

    @migrated_counts['user_subreddit_preferences'] = rows.size
    puts "  ✓ Migrated #{rows.size} user_subreddit_preferences"
  rescue => e
    @errors << "User subreddit preferences migration failed: #{e.message}"
    @migrated_counts['user_subreddit_preferences'] = 0
  end

  def migrate_saved_memes
    rows = @sqlite_db.execute("SELECT * FROM saved_memes")
    
    rows.each do |row|
      @pg_conn.exec_params(%{
        INSERT INTO saved_memes (id, user_id, meme_url, meme_title, meme_subreddit, saved_at)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT DO NOTHING
      }, [
        row['id'],
        row['user_id'].to_i,
        row['meme_url'],
        row['meme_title'],
        row['meme_subreddit'],
        parse_timestamp(row['saved_at'])
      ])
    end

    @migrated_counts['saved_memes'] = rows.size
    puts "  ✓ Migrated #{rows.size} saved_memes"
  rescue => e
    @errors << "Saved memes migration failed: #{e.message}"
    @migrated_counts['saved_memes'] = 0
  end

  def migrate_broken_images
    rows = @sqlite_db.execute("SELECT * FROM broken_images")
    
    rows.each do |row|
      @pg_conn.exec_params(%{
        INSERT INTO broken_images (id, url, failure_count, first_failed_at, last_failed_at)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (url) DO NOTHING
      }, [
        row['id'],
        row['url'],
        row['failure_count'].to_i,
        parse_timestamp(row['first_failed_at']),
        parse_timestamp(row['last_failed_at'])
      ])
    end

    @migrated_counts['broken_images'] = rows.size
    puts "  ✓ Migrated #{rows.size} broken_images"
  rescue => e
    @errors << "Broken images migration failed: #{e.message}"
    @migrated_counts['broken_images'] = 0
  end

  def verify_migration
    puts "✅ Verifying migration..."
    
    tables = %w[users meme_stats user_meme_stats user_meme_exposure user_subreddit_preferences saved_memes broken_images]
    
    tables.each do |table|
      pg_count = @pg_conn.exec("SELECT COUNT(*) FROM #{table}").first['count'].to_i
      sqlite_count = @sqlite_db.get_first_value("SELECT COUNT(*) FROM #{table}").to_i
      
      match = pg_count == sqlite_count ? "✓" : "⚠️"
      puts "  #{match} #{table}: SQLite=#{sqlite_count}, PostgreSQL=#{pg_count}"
    end
    
    puts
  end

  def print_summary
    puts "=" * 80
    puts "MIGRATION SUMMARY"
    puts "=" * 80
    
    total_migrated = @migrated_counts.values.sum
    puts "Total records migrated: #{total_migrated}"
    puts
    
    @migrated_counts.each do |table, count|
      puts "  #{table}: #{count} records"
    end
    
    if @errors.any?
      puts
      puts "⚠️  ERRORS OCCURRED:"
      @errors.each { |error| puts "  - #{error}" }
    else
      puts
      puts "✅ Migration completed successfully!"
    end
    
    puts
    puts "NEXT STEPS:"
    puts "  1. Run tests: bundle exec rspec"
    puts "  2. Verify data: psql -d meme_explorer_dev -c 'SELECT COUNT(*) FROM meme_stats;'"
    puts "  3. Deploy to staging"
    puts "  4. Monitor for 24 hours"
    puts "  5. Deploy to production"
    puts
  end

  def parse_timestamp(value)
    return nil if value.nil? || value.empty?
    
    # Handle different timestamp formats
    if value.is_a?(String)
      # SQLite format: "2025-11-02 05:05:00"
      begin
        DateTime.parse(value).to_time
      rescue
        nil
      end
    else
      value
    end
  end

  def disconnect_databases
    @sqlite_db.close if @sqlite_db
    @pg_conn.close if @pg_conn
  end
end

# Main execution
if __FILE__ == $0
  sqlite_path = ENV['SQLITE_PATH'] || File.join(__dir__, '..', 'meme_explorer.db')
  pg_connection_string = ENV['DATABASE_URL'] || 'postgresql://meme_explorer_dev:dev_password_local@localhost:5432/meme_explorer_dev'

  unless File.exist?(sqlite_path)
    puts "❌ SQLite database not found at: #{sqlite_path}"
    exit 1
  end

  migrator = SqliteToPostgresMigrator.new(sqlite_path, pg_connection_string)
  migrator.run
end
