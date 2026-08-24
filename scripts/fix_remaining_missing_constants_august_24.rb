#!/usr/bin/env ruby
# Fix remaining missing constants - August 24, 2026
# Fixes MilestoneService and CuratedCollectionsHelper errors

require 'fileutils'

puts "🔧 Fixing remaining missing constants..."

# Fix 1: Comment out MilestoneService calls in routes/random_meme.rb
random_meme_path = 'routes/random_meme.rb'
content = File.read(random_meme_path)

content.gsub!(
  /# Check if milestone reached\s+milestone = MemeExplorer::MilestoneService\.check_milestone\(session\[:view_count\]\)\s+if milestone\s+@milestone = milestone\s+# Only award to DB if logged in\s+if current_user_id\s+MemeExplorer::MilestoneService\.award_milestone\(current_user_id, milestone\) rescue nil\s+end\s+end/m,
  <<~RUBY.chomp
    # Check if milestone reached (DISABLED - MilestoneService removed)
          # milestone = MemeExplorer::MilestoneService.check_milestone(session[:view_count])
          # if milestone
          #   @milestone = milestone
          #   # Only award to DB if logged in
          #   if current_user_id
          #     MemeExplorer::MilestoneService.award_milestone(current_user_id, milestone) rescue nil
          #   end
          # end
  RUBY
)

File.write(random_meme_path, content)
puts "✅ Fixed random_meme.rb - Commented out MilestoneService calls"

# Fix 2: Replace CuratedCollectionsHelper in app_helpers.rb with inline logic
app_helpers_path = 'lib/helpers/app_helpers.rb'
content = File.read(app_helpers_path)

content.gsub!(
  /# Wrapper for collection_name_for_subreddit \(views expect this method name\)\s+def collection_name_for_subreddit\(subreddit\)\s+CuratedCollectionsHelper\.collection_name_for\(subreddit\)\s+end/m,
  <<~RUBY.chomp
    # Wrapper for collection_name_for_subreddit (views expect this method name)
      def collection_name_for_subreddit(subreddit)
        # CuratedCollectionsHelper removed - return subreddit as-is
        subreddit.to_s.capitalize
      end
  RUBY
)

File.write(app_helpers_path, content)
puts "✅ Fixed app_helpers.rb - Replaced CuratedCollectionsHelper with inline logic"

puts ""
puts "✅ All missing constants fixed!"
puts "   - MilestoneService calls commented out"
puts "   - CuratedCollectionsHelper replaced with simple logic"
