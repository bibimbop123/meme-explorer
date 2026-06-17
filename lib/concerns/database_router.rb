# frozen_string_literal: true

# Database Router for Read/Write Splitting
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.2
# Routes read queries to replicas, write queries to primary

module DatabaseRouter
  class << self
    # Execute read query on replica (if available)
    def read(&block)
      if replica_available?
        with_connection(DB_REPLICA, &block)
      else
        with_connection(DB_POOL, &block)
      end
    rescue => e
      AppLogger.warn("Replica query failed, falling back to primary", 
        error: e.message
      )
      with_connection(DB_POOL, &block)
    end

    # Execute write query on primary
    def write(&block)
      with_connection(DB_POOL, &block)
    end

    # Execute query on primary (alias for clarity)
    def primary(&block)
      with_connection(DB_POOL, &block)
    end

    # Execute in transaction (always on primary)
    def transaction(&block)
      DB_POOL.with do |conn|
        conn.transaction(&block)
      end
    end

    # Check if replica is available and healthy
    def replica_available?
      return false unless defined?(DB_REPLICA)
      return false if @replica_disabled
      
      # Check replica lag
      check_replica_health
    end

    # Disable replica (for maintenance, high lag, etc.)
    def disable_replica!
      @replica_disabled = true
      AppLogger.warn("Database replica disabled")
    end

    # Re-enable replica
    def enable_replica!
      @replica_disabled = false
      AppLogger.info("Database replica enabled")
    end

    # Get replica lag in seconds
    def replica_lag
      return nil unless replica_available?

      primary_time = read_from_primary { query_server_time }
      replica_time = read_from_replica { query_server_time }

      (primary_time - replica_time).abs
    rescue => e
      AppLogger.error("Failed to check replica lag", error: e.message)
      nil
    end

    # Force next query to use primary
    def force_primary!
      Thread.current[:force_primary] = true
    end

    # Clear force primary flag
    def clear_force_primary!
      Thread.current[:force_primary] = false
    end

    private

    def with_connection(pool, &block)
      pool.with do |conn|
        yield(conn)
      end
    end

    def check_replica_health
      # Skip check if forced to primary
      return false if Thread.current[:force_primary]

      # Check replica lag (disabled if > 10 seconds)
      lag = replica_lag
      if lag && lag > 10
        AppLogger.warn("Replica lag too high", lag_seconds: lag)
        return false
      end

      true
    rescue
      false
    end

    def query_server_time
      result = DB_POOL.with do |conn|
        conn.exec("SELECT EXTRACT(EPOCH FROM NOW()) as time")
      end
      result[0]['time'].to_f
    end

    def read_from_primary(&block)
      DB_POOL.with(&block)
    end

    def read_from_replica(&block)
      DB_REPLICA.with(&block)
    end
  end
end

# Monkey patch for automatic routing in services
module DatabaseHelpers
  def db_read(&block)
    DatabaseRouter.read(&block)
  end

  def db_write(&block)
    DatabaseRouter.write(&block)
  end

  def db_transaction(&block)
    DatabaseRouter.transaction(&block)
  end
end
