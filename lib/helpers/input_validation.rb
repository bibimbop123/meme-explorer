# Comprehensive Input Validation Module
# P1 Fix: Standardize validation across all routes

module InputValidation
  # Validate URL format and safety
  def validate_url(url, max_length: 2048)
    return [false, "URL is required"] if url.nil? || url.strip.empty?
    return [false, "URL too long (max #{max_length})"] if url.length > max_length
    
    begin
      uri = URI.parse(url)
      return [false, "Invalid URL scheme"] unless ['http', 'https'].include?(uri.scheme)
      return [false, "Invalid URL format"] unless uri.host
      [true, nil]
    rescue URI::InvalidURIError => e
      [false, "Invalid URL format: #{e.message}"]
    end
  end
  
  # Validate integer parameters
  def validate_integer(value, name: 'value', min: nil, max: nil)
    return [false, "#{name} is required"] if value.nil?
    
    begin
      int_value = Integer(value)
      return [false, "#{name} must be >= #{min}"] if min && int_value < min
      return [false, "#{name} must be <= #{max}"] if max && int_value > max
      [true, int_value]
    rescue ArgumentError, TypeError
      [false, "#{name} must be a valid integer"]
    end
  end
  
  # Validate string parameters
  def validate_string(value, name: 'value', min_length: 0, max_length: 1000, pattern: nil)
    return [false, "#{name} is required"] if value.nil?
    
    str_value = value.to_s.strip
    return [false, "#{name} is too short (min #{min_length})"] if str_value.length < min_length
    return [false, "#{name} is too long (max #{max_length})"] if str_value.length > max_length
    
    if pattern && str_value !~ pattern
      return [false, "#{name} has invalid format"]
    end
    
    [true, str_value]
  end
  
  # Validate JSON payload
  def validate_json_payload(payload, required_keys: [])
    return [false, "Payload is required"] if payload.nil? || payload.empty?
    
    begin
      data = JSON.parse(payload)
      return [false, "Payload must be a JSON object"] unless data.is_a?(Hash)
      
      missing_keys = required_keys - data.keys
      return [false, "Missing required keys: #{missing_keys.join(', ')}"] unless missing_keys.empty?
      
      [true, data]
    rescue JSON::ParserError => e
      [false, "Invalid JSON: #{e.message}"]
    end
  end
  
  # Validate enum values
  def validate_enum(value, name: 'value', allowed_values: [])
    return [false, "#{name} is required"] if value.nil?
    return [false, "#{name} must be one of: #{allowed_values.join(', ')}"] unless allowed_values.include?(value)
    [true, value]
  end
  
  # Sanitize user input for SQL (additional layer beyond parameterization)
  def sanitize_for_sql(input)
    return nil if input.nil?
    # Remove null bytes and control characters
    input.to_s.gsub(/[\\x00-\\x1F\\x7F]/, '').strip
  end
  
  # Validate and sanitize search query
  def validate_search_query(query, max_length: 200)
    return [false, "Search query is required"] if query.nil? || query.strip.empty?
    
    sanitized = sanitize_for_sql(query)
    return [false, "Search query too long (max #{max_length})"] if sanitized.length > max_length
    
    # Prevent ReDoS patterns
    return [false, "Invalid search pattern"] if sanitized =~ /(\\*|\\+|\\?){3,}/
    
    [true, sanitized]
  end
end
