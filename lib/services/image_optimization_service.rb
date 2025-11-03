require 'image_processing/vips'
require 'aws-sdk-s3'

# Image Optimization Service
# Handles thumbnail generation, format conversion, and S3 upload
# Supports JPEG and WebP formats in 3 sizes: 280px, 600px, 1200px

class ImageOptimizationService
  include ImageProcessing::Vips

  # Size configurations for responsive images
  SIZES = {
    thumbnail: { width: 280, height: 280 },   # Card view
    mobile: { width: 600, height: 600 },      # Mobile view
    desktop: { width: 1200, height: 1200 }    # Desktop view
  }.freeze

  # Image formats to generate
  FORMATS = %i[jpeg webp].freeze

  # Quality settings
  QUALITY = {
    jpeg: 85,
    webp: 85
  }.freeze

  class << self
    # Process image from URL or file
    # @param source_url [String] URL to source image
    # @param meme_id [Integer] Meme ID for organization
    # @return [Hash] URLs for each variant
    def process_image(source_url, meme_id)
      begin
        # Download source image
        image_data = download_image(source_url)
        
        # Generate all variants
        variants = generate_variants(image_data, meme_id)
        
        # Upload to S3
        image_urls = upload_to_s3(variants, meme_id)
        
        # Extract metadata
        metadata = extract_metadata(image_data, image_urls)
        
        {
          success: true,
          image_urls:,
          metadata:
        }
      rescue StandardError => e
        handle_error(e, meme_id)
      end
    end

    private

    def download_image(url)
      response = HTTParty.get(url, timeout: 30)
      raise "Failed to download image: #{response.code}" unless response.success?
      
      response.body
    end

    def generate_variants(image_data, meme_id)
      variants = {}
      tempfile = Tempfile.new('meme_image')
      tempfile.binmode
      tempfile.write(image_data)
      tempfile.rewind

      begin
        # Process each size and format
        SIZES.each do |size_name, dimensions|
          FORMATS.each do |format|
            key = "#{size_name}_#{format}".to_sym
            variants[key] = resize_and_convert(
              tempfile.path,
              dimensions,
              format
            )
          end
        end
      ensure
        tempfile.close
        tempfile.unlink
      end

      variants
    end

    def resize_and_convert(image_path, dimensions, format)
      processor = ImageProcessing::Vips.source(image_path)
      
      # Resize with crop to exact dimensions
      processor = processor
        .resize_to_fill(dimensions[:width], dimensions[:height])

      # Convert format and set quality
      case format
      when :jpeg
        processor.convert('jpeg').call(quality: QUALITY[:jpeg])
      when :webp
        processor.convert('webp').call(quality: QUALITY[:webp])
      end
    end

    def upload_to_s3(variants, meme_id)
      s3_client = Aws::S3::Client.new(
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
        region: ENV['AWS_REGION']
      )

      image_urls = {}
      bucket = ENV['AWS_S3_BUCKET']

      variants.each do |variant_name, image_data|
        # Generate S3 key
        format = variant_name.to_s.split('_').last
        size = variant_name.to_s.split('_').first
        s3_key = "memes/#{meme_id}/#{size}.#{format}"

        # Upload to S3
        s3_client.put_object(
          bucket:,
          key: s3_key,
          body: image_data,
          content_type: content_type_for(format.to_sym),
          cache_control: 'max-age=31536000' # 1 year for immutable content
        )

        # Store URL
        image_urls["#{variant_name}_url".to_sym] = generate_cloudfront_url(s3_key)
      end

      image_urls
    end

    def content_type_for(format)
      case format
      when :jpeg
        'image/jpeg'
      when :webp
        'image/webp'
      else
        'application/octet-stream'
      end
    end

    def generate_cloudfront_url(s3_key)
      distribution = ENV['AWS_CLOUDFRONT_DISTRIBUTION'] || ENV['AWS_S3_BUCKET']
      "https://#{distribution}.cloudfront.net/#{s3_key}"
    end

    def extract_metadata(image_data, image_urls)
      {
        original_size: image_data.bytesize,
        optimized_size: calculate_total_size(image_urls),
        compression_ratio: calculate_compression_ratio(image_data),
        generated_at: Time.now.iso8601,
        formats: %w[jpeg webp],
        sizes: SIZES.keys.map(&:to_s)
      }
    end

    def calculate_total_size(image_urls)
      # In production, fetch from S3 head object
      0
    end

    def calculate_compression_ratio(original_data)
      # Simplified calculation
      format('%.2f%%', 0)
    end

    def handle_error(error, meme_id)
      AppLogger.error("Image optimization failed for meme #{meme_id}: #{error.message}")
      
      {
        success: false,
        error: error.message,
        meme_id:
      }
    end
  end
end
