# Database helper methods
module DbHelpers
  # Returns the global DBWrapper instance (PostgreSQL).
  # All services that previously called get_db_connection should use this.
  def get_db_connection
    DB
  end

  # Returns true — we are always on PostgreSQL in production.
  def using_postgres?
    true
  end

  # Database-agnostic date comparison for "column < NOW() - interval".
  # Always returns PostgreSQL syntax since we only support PostgreSQL.
  # Usage: date_ago('first_failed_at', days: 1)
  def date_ago(column_name, days: nil, hours: nil)
    if days
      "#{column_name} < (NOW() - INTERVAL '#{days} days')"
    elsif hours
      "#{column_name} < (NOW() - INTERVAL '#{hours} hours')"
    else
      raise ArgumentError, "Must specify either days: or hours:"
    end
  end

  module_function :get_db_connection, :using_postgres?, :date_ago
end
