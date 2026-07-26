# frozen_string_literal: true

# Inline Script Extractor
# Extracts inline scripts from layout.erb to external files
# Part of Week 2: Performance Optimization

module InlineScriptExtractor
  class << self
    def extract_from_layout
      layout_path = 'views/layout.erb'
      layout_content = File.read(layout_path)
      
      scripts = []
      script_count = 0
      
      # Find all <script> blocks without src attribute
      layout_content.scan(/<script(?![^>]*src=)[^>]*>(.*?)<\/script>/m) do |match|
        script_count += 1
        script_content = match[0].strip
        next if script_content.empty?
        
        scripts << {
          number: script_count,
          content: script_content,
          size: script_content.bytesize
        }
      end
      
      scripts
    end
    
    def generate_report
      scripts = extract_from_layout
      total_size = scripts.sum { |s| s[:size] }
      
      puts "Inline Script Analysis Report"
      puts "=" * 60
      puts ""
      puts "Total inline scripts found: #{scripts.length}"
      puts "Total size: #{total_size} bytes (~#{total_size / 1024}KB)"
      puts ""
      puts "Breakdown:"
      scripts.each do |script|
        puts "  Script #{script[:number]}: #{script[:size]} bytes"
      end
      puts ""
      puts "Recommendation: Extract to external file for better caching"
      puts "Target: public/js/layout-scripts.js"
    end
    
    def extract_to_file(output_path = 'public/js/layout-scripts.js')
      scripts = extract_from_layout
      
      combined_content = <<~JS
        // Extracted from layout.erb inline scripts
        // Date: #{Time.now.strftime('%Y-%m-%d')}
        // Part of Week 2: Performance Optimization

        (function() {
          'use strict';

      JS
      
      scripts.each_with_index do |script, index|
        combined_content += <<~JS
          
          // ========== Inline Script #{index + 1} ==========
          #{script[:content]}
          
        JS
      end
      
      combined_content += "})();\n"
      
      File.write(output_path, combined_content)
      puts "✅ Extracted #{scripts.length} scripts to #{output_path}"
      puts "   Size: #{combined_content.bytesize} bytes"
    end
  end
end

# Usage:
# InlineScriptExtractor.generate_report
# InlineScriptExtractor.extract_to_file
