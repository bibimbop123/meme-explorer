# frozen_string_literal: true

# Input Sanitization Module
# Prevents XSS, SQL injection, and other injection attacks
# Created: July 22, 2026

module InputSanitizer
  class << self
    # Sanitize user input for database queries
    def sanitize_sql(input)
      return nil if input.nil?
      return input if input.is_a?(Integer)
      
      input.to_s.gsub(/[;'"]/, '').strip
    end

    # Sanitize HTML input (prevent XSS)
    def sanitize_html(input)
      return nil if input.nil?
      
      require 'cgi'
      CGI.escapeHTML(input.to_s)
    end

    # Sanitize file paths (prevent directory traversal)
    def sanitize_path(path)
      return nil if path.nil?
      
      # Remove .. and other dangerous patterns
      sanitized = path.to_s.gsub(/\.\./, '').gsub(/[<>:|?*]/, '')
      
      # Ensure it doesn't start with /
      sanitized.start_with?('/') ? sanitized[1..-1] : sanitized
    end

    # Sanitize URLs
    def sanitize_url(url)
      return nil if url.nil?
      
      # Only allow http/https protocols
      return nil unless url.to_s.match?(/\Ahttps?:\/\//)
      
      url.to_s.strip
    end

    # Sanitize username/email
    def sanitize_identifier(input)
      return nil if input.nil?
      
      input.to_s.gsub(/[^a-zA-Z0-9@._-]/, '').strip[0..255]
    end
  end
end
