# Timezone Helper Module
# P1 Fix: Ensure consistent timezone handling across application

require 'time'

module TimezoneHelper
  # Application timezone (UTC for consistency)
  APP_TIMEZONE = 'UTC'
  
  # Get current time in application timezone
  def current_time_utc
    Time.now.utc
  end
  
  # Parse time string with timezone awareness
  def parse_time_safe(time_string, default: nil)
    return default if time_string.nil? || time_string.to_s.strip.empty?
    
    begin
      Time.parse(time_string).utc
    rescue ArgumentError => e
      AppLogger.warn("Failed to parse time", time_string: time_string, error: e.message)
      default || current_time_utc
    end
  end
  
  # Calculate hours between two times (timezone-safe)
  def hours_between(start_time, end_time = nil)
    end_time ||= current_time_utc
    
    start_utc = ensure_utc(start_time)
    end_utc = ensure_utc(end_time)
    
    ((end_utc - start_utc) / 3600.0).abs
  end
  
  # Ensure time is in UTC
  def ensure_utc(time)
    case time
    when Time
      time.utc
    when String
      parse_time_safe(time, default: current_time_utc)
    when Integer
      Time.at(time).utc
    else
      current_time_utc
    end
  end
  
  # Format time for database storage (ISO 8601 UTC)
  def format_for_db(time = nil)
    time = time ? ensure_utc(time) : current_time_utc
    time.iso8601
  end
  
  # Calculate wait time with timezone safety (for spaced repetition)
  def calculate_wait_hours(shown_count, base: AppConfig::SPACED_REPETITION_BASE)
    base ** (shown_count - 1)
  end
  
  # Check if enough time has passed since last shown
  def should_show_again?(last_shown_time, shown_count)
    return true if last_shown_time.nil?
    
    last_shown = ensure_utc(last_shown_time)
    hours_since = hours_between(last_shown)
    required_hours = calculate_wait_hours(shown_count)
    
    hours_since >= required_hours
  end
end
