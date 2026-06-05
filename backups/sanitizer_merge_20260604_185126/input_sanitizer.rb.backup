# Input Sanitization Module
# Centralized input validation and sanitization
# Generated: May 19, 2026

module InputSanitizer
  # Maximum lengths for various inputs
  MAX_SEARCH_LENGTH = 100
  MAX_URL_LENGTH = 2000
  MAX_USERNAME_LENGTH = 50
  MAX_TITLE_LENGTH = 300
  
  # Sanitize search query - remove special chars, limit length
  def sanitize_search(query)
    return "" unless query
    
    query.to_s
         .strip
         .gsub(/[^\w\s-]/, '') # Only alphanumeric, spaces, hyphens
         .squeeze(' ') # Remove duplicate spaces
         .slice(0, MAX_SEARCH_LENGTH)
  end
  
  # Sanitize and validate URL
  def sanitize_url(url)
    return nil unless url.is_a?(String)
    
    url = url.strip.slice(0, MAX_URL_LENGTH)
    
    # Must be valid HTTP/HTTPS URL
    return nil unless url.match?(/^https?:\/\//)
    
    begin
      uri = URI.parse(url)
      return nil unless %w[http https].include?(uri.scheme)
      return nil if uri.host.nil?
      
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end
  end
  
  # Sanitize username
  def sanitize_username(username)
    return "" unless username
    
    username.to_s
            .strip
            .gsub(/[^\w-]/, '') # Only alphanumeric and hyphens
            .slice(0, MAX_USERNAME_LENGTH)
  end
  
  # Sanitize meme title
  def sanitize_title(title)
    return "Untitled" unless title
    
    title.to_s
         .strip
         .gsub(/[<>]/, '') # Remove HTML brackets
         .slice(0, MAX_TITLE_LENGTH)
  end
  
  # Sanitize email
  def sanitize_email(email)
    return nil unless email.is_a?(String)
    
    email = email.strip.downcase
    
    # Basic email validation
    return nil unless email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
    
    email
  end
  
  # Sanitize subreddit name
  def sanitize_subreddit(subreddit)
    return "unknown" unless subreddit
    
    subreddit.to_s
             .strip
             .downcase
             .gsub(/[^\w]/, '') # Remove non-alphanumeric
             .slice(0, 50)
  end
  
  # Sanitize integer parameter with bounds
  def sanitize_integer(value, min: 0, max: 1000, default: 0)
    return default unless value
    
    int_value = value.to_i
    return default if int_value < min || int_value > max
    
    int_value
  end
  
  # Sanitize boolean parameter
  def sanitize_boolean(value)
    return false if value.nil?
    
    case value.to_s.downcase
    when 'true', '1', 'yes', 'on'
      true
    when 'false', '0', 'no', 'off'
      false
    else
      false
    end
  end
  
  # Sanitize array of strings
  def sanitize_array(array, item_sanitizer: :sanitize_username, max_items: 100)
    return [] unless array.is_a?(Array)
    
    array.take(max_items).map do |item|
      send(item_sanitizer, item)
    end.compact
  end
end
