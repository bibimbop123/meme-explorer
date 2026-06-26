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

# DB Wrapper class to make connection pool usage transparent
class DBWrapper
  def initialize(pool)
    @pool = pool
  end
  
  # Execute SQL and return all results
  def execute(sql, params = [])
    @pool.with do |conn|
      result = conn.exec_params(sql, params)
      # Convert PG::Result to array of hashes (compatible with SQLite3 interface)
      result.map { |row| row }
    end
  end
  
  # Execute SQL and return first column of first row (like SQLite3's get_first_value)
  def get_first_value(sql, params = [])
    @pool.with do |conn|
      result = conn.exec_params(sql, params)
      return nil if result.ntuples == 0
      result[0].values.first
    end
  end
  
  # For backwards compatibility with code that checks connection status
  def closed?
    false
  end
end

# Create wrapped DB instance
DB = DBWrapper.new(DB_POOL)

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
