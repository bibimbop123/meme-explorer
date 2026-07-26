# frozen_string_literal: true

# Service Merger Utility
# Helps consolidate multiple services into one
# Part of Week 3: Code Consolidation

module ServiceMerger
  class << self
    # Analyze a service file
    def analyze_service(path)
      content = File.read(path)
      
      {
        path: path,
        name: File.basename(path, '.rb'),
        lines: content.lines.count,
        methods: extract_methods(content),
        dependencies: extract_dependencies(content),
        size: content.bytesize
      }
    end
    
    # Generate report of all services
    def generate_report(services_dir = 'lib/services')
      service_files = Dir.glob(File.join(services_dir, '*.rb'))
      
      puts "Service Analysis Report"
      puts "=" * 80
      puts ""
      puts "Total services: #{service_files.length}"
      puts ""
      
      services = service_files.map { |path| analyze_service(path) }
      total_lines = services.sum { |s| s[:lines] }
      total_size = services.sum { |s| s[:size] }
      
      puts "Breakdown by size:"
      services.sort_by { |s| -s[:lines] }.each do |service|
        puts "  #{service[:name].ljust(40)} #{service[:lines].to_s.rjust(5)} lines"
      end
      
      puts ""
      puts "Total lines: #{total_lines}"
      puts "Total size: #{(total_size / 1024.0).round(1)} KB"
      puts ""
      
      suggest_merges(services)
    end
    
    # Suggest services that could be merged
    def suggest_merges(services)
      puts "Merge Suggestions:"
      puts "-" * 80
      
      # Group by naming patterns
      patterns = {
        'meme' => [],
        'user' => [],
        'analytics' => [],
        'gamification' => [],
        'media' => [],
        'cache' => []
      }
      
      services.each do |service|
        name = service[:name].downcase
        patterns.each do |pattern, list|
          list << service[:name] if name.include?(pattern)
        end
      end
      
      patterns.each do |category, service_list|
        next if service_list.empty?
        
        puts "\n#{category.capitalize} Services (#{service_list.length}):"
        service_list.each { |name| puts "  - #{name}" }
        
        if service_list.length > 3
          puts "  💡 Suggestion: Merge into one #{category}_service.rb"
        end
      end
      
      puts ""
    end
    
    private
    
    def extract_methods(content)
      content.scan(/def (self\.)?(\w+)/).map { |_, name| name }
    end
    
    def extract_dependencies(content)
      content.scan(/require.*['"](.*?)['"]/).flatten +
      content.scan(/(\w+Service)\./).flatten.uniq
    end
  end
end

# Usage:
# ServiceMerger.generate_report
