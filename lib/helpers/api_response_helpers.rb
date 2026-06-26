# frozen_string_literal: true

# Standardized API Response Helpers
# Ensures consistent response format across all endpoints
module ApiResponseHelpers
  # Standard success response
  def api_success(data, status: 200, metadata: {})
    content_type :json
    halt status, {
      success: true,
      data: data,
      metadata: metadata,
      timestamp: Time.now.iso8601
    }.to_json
  end
  
  # Standard error response
  def api_error(message, status: 400, details: {}, error_code: nil)
    content_type :json
    
    response_data = {
      success: false,
      error: {
        message: message,
        code: error_code || generate_error_code(status),
        details: details
      },
      timestamp: Time.now.iso8601,
      request_id: request.env['HTTP_X_REQUEST_ID']
    }
    
    # Log error for tracking
    if status >= 500
      AppLogger.error('api_error_5xx', {
        status: status,
        message: message,
        details: details,
        path: request.path,
        method: request.request_method
      })
    end
    
    halt status, response_data.to_json
  end
  
  # Specific error types
  def api_not_found(resource = 'Resource', id = nil)
    message = id ? "#{resource} with ID '#{id}' not found" : "#{resource} not found"
    api_error(message, status: 404, error_code: 'NOT_FOUND')
  end
  
  def api_unauthorized(message = 'Authentication required')
    api_error(message, status: 401, error_code: 'UNAUTHORIZED')
  end
  
  def api_forbidden(message = 'Access denied')
    api_error(message, status: 403, error_code: 'FORBIDDEN')
  end
  
  def api_bad_request(message, details: {})
    api_error(message, status: 400, details: details, error_code: 'BAD_REQUEST')
  end
  
  def api_validation_error(errors)
    api_error(
      'Validation failed',
      status: 422,
      details: { validation_errors: errors },
      error_code: 'VALIDATION_ERROR'
    )
  end
  
  def api_rate_limit_exceeded(retry_after: 60)
    headers 'Retry-After' => retry_after.to_s
    api_error(
      'Rate limit exceeded',
      status: 429,
      details: { retry_after_seconds: retry_after },
      error_code: 'RATE_LIMIT_EXCEEDED'
    )
  end
  
  def api_server_error(message = 'Internal server error')
    api_error(message, status: 500, error_code: 'INTERNAL_ERROR')
  end
  
  # Paginated response
  def api_paginated_success(items, page:, per_page:, total_count:)
    total_pages = (total_count.to_f / per_page).ceil
    
    api_success(
      items,
      metadata: {
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: total_pages,
          has_next: page < total_pages,
          has_prev: page > 1
        }
      }
    )
  end
  
  private
  
  def generate_error_code(status)
    case status
    when 400 then 'BAD_REQUEST'
    when 401 then 'UNAUTHORIZED'
    when 403 then 'FORBIDDEN'
    when 404 then 'NOT_FOUND'
    when 422 then 'UNPROCESSABLE'
    when 429 then 'RATE_LIMIT'
    when 500..599 then 'SERVER_ERROR'
    else 'ERROR'
    end
  end
end
