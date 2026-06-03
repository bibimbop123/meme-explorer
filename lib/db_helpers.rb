# Database-agnostic helper methods for PostgreSQL and SQLite compatibility
module DbHelpers
  # Returns true if using PostgreSQL, false if using SQLite
  def using_postgres?
    defined?(DATABASE_URL) && DATABASE_URL&.start_with?("postgres")
  end
  
  # Database-agnostic date comparison for "column < NOW() - interval"
  # Usage: date_ago('first_failed_at', days: 1)
  # Returns a SQL fragment like: "first_failed_at < (NOW() - INTERVAL '1 days')" (PostgreSQL)
  #                          or: "datetime(first_failed_at) < datetime('now', '-1 day')" (SQLite)
  def date_ago(column_name, days: nil, hours: nil)
    if using_postgres?
      # PostgreSQL syntax
      if days
        "#{column_name} < (NOW() - INTERVAL '#{days} days')"
      elsif hours
        "#{column_name} < (NOW() - INTERVAL '#{hours} hours')"
      else
        raise ArgumentError, "Must specify either days or hours"
      end
    else
      # SQLite syntax
      if days
        unit = days == 1 ? 'day' : 'days'
        "datetime(#{column_name}) < datetime('now', '-#{days} #{unit}')"
      elsif hours
        unit = hours == 1 ? 'hour' : 'hours'  
        "datetime(#{column_name}) < datetime('now', '-#{hours} #{unit}')"
      else
        raise ArgumentError, "Must specify either days or hours"
      end
    end
  end
  
  module_function :using_postgres?, :date_ago
end
