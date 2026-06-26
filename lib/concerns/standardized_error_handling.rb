# frozen_string_literal: true

# Standardized Error Handling Module
# Replaces 300+ bare rescue blocks with proper error tracking
module StandardizedErrorHandling
  # Standard error handler with context
  def handle_error(error, context = {})
    error_data = {
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace&.first(10) || [],
      context: context,
      timestamp: Time.now.iso8601,
      request_id: defined?(request) ? request.env['HTTP_X_REQUEST_ID'] : nil
    }
    
    # Log with appropriate level
    if critical_error?(error)
      AppLogger.error('critical_error', error_data)
    else
      AppLogger.warn('handled_error', error_data)
    end
    
    # Send to Sentry if available
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: context)
    end
    
    error_data
  end
  
  # Wrap code block with standardized error handling
  def with_error_handling(context = {}, default_return: nil)
    yield
  rescue => e
    handle_error(e, context)
    default_return
  end
  
  # Async operation error handler (for workers)
  def handle_worker_error(error, worker_name:, job_data: {})
    handle_error(error, {
      worker: worker_name,
      job_data: job_data,
      worker_context: true
    })
  end
  
  # Database operation error handler
  def handle_db_error(error, query: nil, params: [])
    handle_error(error, {
      operation: 'database',
      query: query&.gsub(/\s+/, ' ')&.strip&.slice(0, 200),
      params_count: params.size
    })
  end
  
  # API/HTTP error handler
  def handle_api_error(error, url: nil, method: nil)
    handle_error(error, {
      operation: 'api_call',
      url: url,
      method: method
    })
  end
  
  private
  
  def critical_error?(error)
    critical_classes = [
      NoMemoryError,
      SystemStackError,
      SecurityError,
      'PG::UnableToSend',
      'PG::ConnectionBad'
    ]
    
    critical_classes.any? do |klass|
      error.class.name.include?(klass.to_s)
    end
  end
end
