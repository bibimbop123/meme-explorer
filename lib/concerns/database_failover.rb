# frozen_string_literal: true

# Database Failover Module
# Handles read replica failures gracefully by falling back to primary
# Part of Phase 2 performance optimization

module DatabaseFailover
  class << self
    attr_accessor :replica_enabled, :failover_count, :last_failover_at
    
    def initialize_failover
      @replica_enabled = ENV['DATABASE_REPLICA_URL'].present?
      @failover_count = 0
      @last_failover_at = nil
      @replica_check_interval = 60 # Check every 60 seconds
      @last_replica_check = Time.now
    end

    # Execute query with automatic failover
    def with_failover(prefer_replica: true)
      # If no replica configured, always use primary
      return yield(:primary) unless replica_enabled?

      # If we recently failed over, stick with primary temporarily
      if recently_failed_over?
        return yield(:primary)
      end

      # Try replica first for read queries
      if prefer_replica
        begin
          result = yield(:replica)
          reset_failover_state # Replica working again
          return result
        rescue Sequel::DatabaseConnectionError, PG::ConnectionBad => e
          handle_replica_failure(e)
          # Fall through to primary
        end
      end

      # Use primary (either by preference or after replica failure)
      yield(:primary)
    end

    # Check if replica is healthy
    def replica_healthy?
      return false unless replica_enabled?
      return @replica_healthy if recently_checked?

      @last_replica_check = Time.now
      
      begin
        DB.with_server(:replica) do
          DB.fetch('SELECT 1 AS health_check').first
        end
        @replica_healthy = true
      rescue => e
        AppLogger.warn("Replica health check failed: #{e.message}")
        @replica_healthy = false
      end
      
      @replica_healthy
    end

    # Get replica lag in seconds
    def replica_lag_seconds
      return nil unless replica_enabled?
      
      begin
        DB.with_server(:replica) do
          result = DB.fetch(
            "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag"
          ).first
          result[:lag].to_f
        end
      rescue => e
        AppLogger.error("Failed to check replica lag: #{e.message}")
        nil
      end
    end

    # Check if we're currently in recovery (replica)
    def in_recovery?
      begin
        DB.with_server(:replica) do
          result = DB.fetch('SELECT pg_is_in_recovery() AS in_recovery').first
          result[:in_recovery]
        end
      rescue
        false
      end
    end

    # Get failover statistics
    def stats
      {
        replica_enabled: replica_enabled?,
        replica_healthy: replica_healthy?,
        failover_count: @failover_count || 0,
        last_failover_at: @last_failover_at,
        replica_lag_seconds: replica_lag_seconds,
        in_recovery: in_recovery?
      }
    end

    private

    def replica_enabled?
      @replica_enabled ||= ENV['DATABASE_REPLICA_URL'].present?
    end

    def recently_failed_over?
      return false unless @last_failover_at
      Time.now - @last_failover_at < 300 # Stay on primary for 5 minutes after failover
    end

    def recently_checked?
      return false unless @last_replica_check
      Time.now - @last_replica_check < @replica_check_interval
    end

    def handle_replica_failure(error)
      @failover_count ||= 0
      @failover_count += 1
      @last_failover_at = Time.now
      
      AppLogger.error(
        "Database replica failure (failover ##{@failover_count}): #{error.message}",
        error: error.class.name,
        failover_count: @failover_count
      )
      
      # Alert if too many failovers
      if @failover_count > 10
        AppLogger.critical("Excessive database failovers detected: #{@failover_count}")
      end
    end

    def reset_failover_state
      # Only reset if we've been in failover mode
      if @failover_count && @failover_count > 0
        AppLogger.info("Replica recovered, resetting failover state (was #{@failover_count} failovers)")
        @failover_count = 0
        @last_failover_at = nil
      end
    end
  end
end

# Initialize on load
DatabaseFailover.initialize_failover

# Helper methods for easy usage
module Sequel
  class Dataset
    # Use this to force primary for important reads
    def with_primary
      db.with_server(:primary) { yield(self) }
    end

    # Use this to prefer replica but fallback to primary
    def with_replica_failover
      DatabaseFailover.with_failover(prefer_replica: true) do |server|
        db.with_server(server) { yield(self) }
      end
    end
  end
end
