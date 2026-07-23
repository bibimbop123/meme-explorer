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
