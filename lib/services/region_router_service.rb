# frozen_string_literal: true

# Region Router Service - Routes requests to optimal region
class RegionRouterService
  REGIONS = {
    'us-east-1' => { name: 'US East', latency: 20 },
    'us-west-1' => { name: 'US West', latency: 25 },
    'eu-west-1' => { name: 'Europe West', latency: 50 },
    'ap-southeast-1' => { name: 'Asia Pacific', latency: 80 }
  }.freeze
  
  def self.optimal_region(ip_address)
    # Determine optimal region based on IP geolocation
    geo_data = GeolocationService.lookup(ip_address)
    
    return 'us-east-1' unless geo_data
    
    # Simple region mapping based on continent
    case geo_data[:continent]
    when 'NA' then 'us-east-1'
    when 'SA' then 'us-east-1'
    when 'EU' then 'eu-west-1'
    when 'AS' then 'ap-southeast-1'
    when 'AF' then 'eu-west-1'
    when 'OC' then 'ap-southeast-1'
    else 'us-east-1'
    end
  end
  
  def self.region_url(region)
    urls = {
      'us-east-1' => ENV['REGION_US_EAST_URL'],
      'us-west-1' => ENV['REGION_US_WEST_URL'],
      'eu-west-1' => ENV['REGION_EU_WEST_URL'],
      'ap-southeast-1' => ENV['REGION_AP_SOUTHEAST_URL']
    }
    
    urls[region] || ENV['PRIMARY_URL']
  end
  
  def self.health_check
    # Check health of all regions
    REGIONS.keys.map do |region|
      {
        region: region,
        healthy: check_region_health(region),
        latency: measure_latency(region)
      }
    end
  end
  
  private
  
  def self.check_region_health(region)
    # Ping region health endpoint
    url = region_url(region)
    return false unless url
    
    begin
      response = Net::HTTP.get_response(URI("#{url}/health"))
      response.code == '200'
    rescue
      false
    end
  end
  
  def self.measure_latency(region)
    # Measure round-trip latency
    url = region_url(region)
    return 999 unless url
    
    start = Time.now
    Net::HTTP.get_response(URI("#{url}/ping"))
    ((Time.now - start) * 1000).round
  rescue
    999
  end
end
