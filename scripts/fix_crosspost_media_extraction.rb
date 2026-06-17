#!/usr/bin/env ruby
# Fix Crosspost Media Extraction
# Date: June 17, 2026
# 
# PROBLEM: Crossposts show "content not available" because image URL
#          is in crosspost_parent_list, not directly on the post
#
# SOLUTION: Extract media from original post within crosspost data

require 'fileutils'

FETCHER_FILE = 'lib/services/turbocharged_reddit_fetcher.rb'
BACKUP_DIR = 'backups/crosspost_fix_20260617'

puts "🔧 Fixing Crosspost Media Extraction"
puts "=" * 60

# Create backup
FileUtils.mkdir_p(BACKUP_DIR)
FileUtils.cp(FETCHER_FILE, "#{BACKUP_DIR}/turbocharged_reddit_fetcher.rb.backup")
puts "✓ Backup created: #{BACKUP_DIR}"

# Read current file
content = File.read(FETCHER_FILE)

# Find the parse_reddit_response method and update it
new_parse_method = <<'RUBY'
  # Parse Reddit API response (same logic as original, optimized)
  def parse_reddit_response(data)
    return [] unless data.is_a?(Hash) && data["data"]
    
    children = data.dig("data", "children") || []
    memes = []
    
    children.each do |post|
      post_data = post["data"]
      next unless post_data
      
      # Quick filtering - expensive checks later in quality pipeline
      next if post_data["is_self"]
      next if post_data["is_video"] && !post_data["is_gallery"]
      
      # CROSSPOST FIX: Extract data from original post if this is a crosspost
      if post_data["is_crosspost"] && post_data["crosspost_parent_list"]&.any?
        original_post = post_data["crosspost_parent_list"].first
        
        # Use original post data for media extraction
        # But keep current post's subreddit/title for context
        source_data = original_post
        is_crosspost = true
        crosspost_subreddit = post_data["subreddit"]
        original_subreddit = original_post["subreddit"]
      else
        source_data = post_data
        is_crosspost = false
      end
      
      # Get image URL efficiently from the right source
      is_gallery = source_data["is_gallery"] == true
      gallery_images = is_gallery ? extract_gallery_images(source_data) : nil
      
      image_url = if gallery_images && gallery_images.any?
                    gallery_images.first["url"]
                  else
                    source_data["url"]
                  end
      
      next unless image_url
      
      # Build meme object with variety-preserving data
      meme = {
        "title" => post_data["title"],
        "url" => image_url,
        "subreddit" => post_data["subreddit"],
        "likes" => post_data["ups"] || 0,
        "permalink" => post_data["permalink"],
        "created_utc" => post_data["created_utc"]
      }
      
      # Add crosspost metadata if this is a crosspost
      if is_crosspost
        meme["is_crosspost"] = true
        meme["original_subreddit"] = original_subreddit
        meme["crossposted_from"] = "r/#{original_subreddit}"
      end
      
      # Add gallery data if present
      if is_gallery && gallery_images && gallery_images.any?
        meme["is_gallery"] = true
        meme["gallery_images"] = gallery_images
      end
      
      memes << meme
    end
    
    memes
  end
RUBY

# Replace the parse_reddit_response method
if content =~ /  # Parse Reddit API response.*?^  end\n/m
  content.gsub!(/  # Parse Reddit API response.*?^  end\n/m, new_parse_method)
  
  # Write updated content
  File.write(FETCHER_FILE, content)
  
  puts "✓ Updated #{FETCHER_FILE}"
  puts ""
  puts "Changes made:"
  puts "  - Extract media from crosspost_parent_list when present"
  puts "  - Use original post's URL/gallery for crossposts"
  puts "  - Add crosspost metadata to meme object"
  puts "  - Mark crossposts with is_crosspost flag"
  puts ""
  puts "✅ Fix applied successfully!"
  puts ""
  puts "Next steps:"
  puts "  1. Clear cache: redis-cli FLUSHDB"
  puts "  2. Restart server to see changes"
  puts "  3. Crossposts will now display correctly with proper images"
else
  puts "❌ Could not find parse_reddit_response method"
  puts "File may have been modified. Check manually."
  exit 1
end
