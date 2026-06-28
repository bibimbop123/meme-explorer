# frozen_string_literal: true

# Database Read Replica Configuration
# PostgreSQL-only (migrated from SQLite3)

require 'pg'
require 'connection_pool'

# Primary DB_POOL is defined in db/setup.rb — do not redefine it here.
# This initializer sets up an optional read replica pool.

if ENV['DATABASE_REPLICA_URL']
  DB_REPLICA = ConnectionPool.new(size: 50, timeout: 5) do
    PG.connect(ENV['DATABASE_REPLICA_URL'])
  end

  AppLogger.info("Database replica configured",
    primary_pool: 35,
    replica_pool: 50
  )
else
  # No replica configured — alias replica to primary pool
  DB_REPLICA = DB_POOL

  AppLogger.info("No database replica configured, using primary for all queries")
end

# Health check for replica — intentional long-lived monitoring thread
@replica_health_thread = Thread.new do
  Thread.current.name = 'db-replica-health'
  Thread.current.abort_on_exception = false
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
