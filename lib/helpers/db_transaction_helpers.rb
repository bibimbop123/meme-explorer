# frozen_string_literal: true

require_relative '../app_logger'

# DB Transaction Helpers
# Provides transaction support for atomic database operations
# Week 3 Implementation - June 3, 2026

module DBTransactionHelpers
  class << self
    # Execute block within a database transaction
    # All operations succeed or all rollback
    def transaction(&block)
      if defined?(DB.transaction) && DB.respond_to?(:transaction)
        # PostgreSQL with built-in transaction support
        DB.transaction(&block)
      elsif defined?(DB_POOL)
        # PostgreSQL with connection pool
        DB_POOL.with do |conn|
          conn.transaction do
            yield conn
          end
        end
      else
        # SQLite or fallback
        DB.execute("BEGIN TRANSACTION")
        result = yield
        DB.execute("COMMIT")
        result
      end
    rescue => e
      DB.execute("ROLLBACK") if defined?(DB)
      AppLogger.error("Transaction failed", 
        error: e.message,
        error_class: e.class.name,
        backtrace: e.backtrace&.first(5)
      )
      raise
    end
    
    # Execute multiple statements atomically
    def atomic_execute(statements_with_params)
      transaction do
        statements_with_params.each do |sql, params|
          DB.execute(sql, params || [])
        end
      end
    end
    
    # Retry transaction on deadlock/serialization failure
    def with_retry(max_attempts: 3, &block)
      attempts = 0
      begin
        attempts += 1
        transaction(&block)
      rescue => e
        if retriable_error?(e) && attempts < max_attempts
          AppLogger.warn("Transaction retry", 
            attempt: attempts,
            error: e.message
          )
          sleep(0.1 * attempts)  # Exponential backoff
          retry
        else
          raise
        end
      end
    end
    
    private
    
    def retriable_error?(error)
      error.message.match?(/deadlock|serialization failure|lock timeout/i)
    end
  end
end
