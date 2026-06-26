# frozen_string_literal: true

# Query Timeout Helpers
# Protects against slow queries blocking application threads
module QueryTimeoutHelpers
  # Default timeouts for different operation types
  QUERY_TIMEOUTS = {
    fast: 1,      # Simple lookups
    normal: 5,    # Standard queries
    slow: 15,     # Complex aggregations
    bulk: 30      # Batch operations
  }.freeze

  # Execute query with timeout protection
  def with_query_timeout(seconds = 5, &block)
    Timeout.timeout(seconds) do
      yield
    rescue Timeout::Error => e
      AppLogger.error('query_timeout', {
        timeout_seconds: seconds,
        error: e.message,
        backtrace: e.backtrace.first(5)
      })
      raise
    end
  end

  # Execute database query with timeout
  def db_execute_with_timeout(sql, params = [], timeout: :normal)
    timeout_seconds = QUERY_TIMEOUTS[timeout] || 5
    
    with_query_timeout(timeout_seconds) do
      if defined?(DB)
        DB.execute(sql, params)
      else
        # For direct PG connection
        conn.exec_params(sql, params)
      end
    end
  rescue Timeout::Error
    AppLogger.error('database_query_timeout', {
      sql: sql.gsub(/ +/, ' ').strip[0..200],
      timeout_seconds: timeout_seconds
    })
    []  # Return empty result on timeout
  end

  # Set PostgreSQL statement timeout for a block
  def with_pg_statement_timeout(timeout_seconds = 5)
    if defined?(DB)
      DB.execute("SET LOCAL statement_timeout = '#{timeout_seconds}s'")
      yield
    else
      yield
    end
  ensure
    if defined?(DB)
      DB.execute("SET LOCAL statement_timeout = DEFAULT")
    end
  end
end
