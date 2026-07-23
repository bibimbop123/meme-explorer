#!/usr/bin/env ruby
# Week 1 Days 3-4: Database Connection Pool & Critical Indexes
# Priority: P0 - CRITICAL
# Date: July 22, 2026

require 'fileutils'

puts "="*80
puts "WEEK 1 DAYS 3-4: DATABASE OPTIMIZATION"
puts "="*80
puts ""

# Fix #1: Create proper database connection pool configuration
puts "[1/5] Creating connection pool configuration..."

db_config_file = 'config/database.yml'

db_config_content = <<~YAML
  # Database Configuration with Proper Connection Pooling
  # Created: July 22, 2026
  # Impact: Prevents connection exhaustion under load
  
  default: &default
    adapter: postgresql
    encoding: unicode
    # Connection pool sized for Puma with 5 threads, 5 workers = 25 total
    # Rule: pool = (max_threads * worker_count) + buffer
    pool: 30
    timeout: 5000
    # Reap connections that have been idle for 10 seconds
    reaping_frequency: 10
    # Verify connections are still valid before using
    checkout_timeout: 5
    variables:
      statement_timeout: 15000  # 15 seconds max query time
      idle_in_transaction_session_timeout: 60000  # 60 seconds max idle in transaction

  development:
    <<: *default
    database: meme_explorer_development
    pool: 10  # Smaller pool for dev

  test:
    <<: *default
    database: meme_explorer_test
    pool: 5

  production:
    <<: *default
    database: <%= ENV['DATABASE_NAME'] || 'meme_explorer_production' %>
    username: <%= ENV['DATABASE_USER'] %>
    password: <%= ENV['DATABASE_PASSWORD'] %>
    host: <%= ENV['DATABASE_HOST'] %>
    port: <%= ENV['DATABASE_PORT'] || 5432 %>
    pool: <%= ENV['DB_POOL'] || 30 %>
    # Production-specific settings
    prepared_statements: true
    advisory_locks: true
YAML

File.write(db_config_file, db_config_content)
puts "   ✓ Created: #{db_config_file}"

puts ""

# Fix #2: Create critical database indexes migration
puts "[2/5] Creating critical indexes migration..."

migration_file = 'db/migrations/add_critical_indexes_week1_2026.sql'
FileUtils.mkdir_p('db/migrations')

migration_content = <<~SQL
  -- Critical Database Indexes for Performance
  -- Week 1 Days 3-4: Database Optimization
  -- Date: July 22, 2026
  
  -- Drop indexes if they exist (idempotent)
  DROP INDEX IF EXISTS idx_memes_created_at;
  DROP INDEX IF EXISTS idx_memes_subreddit;
  DROP INDEX IF EXISTS idx_memes_quality_score;
  DROP INDEX IF EXISTS idx_memes_composite_trending;
  DROP INDEX IF EXISTS idx_users_username;
  DROP INDEX IF EXISTS idx_user_likes_composite;
  DROP INDEX IF EXISTS idx_viewing_history_composite;
  DROP INDEX IF EXISTS idx_sessions_user_id;
  DROP INDEX IF EXISTS idx_sessions_expires_at;
  
  -- Memes table indexes
  -- For trending/recent queries
  CREATE INDEX idx_memes_created_at ON memes(created_at DESC);
  
  -- For subreddit filtering
  CREATE INDEX idx_memes_subreddit ON memes(subreddit) WHERE subreddit IS NOT NULL;
  
  -- For quality filtering
  CREATE INDEX idx_memes_quality_score ON memes(quality_score DESC) WHERE quality_score IS NOT NULL;
  
  -- Composite index for trending queries (most common query pattern)
  CREATE INDEX idx_memes_composite_trending ON memes(created_at DESC, quality_score DESC)
    WHERE quality_score > 0.5;
  
  -- Users table indexes
  CREATE UNIQUE INDEX idx_users_username ON users(LOWER(username));
  
  -- User_likes composite (user + meme lookup)
  CREATE INDEX idx_user_likes_composite ON user_likes(user_id, meme_id);
  
  -- Viewing history composite (for "seen" checks)
  CREATE INDEX idx_viewing_history_composite ON viewing_history(user_id, meme_id, viewed_at DESC);
  
  -- Sessions table indexes
  CREATE INDEX idx_sessions_user_id ON sessions(user_id) WHERE user_id IS NOT NULL;
  CREATE INDEX idx_sessions_expires_at ON sessions(expires_at) WHERE expires_at > NOW();
  
  -- Analyze tables to update statistics
  ANALYZE memes;
  ANALYZE users;
  ANALYZE user_likes;
  ANALYZE viewing_history;
  ANALYZE sessions;
SQL

File.write(migration_file, migration_content)
puts "   ✓ Created: #{migration_file}"

puts ""

# Fix #3: Create connection pool monitoring helper
puts "[3/5] Creating connection pool monitor..."

monitor_file = 'lib/helpers/connection_pool_monitor.rb'

monitor_content = <<~RUBY
  # frozen_string_literal: true

  # Connection Pool Monitoring Helper
  # Tracks and logs connection pool health
  # Created: July 22, 2026

  module ConnectionPoolMonitor
    class << self
      def stats
        return {} unless defined?(ActiveRecord::Base)
        
        pool = ActiveRecord::Base.connection_pool
        {
          size: pool.size,
          connections: pool.connections.size,
          in_use: pool.connections.count(&:in_use?),
          available: pool.available_connection_count,
          waiting: pool.num_waiting_in_queue,
          utilization: utilization_percentage(pool)
        }
      end

    def log_stats
      return unless should_log?
      
      data = stats
      return if data.empty?
      
      if data[:utilization] > 80
        AppLogger.warn("[ConnectionPool] High utilization: \#{data[:utilization]}%", data)
      elsif data[:waiting] > 0
        AppLogger.warn("[ConnectionPool] Connections waiting: \#{data[:waiting]}", data)
      else
        AppLogger.debug("[ConnectionPool] Health check", data)
      end
    end

    def health_check
      data = stats
      return :unknown if data.empty?
      
      return :critical if data[:utilization] > 95
      return :warning if data[:utilization] > 80
        return :healthy
      end

      private

      def utilization_percentage(pool)
        return 0 if pool.size.zero?
        ((pool.connections.count(&:in_use?).to_f / pool.size) * 100).round(1)
      end

      def should_log?
        ENV['CONNECTION_POOL_MONITORING'] == 'true' || ENV['RACK_ENV'] == 'development'
      end
    end
  end
RUBY

File.write(monitor_file, monitor_content)
puts "   ✓ Created: #{monitor_file}"

puts ""

# Fix #4: Create database query timeout concern
puts "[4/5] Creating query timeout protection..."

timeout_file = 'lib/concerns/query_timeout.rb'

timeout_content = <<~RUBY
  # frozen_string_literal: true

  # Query Timeout Protection
  # Prevents long-running queries from blocking the app
  # Created: July 22, 2026

  module QueryTimeout
    # Wrap database queries with timeout protection
    def with_query_timeout(seconds = 10, &block)
      return block.call unless defined?(ActiveRecord::Base)
      
      original_timeout = get_statement_timeout
      set_statement_timeout(seconds * 1000) # milliseconds
      
      begin
        block.call
      rescue ActiveRecord::QueryCanceled => e
        AppLogger.error("[QueryTimeout] Query exceeded #{seconds}s timeout", {
          error: e.message,
          backtrace: e.backtrace[0..5]
        })
        raise
      ensure
        set_statement_timeout(original_timeout)
      end
    end

    # Execute read-only query with short timeout
    def with_read_timeout(&block)
      with_query_timeout(5, &block)
    end

    # Execute write query with longer timeout
    def with_write_timeout(&block)
      with_query_timeout(15, &block)
    end

    private

    def get_statement_timeout
      result = ActiveRecord::Base.connection.execute(
        "SHOW statement_timeout"
      ).first
      result ? result['statement_timeout'].to_i : 0
    rescue
      0
    end

    def set_statement_timeout(milliseconds)
      ActiveRecord::Base.connection.execute(
        "SET statement_timeout = #{milliseconds}"
      )
    rescue => e
      AppLogger.warn("[QueryTimeout] Failed to set timeout: #{e.message}")
    end
  end
RUBY

File.write(timeout_file, timeout_content)
puts "   ✓ Created: #{timeout_file}"

puts ""

# Fix #5: Create migration runner script
puts "[5/5] Creating migration runner..."

runner_file = 'scripts/run_database_optimizations.rb'

runner_content = <<~RUBY
  #!/usr/bin/env ruby
  # Run Database Optimization Migrations
  # Week 1 Days 3-4
  
  require 'pg'
  
  def run_migration
    conn = PG.connect(
      host: ENV['DATABASE_HOST'] || 'localhost',
      dbname: ENV['DATABASE_NAME'] || 'meme_explorer_production',
      user: ENV['DATABASE_USER'],
      password: ENV['DATABASE_PASSWORD']
    )
    
    puts "Connected to database: #{conn.db}"
    puts "Running critical indexes migration..."
    
    sql = File.read('db/migrations/add_critical_indexes_week1_2026.sql')
    conn.exec(sql)
    
    puts "✓ Migration completed successfully!"
    puts ""
    puts "Indexes created:"
    result = conn.exec("SELECT indexname FROM pg_indexes WHERE tablename IN ('memes', 'users', 'user_likes', 'viewing_history', 'sessions') ORDER BY indexname")
    result.each { |row| puts "  - #{row['indexname']}" }
    
  rescue PG::Error => e
    puts "✗ Migration failed: #{e.message}"
    exit 1
  ensure
    conn&.close
  end
  
  if __FILE__ == $0
    run_migration
  end
RUBY

File.write(runner_file, runner_content)
File.chmod(runner_file, 0755)
puts "   ✓ Created: #{runner_file}"

puts ""
puts "="*80
puts "SUMMARY - DAYS 3-4"
puts "="*80
puts ""
puts "✓ Database connection pool configuration created"
puts "✓ Critical indexes migration generated"
puts "✓ Connection pool monitoring helper created"
puts "✓ Query timeout protection implemented"
puts "✓ Migration runner script created"
puts ""
puts "⚠ DEPLOYMENT STEPS:"
puts "  1. Review database.yml configuration"
puts "  2. Set environment variables (DATABASE_HOST, DATABASE_USER, etc.)"
puts "  3. Run: ruby scripts/run_database_optimizations.rb"
puts "  4. Monitor connection pool with ConnectionPoolMonitor.stats"
puts "  5. Test query timeouts under load"
puts ""
puts "NEXT: Days 5-7 - Security Hardening & Error Handling"
puts "="*80

puts ""
puts "Execution completed: #{Time.now}"
