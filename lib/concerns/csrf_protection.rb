f# CSRF Protection Module
# Prevents Cross-Site Request Forgery attacks
# Date: June 2, 2026

module CSRFProtection
  # Generate CSRF token for current session
  def csrf_token
    session[:csrf_token] ||= SecureRandom.hex(32)
  end
  
  # Validate CSRF token from request
  def valid_csrf_token?
    return true if request.get? || request.head? || request.options?
    
    # Get token from multiple sources
    request_token = params[:csrf_token] || 
                   request.env['HTTP_X_CSRF_TOKEN'] ||
                   request.env['HTTP_X_XSRF_TOKEN']
    
    return false unless request_token
    
    # Constant-time comparison to prevent timing attacks
    secure_compare(session[:csrf_token].to_s, request_token.to_s)
  end
  
  # Check CSRF token and halt if invalid
  def verify_csrf_token!
    unless valid_csrf_token?
      halt 403, { 
        error: "Invalid CSRF token",
        message: "This request has been blocked for your security."
      }.to_json
    end
  end
  
  # Secure string comparison (constant time)
  def secure_compare(a, b)
    return false if a.nil? || b.nil? || a.bytesize != b.bytesize
    
    l = a.unpack("C*")
    r, i = 0, -1
    
    b.each_byte { |byte| r |= byte ^ l[i += 1] }
    r == 0
  end
  
  # HTML helper to include CSRF meta tag
  def csrf_meta_tag
    %(<meta name="csrf-token" content="#{csrf_token}">)
  end
  
  # HTML helper for CSRF hidden field in forms
  def csrf_hidden_field
    %(<input type="hidden" name="csrf_token" value="#{csrf_token}">)
  end
end
