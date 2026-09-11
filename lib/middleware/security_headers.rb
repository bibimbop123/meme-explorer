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
      #
      # SECURITY TRADEOFF - ACCEPTED (documented 2026-09-11):
      # Monetag/PropellerAds' tag.min.js chain-loads ad-format scripts from
      # constantly-rotating, unpredictable domains as part of its anti-adblock
      # design (observed in production: quge5.com -> 6opo.com -> auqot.com,
      # ekhay.com, b3mny.com, and more over time - these are NOT a fixed set).
      # A per-domain allowlist cannot keep up with this rotation, so
      # script-src intentionally allows any https: origin here to let
      # Monetag ads load reliably. This is a real widening of XSS blast
      # radius vs. a strict per-domain allowlist: if any other part of the
      # app ever has an injection point, an attacker-controlled script from
      # ANY https domain could execute. This was a deliberate, informed
      # tradeoff in favor of ad revenue reliability. If tightening this back
      # up later, the correct fix is a nonce + 'strict-dynamic' policy (lets
      # only scripts descended from an already-trusted nonce'd script load
      # further scripts, without opening script-src to arbitrary origins),
      # NOT reverting to a static domain allowlist (that's what broke ads
      # here in the first place).
      "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https: " \
        "https://pagead2.googlesyndication.com " \
        "https://www.googletagmanager.com " \
        "https://www.google-analytics.com " \
        "https://cdn.jsdelivr.net " \
        "https://quge5.com " \
        "https://3nbf4.com",
      
      # Styles: self + inline + Google Fonts
      "style-src 'self' 'unsafe-inline' " \
        "https://fonts.googleapis.com",
      
      # Images: self + data URIs + Reddit + imgur + Google AdSense + Monetag/PropellerAds
      "img-src 'self' data: https: " \
        "https://i.redd.it https://preview.redd.it " \
        "https://i.imgur.com https://imgur.com " \
        "https://pagead2.googlesyndication.com " \
        "https://www.google-analytics.com " \
        "https://quge5.com " \
        "https://3nbf4.com",
      
      # Fonts: self + data URIs + Google Fonts
      "font-src 'self' data: https://fonts.gstatic.com",
      
      # Connections: self + API endpoints + analytics + service worker resources + CDNs
      # NOTE: Monetag/PropellerAds' tag.min.js calls out to constantly-rotating
      # delivery/anti-adblock domains (e.g. https://6opo.com/88/<zone>?dmn=quge5.com)
      # that change unpredictably and are NOT the same domain the script was
      # loaded from. A static per-domain allowlist can never keep up with this
      # rotation, so connect-src allows any HTTPS endpoint here (same policy
      # already applied to img-src below) to let ad beacons/delivery calls
      # through without opening up script-src (where the real XSS risk is).
      "connect-src 'self' https: " \
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
        "https://cdn.jsdelivr.net " \
        "https://quge5.com " \
        "https://3nbf4.com",
      
      # Frames: Google AdSense + YouTube embeds + Monetag/PropellerAds
      # (same rotating-domain rationale as connect-src above)
      "frame-src 'self' https: " \
        "https://pagead2.googlesyndication.com " \
        "https://www.youtube.com " \
        "https://quge5.com " \
        "https://3nbf4.com",
      
      # Media: Allow Reddit videos and audio
      "media-src 'self' " \
        "https://v.redd.it " \
        "https://i.redd.it",
      
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
