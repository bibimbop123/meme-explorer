# Standardized Error Handling
# P1 Fix: Replace bare rescue blocks with structured error handling

module StandardErrorHandling
  # Categorize errors for appropriate handling
  module ErrorCategories
    RETRYABLE = [
      PG::ConnectionBad,
      PG::UnableToSend,
      Redis::ConnectionError,
      Redis::TimeoutError,
      Timeout::Error
    ].freeze
    
    CLIENT_ERROR = [
      JSON::ParserError,
      ArgumentError,
      TypeError
    ].freeze
    
    NOT_FOUND = [
      ActiveRecord::RecordNotFound,
      Sinatra::NotFound
    ].freeze
  end
  
  # Execute block with comprehensive error handling
  def with_error_handling(context: {}, log_level: :error)
    yield
  rescue *ErrorCategories::NOT_FOUND => e
    handle_not_found_error(e, context)
  rescue *ErrorCategories::CLIENT_ERROR => e
    handle_client_error(e, context)
  rescue *ErrorCategories::RETRYABLE => e
    handle_retryable_error(e, context)
  rescue => e
    handle_unexpected_error(e, context, log_level)
  end
  
  # Handle 404 errors
  def handle_not_found_error(error, context)
    AppLogger.warn("Resource not found", 
      error: error.message,
      context: context,
      request_path: request.path_info
    )
    halt 404, { error: "Not found" }.to_json
  end
  
  # Handle client errors (400 Bad Request)
  def handle_client_error(error, context)
    AppLogger.warn("Client error", 
      error: error.message,
      error_class: error.class.name,
      context: context
    )
    halt 400, { error: "Bad request", message: error.message }.to_json
  end
  
  # Handle retryable errors (503 Service Unavailable)
  def handle_retryable_error(error, context)
    AppLogger.error("Service temporarily unavailable", 
      error: error.message,
      error_class: error.class.name,
      context: context,
      backtrace: error.backtrace.first(5)
    )
    halt 503, { 
      error: "Service temporarily unavailable", 
      message: "Please try again in a moment" 
    }.to_json
  end
  
  # Handle unexpected errors (500 Internal Server Error)
  def handle_unexpected_error(error, context, log_level)
    # Log with full context
    log_data = {
      error: error.message,
      error_class: error.class.name,
      context: context,
      backtrace: error.backtrace.first(10),
      request_path: (request.path_info rescue 'unknown'),
      request_params: (params rescue {})
    }
    
    case log_level
    when :fatal
      AppLogger.fatal("Fatal error occurred", log_data)
    when :error
      AppLogger.error("Unexpected error occurred", log_data)
    else
      AppLogger.warn("Error occurred", log_data)
    end
    
    # Send to error tracking service (Sentry, etc.)
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: context)
    end
    
    halt 500, { error: "Internal server error" }.to_json
  end
  
  # Retry block with exponential backoff
  def with_retry(max_attempts: AppConfig::RETRY_MAX_ATTEMPTS, backoff_base: AppConfig::RETRY_BACKOFF_BASE)
    attempts = 0
    begin
      attempts += 1
      yield
    rescue *ErrorCategories::RETRYABLE => e
      if attempts < max_attempts
        wait_time = backoff_base ** attempts
        AppLogger.warn("Retrying after error", 
          attempt: attempts, 
          max_attempts: max_attempts, 
          wait_time: wait_time,
          error: e.message
        )
        sleep(wait_time)
        retry
      else
        raise
      end
    end
  end
end
