# frozen_string_literal: true

# Asset Optimization Pipeline
# Compresses and minifies CSS/JS
# Created: July 22, 2026

module AssetOptimizer
  class << self
    # Minify CSS
    def minify_css(css_content)
      css_content
        .gsub(/\/\*.*?\*\//m, '')  # Remove comments
        .gsub(/\s+/, ' ')              # Collapse whitespace
        .gsub(/\s*([{}:;,])\s*/, '\1')  # Remove spaces around special chars
        .strip
    end

    # Minify JavaScript
    def minify_js(js_content)
      # Basic minification (for production, use a proper minifier)
      js_content
        .gsub(/\/\/.*$/, '')       # Remove single-line comments
        .gsub(/\/\*.*?\*\//m, '')  # Remove multi-line comments  
        .gsub(/\s+/, ' ')            # Collapse whitespace
        .gsub(/\s*([{}():;,=])\s*/, '\1')  # Remove spaces
        .strip
    end

    # Gzip compress content
    def gzip_compress(content)
      require 'zlib'
      require 'stringio'
      
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      gz.write(content)
      gz.close
      io.string
    end

    # Optimize all assets
    def optimize_all
      optimized = 0
      
      # CSS files
      Dir.glob('public/css/*.css').each do |file|
        next if file.end_with?('.min.css')
        
        content = File.read(file)
        minified = minify_css(content)
        
        output_file = file.sub('.css', '.min.css')
        File.write(output_file, minified)
        
        # Also create gzipped version
        File.write("#{output_file}.gz", gzip_compress(minified))
        
        optimized += 1
      end
      
      # JS files
      Dir.glob('public/js/**/*.js').each do |file|
        next if file.end_with?('.min.js')
        
        content = File.read(file)
        minified = minify_js(content)
        
        output_file = file.sub('.js', '.min.js')
        File.write(output_file, minified)
        File.write("#{output_file}.gz", gzip_compress(minified))
        
        optimized += 1
      end
      
      optimized
    end
  end
end
