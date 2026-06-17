# frozen_string_literal: true

# Database Read Replica Configuration
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.2

require 'connection_pool'

# Primary database (for writes)
DB_POOL ||= ConnectionPool.new(size: 25, timeout: 5) do
  if ENV['DATABASE_URL']&.include?('postgres')
    require 'pg'
    PG.connect(ENV['DATABASE_URL'])
  else
    require 'sqlite3'
    SQLite3::Database.new(ENV['DATABASE_URL'] || 'db/meme_explorer.db')
  end
end

# Read replica (for reads)
if ENV['DATABASE_REPLICA_URL']
  DB_REPLICA = ConnectionPool.new(size: 50, timeout: 5) do
    if ENV['DATABASE_REPLICA_URL'].include?('postgres')
      require 'pg'
      PG.connect(ENV['DATABASE_REPLICA_URL'])
    else
      require 'sqlite3'
      SQLite3::Database.new(ENV['DATABASE_REPLICA_URL'])
    end
  end

  AppLogger.info("Database replica configured", 
    primary_pool: 25,
    replica_pool: 50
  )
else
  # No replica configured, use primary for reads
  DB_REPLICA = DB_POOL
  
  AppLogger.info("No database replica configured, using primary for all queries")
end

# Health check for replica
Thread.new do
  loop do
    sleep 60 # Check every minute
    
    begin
      lag = DatabaseRouter.replica_lag
      if lag
        if lag > 30
          AppLogger.error("High replica lag detected", lag_seconds: lag)
          DatabaseRouter.disable_replica!
        elsif lag < 5 && DatabaseRouter.instance_variable_get(:@replica_disabled)
          AppLogger.info("Replica lag recovered", lag_seconds: lag)
          DatabaseRouter.enable_replica!
        end
      end
    rescue => e
      AppLogger.error("Replica health check failed", error: e.message)
    end
  end
end if ENV['DATABASE_REPLICA_URL']
