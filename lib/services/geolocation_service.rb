# frozen_string_literal: true

# Geolocation Service - IP-based geolocation lookup
class GeolocationService
  CACHE_TTL = 86400  # 24 hours
  
  def self.lookup(ip_address)
    return mock_data if ENV['RACK_ENV'] == 'development'
    
    # Try cache first
    cached = RedisService.get("geo:#{ip_address}")
    return JSON.parse(cached, symbolize_names: true) if cached
    
    # Lookup from MaxMind or similar service
    data = lookup_from_provider(ip_address)
    
    # Cache result
    RedisService.setex("geo:#{ip_address}", CACHE_TTL, data.to_json) if data
    
    data
  end
  
  private
  
  def self.lookup_from_provider(ip_address)
    # Use MaxMind GeoIP2, IP2Location, or similar
    # This is a placeholder - integrate with actual service
    {
      ip: ip_address,
      continent: 'NA',
      country: 'US',
      region: 'California',
      city: 'San Francisco',
      latitude: 37.7749,
      longitude: -122.4194,
      timezone: 'America/Los_Angeles'
    }
  end
  
  def self.mock_data
    {
      ip: '127.0.0.1',
      continent: 'NA',
      country: 'US',
      region: 'California',
      city: 'San Francisco',
      latitude: 37.7749,
      longitude: -122.4194,
      timezone: 'America/Los_Angeles'
    }
  end
end
