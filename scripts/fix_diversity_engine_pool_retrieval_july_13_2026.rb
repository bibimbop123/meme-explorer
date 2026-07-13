#!/usr/bin/env ruby
# frozen_string_literal: true

# Fix Diversity Engine to retrieve from tier-specific Redis pools
# July 13, 2026 - Pool Retrieval Mismatch Fix

require 'fileutils'

DIVERSITY_ENGINE_FILE = 'lib/services/diversity_engine_service_v2.rb'

puts "🔧 Fixing Diversity Engine pool retrieval to use tier-specific Redis pools..."
puts "="  * 80

# Read the current file
content = File.read(DIVERSITY_ENGINE_FILE)

# Replace the get_pool_memes method to retrieve from tier-specific Redis pools
new_get_pool_memes = <<~RUBY
  # Get memes from specific pool type with viewing history filtering
      def get_pool_memes(pool_type, session_id)
        # FIXED (July 13, 2026): Retrieve directly from tier-specific Redis pools
        # instead of filtering all_memes which caused 0 memes warnings
        
        begin
          redis_key = "meme_pool:\#{pool_type}"  # e.g., "meme_pool:fresh", "meme_pool:surprise"
          
          # Get memes from the tier-specific Redis pool
          pool_json = RedisService.get(redis_key)
          
          if pool_json.nil? || pool_json.empty?
            AppLogger.warn("⚠️  Redis pool '\#{redis_key}' is empty or missing")
            return []
          end
          
          pool_memes = JSON.parse(pool_json)
          
          unless pool_memes.is_a?(Array)
            AppLogger.warn("⚠️  Redis pool '\#{redis_key}' is not an array: \#{pool_memes.class}")
            return []
          end
          
          # Filter out already-seen memes for this session
          seen_urls = get_seen_memes(session_id)
          unseen_memes = pool_memes.reject { |m| seen_urls.include?(m['url']) }
          
          if unseen_memes.size < 10 && pool_memes.size >= 10
            puts "⚠️  Pool '\#{pool_type}' only has \#{unseen_memes.size} unseen memes (total: \#{pool_memes.size}), refreshing seen list"
            # User has seen most of the pool, clear their history to allow revisits
            clear_seen_memes(session_id)
            unseen_memes = pool_memes
          end
          
          unseen_memes
        rescue JSON::ParserError => e
          AppLogger.error("JSON parse error for pool '\#{pool_type}'", error: e.message)
          []
        rescue => e
          AppLogger.error("Error retrieving pool '\#{pool_type}'", error: e.message)
          []
        end
      end
RUBY

# Replace the method in the file
if content.match?(/def get_pool_memes\(pool_type, session_id\).*?end\n/m)
  content.gsub!(/def get_pool_memes\(pool_type, session_id\).*?end\n/m, new_get_pool_memes)
  puts "✅ Replaced get_pool_memes method to use tier-specific Redis pools"
else
  puts "❌ Could not find get_pool_memes method to replace"
  exit 1
end

# Write the updated content back
File.write(DIVERSITY_ENGINE_FILE, content)

puts "\n" + "=" * 80
puts "✅ Diversity Engine fix complete!"
puts "\nChanges:"
puts "  • get_pool_memes now retrieves from 'meme_pool:fresh', 'meme_pool:surprise', 'meme_pool:diverse'"
puts "  • Eliminated attribute-based filtering that returned 0 memes"
puts "  • Maintained viewing history filtering logic"
puts "\nResult: Pools will now properly return memes that were stored by MemePoolManager"
