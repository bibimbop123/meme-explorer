# Phase 3: Performance Optimization Helpers
module PerformanceHelpers
  # Generate preconnect link tag
  def preconnect_tag(url, crossorigin: true)
    attrs = crossorigin ? ' crossorigin' : ''
    "<link rel='preconnect' href='#{url}'#{attrs}>"
  end
  
  # Generate dns-prefetch link tag
  def dns_prefetch_tag(url)
    "<link rel='dns-prefetch' href='#{url}'>"
  end
  
  # Generate preload link tag for critical resources
  def preload_tag(url, as:)
    "<link rel='preload' href='#{url}' as='#{as}'>"
  end
  
  # Check if production environment
  def production?
    ENV['RACK_ENV'] == 'production'
  end
  
  # Minify inline CSS in production
  def inline_css(css)
    return css unless production?
    css.gsub(/\s+/, ' ').strip
  end
  
  # Minify inline JS in production
  def inline_js(js)
    return js unless production?
    js.gsub(/\s+/, ' ').strip
  end
end
