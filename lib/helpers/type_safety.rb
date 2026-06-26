# Type Safety Module
# P1 Fix: Prevent implicit type coercion bugs

module TypeSafety
  # Safe integer conversion with error handling
  def safe_to_i(value, default: 0, allow_nil: false)
    return nil if value.nil? && allow_nil
    return default if value.nil?
    
    case value
    when Integer
      value
    when String
      return default if value.strip.empty?
      Integer(value)
    when Float
      value.to_i
    else
      default
    end
  rescue ArgumentError, TypeError
    AppLogger.warn("Type coercion failed", value: value, method: :safe_to_i)
    default
  end
  
  # Safe float conversion
  def safe_to_f(value, default: 0.0, allow_nil: false)
    return nil if value.nil? && allow_nil
    return default if value.nil?
    
    case value
    when Float
      value
    when Integer
      value.to_f
    when String
      return default if value.strip.empty?
      Float(value)
    else
      default
    end
  rescue ArgumentError, TypeError
    AppLogger.warn("Type coercion failed", value: value, method: :safe_to_f)
    default
  end
  
  # Safe string conversion
  def safe_to_s(value, default: '', allow_nil: false)
    return nil if value.nil? && allow_nil
    return default if value.nil?
    value.to_s
  rescue => e
    AppLogger.warn("Type coercion failed", value: value, method: :safe_to_s, error: e.message)
    default
  end
  
  # Calculate score with type safety
  def calculate_engagement_score(meme, weights: { likes: 2, views: 1 })
    likes = safe_to_i(meme["likes"], default: 0)
    views = safe_to_i(meme["views"], default: 0)
    
    # Validate data quality
    if likes < 0 || views < 0
      AppLogger.warn("Invalid engagement metrics", meme: meme["url"], likes: likes, views: views)
      return 0.0
    end
    
    (likes * weights[:likes] + views * weights[:views]).to_f
  end
  
  # Safe hash access with type checking
  def safe_fetch(hash, key, type: String, default: nil)
    value = hash[key] || hash[key.to_s] || hash[key.to_sym]
    return default if value.nil?
    
    case type.name
    when 'Integer'
      safe_to_i(value, default: default)
    when 'Float'
      safe_to_f(value, default: default)
    when 'String'
      safe_to_s(value, default: default)
    else
      value.is_a?(type) ? value : default
    end
  end
end
