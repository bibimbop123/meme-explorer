# Structured error handling with recovery strategies
module ErrorHandler
  # Error context for logging and monitoring
  class ErrorContext
    attr_reader :error, :context, :severity, :timestamp

    def initialize(error, context = {}, severity = :warning)
      @error = error
      @context = context
      @severity = severity
      @timestamp = Time.now
    end

    def to_h
      {
        error: @error.class.name,
        message: @error.message,
        severity: @severity,
        context: @context,
        timestamp: @timestamp.iso8601,
        backtrace: @error.backtrace&.first(5)
      }
    end

    def to_s
      "[#{@severity.upcase}] #{@error.class}: #{@error.message}"
    end
  end

  # Global error logger with recovery tracking
  class Logger
    @@errors = []
    @@errors_lock = Thread::Mutex.new

    def self.log(error, context = {}, severity = :warning)
      error_ctx = ErrorContext.new(error, context, severity)
      
      # Thread-safe logging
      @@errors_lock.synchronize do
        @@errors << error_ctx.to_h
        # Keep last 1000 errors only
        @@errors.shift if @@errors.size > 1000
      end

      # Log to STDOUT with colors
      severity_color = case severity
                       when :critical then :red
                       when :error then :light_red
                       when :warning then :yellow
                       when :info then :blue
                       else :white
                       end

      puts "[#{error_ctx.timestamp.strftime('%H:%M:%S')}] #{error_ctx.to_s}".colorize(severity_color)
      puts "  Context: #{context}".colorize(:light_black) if context.any?
    end

    def self.recent(limit = 50)
      @@errors_lock.synchronize do
        @@errors.last(limit)
      end
    end

    def self.error_rate(window_seconds = 300)
      cutoff = Time.now - window_seconds
      @@errors_lock.synchronize do
        @@errors.count { |e| Time.parse(e[:timestamp]) > cutoff }
      end
    end

    def self.critical_errors(window_seconds = 300)
      cutoff = Time.now - window_seconds
      @@errors_lock.synchronize do
        @@errors.select do |e|
          e[:severity].to_sym == :critical && 
          Time.parse(e[:timestamp]) > cutoff
        end
      end
    end
  end

  # Recovery strategies for common failures
  module Recoveries
    def self.redis_unavailable(fallback_value = nil)
      Logger.log(
        StandardError.new("Redis connection failed"),
        { strategy: "Using fallback", fallback: fallback_value.class },
        :warning
      )
      fallback_value
    end

    def self.database_query_failed(query, fallback = [])
      Logger.log(
        StandardError.new("Database query failed"),
        { query: query.slice(0, 100), fallback_size: fallback.size },
        :error
      )
      fallback
    end

    def self.reddit_api_timeout(subreddit, fallback = [])
      Logger.log(
        StandardError.new("Reddit API timeout"),
        { subreddit: subreddit, fallback_count: fallback.size },
        :warning
      )
      fallback
    end

    def self.user_not_found(user_id)
      Logger.log(
        StandardError.new("User not found in database"),
        { user_id: user_id },
        :warning
      )
      nil
    end

    def self.invalid_meme_data(meme_data)
      Logger.log(
        StandardError.new("Invalid meme data received"),
        { 
          has_url: meme_data&.key?("url"),
          has_title: meme_data&.key?("title")
        },
        :error
      )
      nil
    end

    def self.image_loading_failed(image_url, attempt = 1)
      Logger.log(
        StandardError.new("Image failed to load"),
        { url: image_url.slice(0, 100), attempt: attempt },
        :info
      )
    end

    def self.oauth_token_refresh_failed(error_msg)
      Logger.log(
        StandardError.new("OAuth token refresh failed"),
        { original_error: error_msg },
        :error
      )
    end
  end
end
