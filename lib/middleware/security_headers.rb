# Security Headers Middleware
# Implements OWASP-recommended security headers for production security
# Phase 0 Task 2.2 - Security Hardening

class SecurityHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # Apply security headers to all responses
    headers.merge!(security_headers)
    
    [status, headers, response]
  end

  private

  def security_headers
    {
      # Prevent clickjacking attacks
      'X-Frame-Options' => 'SAMEORIGIN',
      
      # Prevent MIME-type sniffing
      'X-Content-Type-Options' => 'nosniff',
      
      # Enable XSS filter in browsers (legacy support)
      'X-XSS-Protection' => '1; mode=block',
      
      # Referrer policy - balance privacy with analytics
      'Referrer-Policy' => 'strict-origin-when-cross-origin',
      
      # Permissions policy - restrict browser features
      'Permissions-Policy' => permissions_policy,
      
      # Content Security Policy - prevent XSS attacks
      'Content-Security-Policy' => content_security_policy,
      
      # Force HTTPS in production
      'Strict-Transport-Security' => strict_transport_security
    }.compact # Remove nil values for development
  end

  def permissions_policy
    [
      'camera=()',           # No camera access
      'microphone=()',       # No microphone access
      'geolocation=()',      # No location access
      'payment=()',          # No payment API
      'usb=()',              # No USB access
      'accelerometer=()',    # No motion sensors
      'gyroscope=()',        # No gyroscope
      'magnetometer=()',     # No magnetometer
      'interest-cohort=()'   # Disable FLoC tracking
    ].join(', ')
  end

  def content_security_policy
    # Development: More permissive for hot reload and local dev
    # Production: Strict policy with specific allowlists
    if development_or_test?
      development_csp
    else
      production_csp
    end
  end

  def development_csp
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'",  # Allow eval for dev tools
      "style-src 'self' 'unsafe-inline'",                  # Allow inline styles
      "img-src 'self' data: https: http:",                 # Allow all images
      "font-src 'self' data:",
      "connect-src 'self' ws: wss:",                       # Allow websockets for hot reload
      "form-action 'self' https://www.reddit.com",         # Allow Reddit OAuth
      "frame-ancestors 'self'"
    ].join('; ')
  end

  def production_csp
    [
      "default-src 'self'",
      
      # Scripts: self + specific CDNs + inline for critical path + wasm support
      "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' " \
        "https://pagead2.googlesyndication.com " \
        "https://www.googletagmanager.com " \
        "https://www.google-analytics.com " \
        "https://cdn.jsdelivr.net",
      
      # Styles: self + inline + Google Fonts
      "style-src 'self' 'unsafe-inline' " \
        "https://fonts.googleapis.com",
      
      # Images: self + data URIs + Reddit + imgur + Google AdSense
      "img-src 'self' data: https: " \
        "https://i.redd.it https://preview.redd.it " \
        "https://i.imgur.com https://imgur.com " \
        "https://pagead2.googlesyndication.com " \
        "https://www.google-analytics.com",
      
      # Fonts: self + data URIs + Google Fonts
      "font-src 'self' data: https://fonts.gstatic.com",
      
      # Connections: self + API endpoints + analytics + service worker resources + CDNs
      "connect-src 'self' " \
        "https://www.reddit.com " \
        "https://oauth.reddit.com " \
        "https://www.google-analytics.com " \
        "https://i.redd.it " \
        "https://v.redd.it " \
        "https://preview.redd.it " \
        "https://external-preview.redd.it " \
        "https://i.imgur.com " \
        "https://imgur.com " \
        "https://fonts.googleapis.com " \
        "https://fonts.gstatic.com " \
        "https://pagead2.googlesyndication.com " \
        "https://cdn.jsdelivr.net",
      
      # Frames: Google AdSense + YouTube embeds
      "frame-src 'self' " \
        "https://pagead2.googlesyndication.com " \
        "https://www.youtube.com",
      
      # Frame ancestors: prevent embedding except same origin
      "frame-ancestors 'self'",
      
      # Object/embed: disallow Flash and other plugins
      "object-src 'none'",
      
      # Base URI: prevent base tag hijacking
      "base-uri 'self'",
      
      # Form action: allow Reddit OAuth + same origin
      "form-action 'self' https://www.reddit.com",
      
      # Upgrade insecure requests in production
      "upgrade-insecure-requests"
    ].join('; ')
  end

  def strict_transport_security
    # Only enable HSTS in production over HTTPS
    return nil if development_or_test?
    
    # max-age: 1 year (31536000 seconds)
    # includeSubDomains: apply to all subdomains
    # preload: allow inclusion in browser HSTS preload lists
    'max-age=31536000; includeSubDomains; preload'
  end

  def development_or_test?
    env = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
    %w[development test].include?(env.to_s.downcase)
  end
end
