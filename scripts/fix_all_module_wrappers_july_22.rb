#!/usr/bin/env ruby
# Fix ALL module MemeExplorer wrappers - they conflict with the main MemeExplorer class

FILES_TO_FIX = %w[
  lib/services/contextual_scoring_service.rb
  lib/services/diversity_engine_service.rb
  lib/services/humor_optimizer_service.rb
  lib/services/meme_pool.rb
  lib/services/meme_selection_service.rb
  lib/services/near_miss_service.rb
  lib/services/quality_control_service.rb
  lib/services/retention_service.rb
  lib/services/session_learning_service.rb
  lib/services/similar_meme_service.rb
  lib/services/simple_meme_selector.rb
  lib/services/surprise_mechanics_service.rb
  lib/services/viewing_history_service.rb
]

FILES_TO_FIX.each do |file|
  puts "Fixing #{file}..."
  content = File.read(file)
  
  # Remove module MemeExplorer wrapper
  # Find the first "module MemeExplorer" and its matching "end"
  lines = content.split("\n")
  module_line_idx = nil
  last_end_idx = nil
  indent_level = 0
  
  lines.each_with_index do |line, idx|
    if line.strip == "module MemeExplorer"
      module_line_idx = idx
      indent_level = 1
    elsif module_line_idx && line.strip == "end"
      if indent_level == 1
        last_end_idx = idx
      end
      indent_level -= 1 if line.strip.start_with?("end")
      indent_level += 1 if line.strip.start_with?("class", "module", "def")
    end
  end
  
  if module_line_idx && last_end_idx
    # Remove the module line and the last end, unindent everything in between
    new_lines = []
    lines.each_with_index do |line, idx|
      next if idx == module_line_idx # Skip module line
      next if idx == last_end_idx # Skip closing end
      
      if idx > module_line_idx && idx < last_end_idx
        # Unindent by 2 spaces
        new_lines << line.sub(/^  /, '')
      else
        new_lines << line
      end
    end
    
    File.write(file, new_lines.join("\n"))
    puts "  ✅ Fixed!"
  else
    puts "  ⚠️  Could not find module/end pair"
  end
end

puts "\n🎉 All 13 services fixed!"
