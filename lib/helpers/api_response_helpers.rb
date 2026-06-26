# frozen_string_literal: true
# API Response Helpers - Standardized Response Format
# Part of Phase 1 Code Quality Improvements

module ApiResponseHelpers
  # Standard success response
  def api_success(data, status: 200, meta: {})
    response = {
      status: 'success',
      data: data,
      timestamp: Time.now.to_i
    }
    
    response[:meta] = meta unless meta.empty?
    
    content_type :json
    status status
    response.to_json
  end
  
  # Standard error response
  def api_error(message, status: 400, code: nil, details: {})
    response = {
      status: 'error',
      error: {
        message: message,
        code: code || error_code_from_status(status),
        timestamp: Time.now.to_i
      }
    }
    
    response[:error][:details] = details unless details.empty?
    
    content_type :json
    status status
    response.to_json
  end
  
  # Paginated response
  def api_paginated(data, page:, per_page:, total:)
    total_pages = (total.to_f / per_page).ceil
    
    meta = {
      pagination: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages,
        has_next: page < total_pages,
        has_prev: page > 1
      }
    }
    
    api_success(data, meta: meta)
  end
  
  # Not found response
  def api_not_found(resource_name = 'Resource')
    api_error(
      "#{resource_name} not found",
      status: 404,
      code: 'NOT_FOUND'
    )
  end
  
  # Unauthorized response
  def api_unauthorized(message = 'Authentication required')
    api_error(message, status: 401, code: 'UNAUTHORIZED')
  end
  
  # Forbidden response
  def api_forbidden(message = 'Access forbidden')
    api_error(message, status: 403, code: 'FORBIDDEN')
  end
  
  # Rate limit exceeded response
  def api_rate_limited(retry_after_seconds: 60)
    headers 'Retry-After' => retry_after_seconds.to_s
    
    api_error(
      'Rate limit exceeded',
      status: 429,
      code: 'RATE_LIMITED',
      details: { retry_after: retry_after_seconds }
    )
  end
  
  # Validation error response
  def api_validation_error(errors = {})
    api_error(
      'Validation failed',
      status: 422,
      code: 'VALIDATION_ERROR',
      details: { errors: errors }
    )
  end
  
  # Server error response
  def api_server_error(message = 'Internal server error', error_id: nil)
    details = {}
    details[:error_id] = error_id if error_id
    
    api_error(message, status: 500, code: 'SERVER_ERROR', details: details)
  end
  
  private
  
  # Map HTTP status codes to error codes
  def error_code_from_status(status)
    case status
    when 400 then 'BAD_REQUEST'
    when 401 then 'UNAUTHORIZED'
    when 403 then 'FORBIDDEN'
    when 404 then 'NOT_FOUND'
    when 422 then 'UNPROCESSABLE_ENTITY'
    when 429 then 'TOO_MANY_REQUESTS'
    when 500 then 'INTERNAL_SERVER_ERROR'
    when 503 then 'SERVICE_UNAVAILABLE'
    else 'ERROR'
    end
  end
end
