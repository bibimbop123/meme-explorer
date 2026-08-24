#!/usr/bin/env ruby
# frozen_string_literal: true

# PRODUCTION BUG FIX: /random page not displaying memes
# Root Cause: DiversityEngineService and SimilarMemeService were deleted during audit
# Solution: Replace with SimpleMemeSelector and add module wrapper

puts "🚨 PRODUCTION BUG FIX: Fixing /random page meme display"
puts "=" * 80

# Step 1: Add MemeExplorer module wrapper to SimpleMemeSelector
puts "\n📝 Step 1: Wrapping SimpleMemeSelector in MemeExplorer module..."

simple_selector_path = "lib/services/simple_meme_selector.rb"
simple_selector_content = File.read(simple_selector_path)

# Check if already wrapped
if simple_selector_content.include?("module MemeExplorer")
  puts "   ✅ SimpleMemeSelector already has MemeExplorer wrapper"
else
  # Add module wrapper
  new_content = simple_selector_content.sub(
    /^(class SimpleMemeSelector)/,
    "module MemeExplorer\n  \\1"
  )
  
  # Add end for module at the end
  new_content = new_content.sub(
    /^end\s*$/,
    "  end\nend"
  )
  
  File.write(simple_selector_path, new_content)
  puts "   ✅ Added MemeExplorer module wrapper to SimpleMemeSelector"
end

# Step 2: Fix routes/random_meme.rb to use SimpleMemeSelector
puts "\n📝 Step 2: Updating routes/random_meme.rb to use SimpleMemeSelector..."

routes_path = "routes/random_meme.rb"
routes_content = File.read(routes_path)

# Replace DiversityEngineService.select_diverse_meme with SimpleMemeSelector.select
routes_content.gsub!(
  /MemeExplorer::DiversityEngineService\.select_diverse_meme\(\s*meme_pool,\s*session_id:\s*session_id,\s*preferences:\s*user_prefs\s*\)/,
  "MemeExplorer::SimpleMemeSelector.select(meme_pool, session_id)"
)

routes_content.gsub!(
  /MemeExplorer::DiversityEngineService\.select_diverse_meme\(\s*memes,\s*session_id:\s*session_id,\s*preferences:\s*user_prefs\s*\)/,
  "MemeExplorer::SimpleMemeSelector.select(memes, session_id)"
)

# Replace SimilarMemeService.find_similar with SimpleMemeSelector
# For "similar" memes, filter by subreddit first, then select
routes_content.gsub!(
  /# Find similar meme.*?@meme = MemeExplorer::SimilarMemeService\.find_similar\(\s*source_meme,\s*meme_pool,\s*session_id:\s*session_id\s*\)/m,
  <<~RUBY.chomp
  # Find similar meme (same subreddit)
          similar_pool = meme_pool.select { |m| m['subreddit']&.downcase == subreddit }
          similar_pool = meme_pool if similar_pool.empty? # Fallback to all if no matches
          
          @meme = MemeExplorer::SimpleMemeSelector.select(similar_pool, session_id)
  RUBY
)

# Remove the SimilarMemeService.track_similar_request call
routes_content.gsub!(
  /\n\s*# Track the request for learning.*?\n\s*MemeExplorer::SimilarMemeService\.track_similar_request\(subreddit, session_id\)\s*\n/m,
  "\n"
)

# Update the log message that mentions Diversity Engine
routes_content.gsub!(
  'AppLogger.info("✅ [/random.json] Selected meme via Diversity Engine: #{@meme[\'title\']} (Pool: #{@meme[\'diversity_pool\']})")',
  'AppLogger.info("✅ [/random.json] Selected meme: #{@meme[\'title\']}")'
)

File.write(routes_path, routes_content)
puts "   ✅ Updated random_meme.rb to use SimpleMemeSelector"

# Step 3: Add require for SimpleMemeSelector
puts "\n📝 Step 3: Adding require statement for SimpleMemeSelector..."

unless routes_content.include?("require_relative '../lib/services/simple_meme_selector'")
  # Add after the existing require
  routes_content.sub!(
    /(require_relative '\.\.\/lib\/services\/viewing_history_service')/,
    "\\1\nrequire_relative '../lib/services/simple_meme_selector'"
  )
  File.write(routes_path, routes_content)
  puts "   ✅ Added require for SimpleMemeSelector"
else
  puts "   ✅ SimpleMemeSelector already required"
end

puts "\n" + "=" * 80
puts "✅ PRODUCTION BUG FIX COMPLETE!"
puts ""
puts "Changes made:"
puts "  1. ✅ Wrapped SimpleMemeSelector in MemeExplorer module"
puts "  2. ✅ Replaced DiversityEngineService calls with SimpleMemeSelector"  
puts "  3. ✅ Replaced SimilarMemeService calls with SimpleMemeSelector"
puts "  4. ✅ Added require for SimpleMemeSelector"
puts ""
puts "Next step: Deploy and test /random page"
puts "=" * 80
