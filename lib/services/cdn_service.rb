# frozen_string_literal: true

# CDN Service - Manages CDN integration for static assets and images
class CDNService
  CDN_PROVIDERS = {
    cloudflare: 'https://cdn.cloudflare.com',
    cloudinary: 'https://res.cloudinary.com',
    imgix: 'https://meme-explorer.imgix.net'
  }.freeze
  
  def self.asset_url(path, options = {})
    provider = options[:provider] || :cloudflare
    base_url = CDN_PROVIDERS[provider]
    
    # Add optimization parameters
    params = build_params(options)
    
    "#{base_url}/#{path}?#{params}"
  end
  
  def self.image_url(url, transformations = {})
    return url unless use_cdn?
    
    # Use Cloudinary or imgix for image optimization
    provider = ENV['IMAGE_CDN_PROVIDER']&.to_sym || :cloudinary
    
    case provider
    when :cloudinary
      cloudinary_transform(url, transformations)
    when :imgix
      imgix_transform(url, transformations)
    else
      url
    end
  end
  
  def self.purge_cache(paths)
    # Purge CDN cache for specific paths
    paths = [paths] unless paths.is_a?(Array)
    
    case ENV['CDN_PROVIDER']&.to_sym
    when :cloudflare
      purge_cloudflare(paths)
    end
  end
  
  private
  
  def self.use_cdn?
    ENV['USE_CDN'] == 'true' && ENV['CDN_ENABLED'] == 'true'
  end
  
  def self.build_params(options)
    params = []
    params << "w=#{options[:width]}" if options[:width]
    params << "h=#{options[:height]}" if options[:height]
    params << "q=#{options[:quality] || 85}"
    params << "f=#{options[:format] || 'auto'}"
    params.join('&')
  end
  
  def self.cloudinary_transform(url, transformations)
    # Cloudinary URL transformation
    width = transformations[:width] || 'auto'
    height = transformations[:height] || 'auto'
    quality = transformations[:quality] || 'auto'
    format = transformations[:format] || 'auto'
    
    cloud_name = ENV['CLOUDINARY_CLOUD_NAME']
    "https://res.cloudinary.com/#{cloud_name}/image/fetch/w_#{width},h_#{height},q_#{quality},f_#{format}/#{url}"
  end
  
  def self.imgix_transform(url, transformations)
    # imgix URL transformation
    base = ENV['IMGIX_DOMAIN']
    params = transformations.map { |k, v| "#{k}=#{v}" }.join('&')
    "#{base}?url=#{CGI.escape(url)}&#{params}"
  end
  
  def self.purge_cloudflare(paths)
    require 'net/http'
    require 'json'
    
    uri = URI('https://api.cloudflare.com/client/v4/zones/ZONE_ID/purge_cache')
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{ENV['CLOUDFLARE_API_TOKEN']}"
    request['Content-Type'] = 'application/json'
    request.body = { files: paths }.to_json
    
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end
end
