# frozen_string_literal: true

# Transaction Wrapper for Multi-Step Database Operations
# Ensures ACID properties for complex operations
# Senior Dev Pattern: Always wrap multi-step DB operations in transactions

module TransactionWrapper
  # Execute multiple DB operations in a transaction
  # Automatically rolls back on any error
  #
  # @param connection [Object] Database connection (defaults to DB)
  # @yield Block containing database operations
  # @return [Object] Result of the block
  # @raise [StandardError] Any error from the block (after rollback)
  #
  # Example:
  #   with_transaction do
  #     DB.execute("INSERT INTO meme_stats ...")
  #     DB.execute("UPDATE user_stats ...")
  #   end
  def with_transaction(connection = DB, &block)
    # Check if we're already in a transaction (avoid nested transactions)
    if connection.respond_to?(:in_transaction?) && connection.in_transaction?
      AppLogger.debug('transaction_nested', {
        message: 'Already in transaction, executing without new transaction'
      })
      return yield
    end

    start_time = Time.now
    
    begin
      result = connection.transaction do
        yield
      end
      
      duration_ms = ((Time.now - start_time) * 1000).round(2)
      
      AppLogger.debug('transaction_complete', {
        duration_ms: duration_ms,
        status: 'committed'
      })
      
      result
    rescue => e
      duration_ms = ((Time.now - start_time) * 1000).round(2)
      
      AppLogger.error('transaction_failed', {
        error_class: e.class.name,
        error_message: e.message,
        backtrace: e.backtrace.first(10),
        duration_ms: duration_ms,
        status: 'rolled_back'
      })
      
      Sentry.capture_exception(e) if defined?(Sentry)
      raise
    end
  end

  # Execute with timeout protection
  # Prevents long-running transactions from blocking
  def with_transaction_timeout(timeout_seconds = 30, connection = DB, &block)
    Timeout.timeout(timeout_seconds) do
      with_transaction(connection, &block)
    end
  rescue Timeout::Error => e
    AppLogger.error('transaction_timeout', {
      timeout_seconds: timeout_seconds,
      error: 'Transaction exceeded timeout limit'
    })
    raise StandardError, "Transaction timeout after #{timeout_seconds}s"
  end

  module_function :with_transaction, :with_transaction_timeout
end
