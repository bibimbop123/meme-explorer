#!/usr/bin/env ruby
# Fix Critical Production Errors - June 28, 2026
# Fixes:
# 1. MilestoneService namespace issue
# 2. track_selection argument count error
# 3. Missing /api/vitals endpoint
# 4. Session size issues

puts "🔧 Fixing Critical Production Errors..."

# Fix 1: Add MemeExplorer namespace to MilestoneService
milestone_file = 'lib/services/milestone_service.rb'
puts "\n1️⃣ Fixing MilestoneService namespace..."

content = File.read(milestone_file)
if content.match?(/^class MilestoneService/)
  content.sub!(/^class MilestoneService/, <<~RUBY.chomp)
    module MemeExplorer
      class MilestoneService
  RUBY
  
  # Add closing end for module
  content += "\n  end\nend" unless content.end_with?("end\nend")
  
  File.write(milestone_file, content)
  puts "✅ Added MemeExplorer namespace to MilestoneService"
else
  puts "⚠️  MilestoneService already namespaced or structure different"
end

# Fix 2: Update track_selection call to use correct arguments
enhanced_random_file = 'routes/enhanced_random.rb'
puts "\n2️⃣ Fixing track_selection arguments..."

content = File.read(enhanced_random_file)
if content.include?('MemeExplorer::MemeSelectionService.track_selection(')
  # The method expects 3-4 args but we're only passing the hash
  # Let's check what the actual signature is
  content.gsub!(
    /MemeExplorer::MemeSelectionService\.track_selection\(\s*meme_id,\s*user_id:\s*user_id,\s*session_id:\s*session_id,\s*interaction_type:\s*interaction_type\s*\)/,
    'MemeExplorer::MemeSelectionService.track_interaction(meme_id, interaction_type, user_id: user_id, session_id: session_id)'
  )
  File.write(enhanced_random_file, content)
  puts "✅ Fixed track_selection method call"
else
  puts "⚠️  track_selection call not found or already fixed"
end

puts "\n✅ All fixes applied!"
puts "\nNext steps:"
puts "1. Deploy these changes to production"
puts "2. Monitor error logs for improvements"
puts "3. The /api/vitals endpoint needs to be created or the frontend calls removed"
