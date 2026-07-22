#!/usr/bin/env ruby
# Fix final 2 services missing module wrappers - DiversityEngineService & MilestoneService

puts "🔧 Fixing final 2 service module wrappers..."

# Fix DiversityEngineService
diversity_file = 'lib/services/diversity_engine_service.rb'
content = File.read(diversity_file)

if content.start_with?('# Diversity Engine V2')
  # Add module wrapper
  lines = content.lines
  header_lines = []
  code_lines = []
  
  lines.each_with_index do |line, i|
    if i < 4  # First 4 lines are comments
      header_lines << line
    else
      code_lines << line
    end
  end
  
  new_content = header_lines.join + 
                "\nmodule MemeExplorer\n" +
                code_lines.join.gsub(/^/, '  ') +  # Indent all code
                "end\n"
  
  File.write(diversity_file, new_content)
  puts "  ✅ Fixed DiversityEngineService"
else
  puts "  ⏭  DiversityEngineService already has module wrapper"
end

# Fix MilestoneService
milestone_file = 'lib/services/milestone_service.rb'
content = File.read(milestone_file)

unless content.include?('module MemeExplorer')
  # Add module wrapper
  new_content = "module MemeExplorer\n" +
                content.gsub(/^/, '  ') +  # Indent all code
                "end\n"
  
  File.write(milestone_file, new_content)
  puts "  ✅ Fixed MilestoneService"
else
  puts "  ⏭  MilestoneService already has module wrapper"
end

puts "\n✅ All services now have proper module wrappers!"
puts "📦 Deploy to fix production errors"
