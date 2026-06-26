#!/usr/bin/env ruby
# P2 FIXES - Complete Implementation
# Based on P2_IMPLEMENTATION_PLAN.md and SENIOR_DEV_FINAL_AUDIT_2026.md
# Senior Ruby on Sinatra Developer with 50+ Years Experience
# Run with: ruby scripts/apply_p2_fixes.rb

require 'fileutils'
require 'time'

puts "=" * 80
puts "🎯 EXECUTING P2 FIXES - COMPLETE IMPLEMENTATION"
puts "Senior Ruby on Sinatra Developer with 50+ Years Experience"
puts "=" * 80
puts ""

# Create backup directory
backup_dir = "backups/p2_fixes_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.mkdir_p(backup_dir)
puts "✅ Created backup directory: #{backup_dir}"
puts ""

# Track fixes applied
fixes_applied = []
fixes_failed = []

# =============================================================================
# P2 WEEK 2: SQL Query Optimization 
# =============================================================================
puts "📊 P2 Week 2: SQL Query Optimization"
puts "-" * 80

# Fix: Move trending sort from Ruby to SQL
trending_service_optimized = <<~'RUBY'
  # lib/services/trending_service.rb
  # P2 OPTIMIZATION: Move sorting to database layer
  
  module TrendingService
    extend self
    
    # Calculate trending score in SQL, not Ruby
    def get_trending_memes(limit: 50, time_window_hours: 24)
      cutoff_time = Time.now - (time_window_hours * 3600)
      
      # OPTIMIZED: Scoring done in SQL with proper indexes
      query = <<~SQL
        SELECT 
          url,
          title,
          subreddit,
          views,
          likes,
          created_at,
          updated_at,
          -- Trending score: likes * 2 + views, with time decay
          (likes * 2.0 + views) * 
          EXP(-0.05 * EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at)) / 3600.0) AS trending_score
        FROM meme_stats
        WHERE updated_at >= $1
          AND views > 0
        ORDER BY trending_score DESC, updated_at DESC
        LIMIT $2
      SQL
      
      DB_POOL.with do |conn|
        conn.exec_params(query, [cutoff_time, limit])
          .map { |row| row.transform_keys(&:to_sym) }
      end
    rescue => e
      AppLogger.error("Trending query failed", error: e.message, backtrace: e.backtrace.first(3))
      []
    end
    
    # Get trending by category with SQL aggregation
    def get_trending_by_category(category, limit: 30)
      query = <<~SQL
        SELECT 
          m.*,
          (m.likes * 2.0 + m.views) * 
          EXP(-0.05 * EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - m.updated_at)) / 3600.0) AS score
        FROM meme_stats m
        WHERE m.subreddit = $1
          AND m.updated_at >= CURRENT_TIMESTAMP - INTERVAL '48 hours'
        ORDER BY score DESC
        LIMIT $2
      SQL
      
      DB_POOL.with do |conn|
        conn.exec_params(query, [category, limit])
          .map { |row| row.transform_keys(&:to_sym) }
      end
    rescue => e
      AppLogger.warn("Category trending failed", category: category, error: e.message)
      []
    end
    
    # Aggregate stats at database level
    def get_aggregate_stats
      query = <<~SQL
        SELECT 
          COUNT(DISTINCT url) as total_memes,
          SUM(views) as total_views,
          SUM(likes) as total_likes,
          AVG(likes::float / NULLIF(views, 0)) as avg_like_rate,
          COUNT(DISTINCT subreddit) as total_subreddits
        FROM meme_stats
        WHERE updated_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
      SQL
      
      DB_POOL.with do |conn|
        result = conn.exec(query)
        result[0] if result.ntuples > 0
      end
    rescue => e
      AppLogger.error("Stats aggregation failed", error: e.message)
      {}
    end
    
    # Cache trending results with proper TTL
    def cached_trending(time_window: 24, cache_ttl: 300)
      cache_key = "trending:#{time_window}h"
      
      cached = RedisService.get(cache_key) rescue nil
      return JSON.parse(cached) if cached
      
      trending = get_trending_memes(time_window_hours: time_window)
      RedisService.setex(cache_key, cache_ttl, trending.to_json) rescue nil
      
      trending
    end
  end
RUBY

begin
  FileUtils.cp('lib/services/trending_service.rb', "#{backup_dir}/trending_service.rb.bak") if File.exist?('lib/services/trending_service.rb')
  File.write('lib/services/trending_service.rb', trending_service_optimized)
  puts "   ✓ Optimized TrendingService with SQL-level calculations"
  fixes_applied << "SQL optimization: TrendingService"
rescue => e
  puts "   ✗ Failed to optimize TrendingService: #{e.message}"
  fixes_failed << "TrendingService optimization"
end

# =============================================================================
# P2: Enhanced Leaderboard Service with SQL Aggregation
# =============================================================================
puts "\n🏆 P2: Leaderboard SQL Optimization"

leaderboard_optimized = <<~'RUBY'
  # lib/services/leaderboard_service.rb
  # P2 OPTIMIZATION: Complex calculations in SQL, not Ruby
  
  module LeaderboardService
    extend self
    
    # Calculate leaderboard with SQL aggregation
    def get_leaderboard(limit: 100, min_level: 1)
      query = <<~SQL
        WITH user_stats AS (
          SELECT 
            u.id,
            u.username,
            u.level,
            u.xp,
            u.streak_days,
            u.total_likes_given,
            u.total_memes_saved,
            -- Calculate engagement score in SQL
            (u.total_likes_given * 1.0 + u.total_memes_saved * 2.0 + u.streak_days * 5.0) AS engagement_score,
            -- Rank users by level and XP
            RANK() OVER (ORDER BY u.level DESC, u.xp DESC) AS rank
          FROM users u
          WHERE u.role != 'admin'
            AND u.level >= $1
        )
        SELECT * FROM user_stats
        ORDER BY rank ASC
        LIMIT $2
      SQL
      
      DB_POOL.with do |conn|
        conn.exec_params(query, [min_level, limit])
          .map { |row| row.transform_keys(&:to_sym) }
      end
    rescue => e
      AppLogger.error("Leaderboard query failed", error: e.message)
      []
    end
    
    # Get user rank efficiently with single query
    def get_user_rank(user_id)
      query = <<~SQL
        WITH ranked_users AS (
          SELECT 
            id,
            RANK() OVER (ORDER BY level DESC, xp DESC) AS rank
          FROM users
          WHERE role != 'admin'
        )
        SELECT rank FROM ranked_users WHERE id = $1
      SQL
      
      DB_POOL.with do |conn|
        result = conn.exec_params(query, [user_id])
        result[0]['rank'].to_i if result.ntuples > 0
      end
    rescue => e
      AppLogger.warn("User rank query failed", user_id: user_id, error: e.message)
      nil
    end
    
    # Periodic leaderboard cache refresh
    def refresh_leaderboard_cache
      leaderboard = get_leaderboard(limit: 100)
      RedisService.setex('leaderboard:top100', 600, leaderboard.to_json) # 10 min TTL
      leaderboard
    rescue => e
      AppLogger.error("Leaderboard cache refresh failed", error: e.message)
      []
    end
  end
RUBY

begin
  FileUtils.cp('lib/services/leaderboard_service.rb', "#{backup_dir}/leaderboard_service.rb.bak") if File.exist?('lib/services/leaderboard_service.rb')
  File.write('lib/services/leaderboard_service.rb', leaderboard_optimized)
  puts "   ✓ Optimized LeaderboardService with SQL window functions"
  fixes_applied << "SQL optimization: LeaderboardService"
rescue => e
  puts "   ✗ Failed to optimize LeaderboardService: #{e.message}"
  fixes_failed << "LeaderboardService optimization"
end

# =============================================================================
# P2: Search Results with SQL Relevance Scoring
# =============================================================================
puts "\n🔍 P2: Search Optimization with Relevance Scoring"

search_optimization_helper = <<~'RUBY'
  # lib/helpers/search_optimization_helpers.rb
  # P2: Add relevance scoring to search results
  
  module SearchOptimizationHelpers
    # Search with relevance scoring (PostgreSQL specific)
    def search_memes_with_relevance(query, limit: 100)
      sanitized = sanitize_search_query(query)
      
      sql = <<~SQL
        SELECT 
          url,
          title,
          subreddit,
          views,
          likes,
          created_at,
          -- Relevance scoring: exact matches score higher
          CASE 
            WHEN LOWER(title) = LOWER($1) THEN 100
            WHEN LOWER(title) LIKE LOWER($1) || '%' THEN 90
            WHEN LOWER(title) LIKE '%' || LOWER($1) || '%' THEN 80
            ELSE 70
          END +
          -- Boost popular memes
          (likes * 0.1 + views * 0.01) AS relevance_score
        FROM meme_stats
        WHERE LOWER(title) LIKE '%' || LOWER($1) || '%'
        ORDER BY relevance_score DESC, updated_at DESC
        LIMIT $2
      SQL
      
      DB_POOL.with do |conn|
        conn.exec_params(sql, [sanitized, limit])
          .map { |row| row.transform_keys(&:to_sym) }
      end
    rescue => e
      AppLogger.error("Search with relevance failed", query: query, error: e.message)
      fallback_search(query, limit)
    end
    
    # Fallback to simple search if relevance scoring fails
    def fallback_search(query, limit)
      sql = "SELECT * FROM meme_stats WHERE LOWER(title) LIKE '%' || LOWER($1) || '%' LIMIT $2"
      
      DB_POOL.with do |conn|
        conn.exec_params(sql, [sanitize_search_query(query), limit])
          .map { |row| row.transform_keys(&:to_sym) }
      end
    rescue => e
      AppLogger.error("Fallback search failed", error: e.message)
      []
    end
    
    # Sanitize search query to prevent SQL injection and ReDoS
    def sanitize_search_query(query)
      return "" if query.nil?
      
      # Remove null bytes and control characters
      cleaned = query.to_s.gsub(/[\x00-\x1F\x7F]/, '').strip
      
      # Limit length to prevent ReDoS
      cleaned = cleaned[0...200] if cleaned.length > 200
      
      # Remove dangerous patterns
      cleaned.gsub(/[%_\\]/, '') # Remove SQL LIKE wildcards
    end
  end
RUBY

begin
  File.write('lib/helpers/search_optimization_helpers.rb', search_optimization_helper)
  puts "   ✓ Created search optimization helpers with relevance scoring"
  fixes_applied << "Search optimization with relevance scoring"
rescue => e
  puts "   ✗ Failed to create search helpers: #{e.message}"
  fixes_failed << "Search optimization"
end

# =============================================================================
# P2: Thread-Safe Metrics (CRITICAL FIX)
# =============================================================================
puts "\n🔒 P2 CRITICAL: Thread-Safe Metrics Implementation"

thread_safe_metrics = <<~'RUBY'
  # lib/services/thread_safe_metrics.rb
  # P2 CRITICAL FIX: Thread-safe metrics to prevent race conditions
  
  require 'concurrent'
  
  module ThreadSafeMetrics
    class Collector
      def initialize
        @metrics = Concurrent::Hash.new
        @request_count = Concurrent::AtomicFixnum.new(0)
        @total_duration = Concurrent::AtomicReference.new(0.0)
        @lock = Mutex.new
      end
      
      # Thread-safe increment
      def increment(key, amount = 1)
        @metrics.compute(key) do |old_value|
          (old_value || 0) + amount
        end
      end
      
      # Thread-safe set
      def set(key, value)
        @metrics[key] = value
      end
      
      # Thread-safe get
      def get(key, default = 0)
        @metrics.fetch(key, default)
      end
      
      # Record request timing with atomic operations
      def record_request(duration_ms)
        count = @request_count.increment
        
        # Update average with thread-safe operations
        @lock.synchronize do
          current_total = @total_duration.value
          new_total = current_total + duration_ms
          @total_duration.set(new_total)
        end
        
        count
      end
      
      # Get average request time (thread-safe)
      def avg_request_time_ms
        @lock.synchronize do
          count = @request_count.value
          return 0.0 if count.zero?
          @total_duration.value / count.to_f
        end
      end
      
      # Get all metrics snapshot (thread-safe)
      def snapshot
        @lock.synchronize do
          {
            total_requests: @request_count.value,
            avg_request_time_ms: avg_request_time_ms,
            metrics: @metrics.dup
          }
        end
      end
      
      # Reset all metrics (thread-safe)
      def reset!
        @lock.synchronize do
          @metrics.clear
          @request_count.value = 0
          @total_duration.set(0.0)
        end
      end
    end
  end
RUBY

begin
  File.write('lib/services/thread_safe_metrics.rb', thread_safe_metrics)
  puts "   ✓ Created thread-safe metrics collector (CRITICAL)"
  fixes_applied << "CRITICAL: Thread-safe metrics"
rescue => e
  puts "   ✗ Failed to create thread-safe metrics: #{e.message}"
  fixes_failed << "CRITICAL: Thread-safe metrics"
end

# =============================================================================
# P2: Database Connection Pool Size Fix (CRITICAL)
# =============================================================================
puts "\n💾 P2 CRITICAL: Database Connection Pool Optimization"

db_setup_fix = <<~'RUBY'
  # db/setup.rb
  # P2 CRITICAL FIX: Increase connection pool to match Puma threads
  
  require 'pg'
  require 'connection_pool'
  
  # Database URL from environment
  DATABASE_URL = ENV['DATABASE_URL'] || ENV['POSTGRES_URL'] || 'postgresql://localhost/meme_explorer_development'
  
  # CRITICAL FIX: Pool size must be >= Puma max_threads (32) + buffer
  # Previous: 25 connections for 32 threads = 7 requests will block
  # Fixed: 35 connections (32 threads + 3 buffer for migrations/workers)
  DB_POOL = ConnectionPool.new(size: 35, timeout: 5) do
    conn = PG.connect(DATABASE_URL)
    
    # Configure connection for optimal performance
    conn.exec("SET application_name = 'meme_explorer'")
    conn.exec("SET statement_timeout = '30s'") # Prevent runaway queries
    conn.exec("SET idle_in_transaction_session_timeout = '60s'")
    
    conn
  end
  
  # Convenience method for queries
  DB = DB_POOL
  
  # Health check for connection pool
  def self.check_db_health
    DB_POOL.with do |conn|
      result = conn.exec("SELECT 1 as healthy")
      result[0]['healthy'] == '1'
    end
  rescue => e
    false
  end
  
  puts "✅ Database connection pool configured: 35 connections for 32 Puma threads"
RUBY

begin
  FileUtils.cp('db/setup.rb', "#{backup_dir}/setup.rb.bak") if File.exist?('db/setup.rb')
  File.write('db/setup.rb', db_setup_fix)
  puts "   ✓ Fixed database connection pool size: 25 → 35 (CRITICAL)"
  fixes_applied << "CRITICAL: DB connection pool 25→35"
rescue => e
  puts "   ✗ Failed to fix DB pool: #{e.message}"
  fixes_failed << "CRITICAL: DB pool size"
end

# =============================================================================
# P2: Query Optimization Index Recommendations
# =============================================================================
puts "\n📈 P2: Additional Performance Indexes"

additional_indexes = <<~SQL
  -- P2 Performance Indexes
  -- Optimizes trending, search, and leaderboard queries
  -- Generated: #{Time.now}
  
  -- For trending score calculations (used in TrendingService)
  CREATE INDEX IF NOT EXISTS idx_meme_stats_trending_calc 
    ON meme_stats(updated_at DESC, likes DESC, views DESC) 
    WHERE updated_at >= CURRENT_TIMESTAMP - INTERVAL '48 hours';
  
  -- For search relevance scoring
  CREATE INDEX IF NOT EXISTS idx_meme_stats_title_gin 
    ON meme_stats USING gin(to_tsvector('english', title));
  
  -- For leaderboard window function queries
  CREATE INDEX IF NOT EXISTS idx_users_leaderboard_rank 
    ON users(level DESC, xp DESC, id) 
    WHERE role != 'admin';
  
  -- For category-based trending
  CREATE INDEX IF NOT EXISTS idx_meme_stats_category_trending 
    ON meme_stats(subreddit, updated_at DESC, likes DESC)
    WHERE updated_at >= CURRENT_TIMESTAMP - INTERVAL '48 hours';
  
  -- For user engagement calculations
  CREATE INDEX IF NOT EXISTS idx_users_engagement 
    ON users(total_likes_given, total_memes_saved, streak_days)
    WHERE role != 'admin';
  
  -- Composite index for common query patterns
  CREATE INDEX IF NOT EXISTS idx_meme_stats_hot 
    ON meme_stats(updated_at, likes, views) 
    WHERE views > 0 AND likes > 0;
SQL

begin
  File.write('db/migrations/add_p2_performance_indexes.sql', additional_indexes)
  puts "   ✓ Created P2 performance indexes migration"
  fixes_applied << "P2 performance indexes"
rescue => e
  puts "   ✗ Failed to create index migration: #{e.message}"
  fixes_failed << "P2 performance indexes"
end

# =============================================================================
# P2: Migration Runner for New Indexes
# =============================================================================
puts "\n🔧 P2: Creating Index Migration Runner"

index_runner = <<~'RUBY'
  #!/usr/bin/env ruby
  # Run P2 performance index migrations
  
  require_relative '../db/setup'
  
  puts "=" * 80
  puts "Running P2 Performance Index Migrations"
  puts "=" * 80
  puts ""
  
  sql = File.read('db/migrations/add_p2_performance_indexes.sql')
  
  # Split on semicolons and execute each statement
  statements = sql.split(';').map(&:strip).reject { |s| s.empty? || s.start_with?('--') }
  
  success_count = 0
  error_count = 0
  
  statements.each do |stmt|
    begin
      DB_POOL.with { |conn| conn.exec(stmt) }
      # Extract index name for logging
      index_name = stmt[/idx_\w+/i]
      puts "✓ Created: #{index_name}" if index_name
      success_count += 1
    rescue => e
      puts "⚠️  Warning: #{e.message}"
      error_count += 1
    end
  end
  
  puts ""
  puts "=" * 80
  puts "Migration Complete!"
  puts "  ✓ Success: #{success_count} indexes"
  puts "  ⚠️  Errors: #{error_count}" if error_count > 0
  puts "=" * 80
RUBY

begin
  File.write('scripts/run_p2_indexes.rb', index_runner)
  FileUtils.chmod(0755, 'scripts/run_p2_indexes.rb')
  puts "   ✓ Created scripts/run_p2_indexes.rb"
  fixes_applied << "P2 index runner script"
rescue => e
  puts "   ✗ Failed to create runner: #{e.message}"
  fixes_failed << "P2 index runner"
end

# =============================================================================
# Summary
# =============================================================================
puts "\n"
puts "=" * 80
puts "P2 FIXES EXECUTION COMPLETE"
puts "=" * 80
puts ""
puts "✅ Fixes Applied (#{fixes_applied.length}):"
fixes_applied.each { |fix| puts "   • #{fix}" }

if fixes_failed.any?
  puts ""
  puts "❌ Fixes Failed (#{fixes_failed.length}):"
  fixes_failed.each { |fix| puts "   • #{fix}" }
end

puts ""
puts "📁 Backups saved to: #{backup_dir}"
puts ""
puts "🚀 NEXT STEPS:"
puts "   1. Run: ruby scripts/run_p2_indexes.rb"
puts "   2. Test endpoints: bundle exec rackup config.ru -p 3000"
puts "   3. Monitor metrics and logs"
puts "   4. Deploy to production when ready"
puts ""
puts "=" * 80
