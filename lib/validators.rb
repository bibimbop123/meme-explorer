# frozen_string_literal: true

# Centralized input validation module for MemeExplorer
# Provides defense-in-depth security: XSS prevention, input sanitization, parameter validation
# Used across auth, search, profile, admin routes

module Validators
  # Custom exception for validation failures
  class ValidationError < StandardError; end

  # Email validation: RFC 5322 simplified
  # Returns lowercased email or raises ValidationError
  def self.validate_email(email)
    email = email.to_s.strip.downcase
    
    raise ValidationError, "Email cannot be empty" if email.empty?
    raise ValidationError, "Email exceeds maximum length (255 chars)" if email.length > 255
    
    # Basic RFC 5322 pattern
    pattern = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
    raise ValidationError, "Email format invalid" unless email.match?(pattern)
    
    # Reject common SQL injection attempts
    raise ValidationError, "Email contains invalid characters" if email.match?(/['";-]/)
    
    email
  end

  # Username validation: alphanumeric, underscores, hyphens only
  # Returns original username or raises ValidationError
  def self.validate_username(username)
    username = username.to_s.strip
    
    raise ValidationError, "Username cannot be empty" if username.empty?
    raise ValidationError, "Username must be at least 3 characters" if username.length < 3
    raise ValidationError, "Username exceeds maximum length (50 chars)" if username.length > 50
    
    # Allow alphanumeric, underscores, hyphens only
    pattern = /\A[a-z0-9_\-]+\z/i
    raise ValidationError, "Username contains invalid characters" unless username.match?(pattern)
    
    # Reject SQL keywords and injection attempts
    raise ValidationError, "Username contains invalid patterns" if username.match?(/'|--;|\/\*|\*\//)
    
    username
  end

  # Password validation: strong requirements
  # Returns password or raises ValidationError
  def self.validate_password(password)
    password = password.to_s
    
    raise ValidationError, "Password cannot be empty" if password.empty?
    raise ValidationError, "Password minimum 8 characters required" if password.length < 8
    raise ValidationError, "Password maximum 128 characters allowed" if password.length > 128
    raise ValidationError, "Password must contain uppercase letter" unless password.match?(/[A-Z]/)
    raise ValidationError, "Password must contain lowercase letter" unless password.match?(/[a-z]/)
    raise ValidationError, "Password must contain number" unless password.match?(/[0-9]/)
    
    # Allow special characters (!, @, #, $, %, ^, &, *)
    has_special = password.match?(/[!@#$%^&*]/)
    raise ValidationError, "Password must contain uppercase, lowercase, number, and special character" if password.length < 12 && !has_special
    
    password
  end

  # String sanitization: removes XSS vectors and control characters
  # Returns sanitized string or raises ValidationError if exceeds max_length
  def self.sanitize_string(string, max_length: 1000)
    string = string.to_s
    
    raise ValidationError, "String exceeds maximum length (#{max_length} chars)" if string.length > max_length
    
    # Remove dangerous HTML/JS tags
    string = string.gsub(/<script[^>]*>.*?<\/script>/im, '')
    string = string.gsub(/<iframe[^>]*>.*?<\/iframe>/im, '')
    string = string.gsub(/<object[^>]*>.*?<\/object>/im, '')
    string = string.gsub(/<embed[^>]*>/im, '')
    string = string.gsub(/on\w+\s*=\s*["'][^"']*["']/im, '')  # Remove event handlers
    string = string.gsub(/javascript:/im, '')  # Remove javascript: protocol
    
    # Remove null bytes and other control characters
    string = string.gsub(/\x00/, '')  # Null byte
    string = string.gsub(/[\x01-\x08\x0B-\x0C\x0E-\x1F\x7F]/, '')  # Other control chars
    
    string
  end

  # Parameter whitelisting: only allows specified keys in hash
  # Returns filtered hash with only allowed keys or raises ValidationError
  def self.whitelist_params(params, allowed_keys: [], optional_keys: [])
    params = params.to_h
    
    # Check all required keys present
    (allowed_keys - optional_keys).each do |key|
      raise ValidationError, "Missing required parameter: #{key}" unless params.key?(key) || params.key?(key.to_s)
    end
    
    # Extract only allowed keys (support both symbol and string keys)
    filtered = {}
    (allowed_keys + optional_keys).uniq.each do |key|
      if params.key?(key)
        filtered[key] = params[key]
      elsif params.key?(key.to_s)
        filtered[key.to_s] = params[key.to_s]
      end
    end
    
    filtered
  end

  # Search query validation: prevents injection, enforces length limits
  # Returns sanitized query or raises ValidationError
  def self.validate_search_query(query, min_length: 1, max_length: 200)
    query = query.to_s.strip
    
    raise ValidationError, "Search query cannot be empty" if query.length < min_length
    raise ValidationError, "Search query exceeds maximum length (#{max_length} chars)" if query.length > max_length
    
    # Reject SQL injection patterns
    raise ValidationError, "Search query contains invalid characters" if query.match?(/'|";|--|\*|\/\*|\*\/|xp_|sp_/i)
    
    # Sanitize XSS vectors
    query = sanitize_string(query, max_length: max_length)
    
    query
  end

  # Pagination parameter validation
  # Returns { page: int, limit: int } or raises ValidationError
  def self.validate_pagination(page = 1, limit = 10)
    page = page.to_i
    limit = limit.to_i
    
    raise ValidationError, "Page must be positive integer" if page < 1
    raise ValidationError, "Limit must be positive integer" if limit < 1
    raise ValidationError, "Limit exceeds maximum (100)" if limit > 100
    
    { page: page, limit: limit }
  end

  # URL validation: ensures URL is HTTPS and from trusted domains
  # Returns URL or raises ValidationError
  def self.validate_url(url, allowed_domains: [])
    url = url.to_s.strip
    
    raise ValidationError, "URL cannot be empty" if url.empty?
    raise ValidationError, "URL must start with https://" unless url.start_with?('https://')
    
    # Only check domains if whitelist provided
    if allowed_domains.any?
      uri = begin
        URI.parse(url)
      rescue => e
        raise ValidationError, "Invalid URL format: #{e.message}"
      end
      
      domain_allowed = allowed_domains.any? { |domain| uri.host&.include?(domain) }
      raise ValidationError, "URL domain not whitelisted" unless domain_allowed
    end
    
    url
  end

  # Integer ID validation: ensures positive integer
  # Returns integer or raises ValidationError
  def self.validate_id(id)
    id = id.to_i
    raise ValidationError, "ID must be positive integer" if id <= 0
    id
  end

  # Boolean coercion with validation
  # Returns true/false or raises ValidationError
  def self.validate_boolean(value)
    case value
    when true, 'true', 1, '1'
      true
    when false, 'false', 0, '0'
      false
    else
      raise ValidationError, "Invalid boolean value: #{value}"
    end
  end

  # Validate API rate limit parameters
  # Returns { limit: int, window: int } or raises ValidationError
  def self.validate_rate_limit(limit = 60, window = 60)
    limit = limit.to_i
    window = window.to_i
    
    raise ValidationError, "Rate limit must be positive integer" if limit < 1
    raise ValidationError, "Rate limit window must be positive integer" if window < 1
    raise ValidationError, "Rate limit window exceeds maximum (3600 seconds)" if window > 3600
    
    { limit: limit, window: window }
  end

  # Comprehensive signup parameter validation
  # Returns validated { email, username, password } hash or raises ValidationError
  def self.validate_signup(params)
    email = validate_email(params[:email] || params['email'])
    username = validate_username(params[:username] || params['username'])
    password = validate_password(params[:password] || params['password'])
    
    # Check password confirmation if provided
    password_confirm = params[:password_confirm] || params['password_confirm']
    if password_confirm && password != password_confirm
      raise ValidationError, "Passwords do not match"
    end
    
    {
      email: email,
      username: username,
      password: password
    }
  end

  # Comprehensive login parameter validation
  # Returns validated { email, password } hash or raises ValidationError
  def self.validate_login(params)
    email = validate_email(params[:email] || params['email'])
    password = params[:password] || params['password']
    
    raise ValidationError, "Password required" if password.to_s.empty?
    
    {
      email: email,
      password: password
    }
  end

  # Search endpoint parameter validation
  # Returns validated { query, page, limit } hash or raises ValidationError
  def self.validate_search_params(params)
    query = validate_search_query(params[:q] || params['q'])
    pagination = validate_pagination(
      params[:page] || params['page'] || 1,
      params[:limit] || params['limit'] || 10
    )
    
    {
      query: query,
      page: pagination[:page],
      limit: pagination[:limit]
    }
  end
end
