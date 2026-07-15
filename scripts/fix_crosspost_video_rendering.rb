#!/usr/bin/env ruby
# Fix Crosspost Video Rendering
# Date: July 15, 2026
# 
# PROBLEM: Crosspost videos not rendering because the code skips ALL videos
#          without checking if they have preview images available
#
# SOLUTION: Extract preview images from video posts (including crossposts)
#           so that video content can still be displayed as static images

require 'fileutils'

FETCHER_FILE = 'lib/services/turbocharged_reddit_fetcher.rb'
BACKUP_DIR = 'backups/crosspost_video_fix_20260715'

puts "🔧 Fixing Crosspost Video Rendering"
puts "=" * 60

# Create backup
FileUtils.mkdir_p(BACKUP_DIR)
FileUtils.cp(FETCHER_FILE, "#{BACKUP_DIR}/turbocharged_reddit_fetcher.rb.backup")
puts "✓ Backup created: #{BACKUP_DIR}"

# Read current file
content = File.read(FETCHER_FILE)

# Find and replace the parse_reddit_response method
new_parse_method = <<'RUBY'
  # Parse Reddit API response with video preview extraction
  def parse_reddit_response(data)
    return [] unless data.is_a?(Hash) && data["data"]
    
    children = data.dig("data", "children") || []
    memes = []
    
    children.each do |post|
      post_data = post["data"]
      next unless post_data
      
      # Quick filtering - skip text-only posts
      next if post_data["is_self"]
      
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
      
      # IMPROVED VIDEO HANDLING: Try to extract preview image from videos
      is_video = source_data["is_video"] == true
      
      # Get image URL efficiently from the right source
      is_gallery = source_data["is_gallery"] == true
      gallery_images = is_gallery ? extract_gallery_images(source_data) : nil
      
      image_url = if gallery_images && gallery_images.any?
                    gallery_images.first["url"]
                  elsif is_video
                    # NEW: Extract video preview/thumbnail
                    extract_video_preview(source_data)
                  else
                    source_data["url"]
                  end
      
      # Skip if no displayable content found
      next unless image_url
      next if image_url.to_s.strip.empty?
      
      # Skip if URL points to video player (not an image)
      next if is_video && !image_url.match?(/\.(jpg|jpeg|png|gif|webp)/i)
      
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
      
      # Mark if this was originally a video (for context)
      if is_video
        meme["was_video"] = true
        meme["video_preview"] = true
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
  
  # Extract preview image from video posts
  def extract_video_preview(post_data)
    # Try multiple sources for video preview images
    
    # 1. Check for preview images (most common)
    if post_data["preview"] && post_data["preview"]["images"]
      images = post_data["preview"]["images"]
      if images.any?
        # Get the highest resolution preview
        source = images.first["source"]
        if source && source["url"]
          # Decode HTML entities in URL
          return source["url"].gsub('&amp;', '&')
        end
        
        # Fallback to resolutions array
        resolutions = images.first["resolutions"]
        if resolutions && resolutions.any?
          # Get highest resolution
          best = resolutions.last
          return best["url"].gsub('&amp;', '&') if best && best["url"]
        end
      end
    end
    
    # 2. Check thumbnail
    thumbnail = post_data["thumbnail"]
    if thumbnail && thumbnail.start_with?("http") && !thumbnail.include?("self")
      return thumbnail
    end
    
    # 3. Check secure media (some videos have preview here)
    if post_data["secure_media"] && post_data["secure_media"]["oembed"]
      oembed = post_data["secure_media"]["oembed"]
      if oembed["thumbnail_url"]
        return oembed["thumbnail_url"]
      end
    end
    
    # 4. Check media
    if post_data["media"] && post_data["media"]["oembed"]
      oembed = post_data["media"]["oembed"]
      if oembed["thumbnail_url"]
        return oembed["thumbnail_url"]
      end
    end
    
    # No preview found
    nil
  end
RUBY

# Replace the parse_reddit_response method
if content =~ /  # Parse Reddit API response.*?^  end\n/m
  # Remove old extract_video_preview if it exists
  content.gsub!(/  # Extract preview image from video posts.*?^  end\n/m, '')
  
  # Replace parse_reddit_response
  content.gsub!(/  # Parse Reddit API response.*?^  end\n/m, new_parse_method)
  
  # Write updated content
  File.write(FETCHER_FILE, content)
  
  puts "✓ Updated #{FETCHER_FILE}"
  puts ""
  puts "Changes made:"
  puts "  - Added extract_video_preview method"
  puts "  - Modified video handling to extract preview images"
  puts "  - Crosspost videos now extract preview from original post"
  puts "  - Added video_preview flag to memes for transparency"
  puts "  - Skip only videos without any displayable preview"
  puts ""
  puts "✅ Fix applied successfully!"
  puts ""
  puts "Next steps:"
  puts "  1. Clear cache: redis-cli FLUSHDB (or restart Redis)"
  puts "  2. Restart server to see changes"
  puts "  3. Crosspost videos will now display as preview images"
  puts "  4. Check logs for 'video_preview: true' on memes"
else
  puts "❌ Could not find parse_reddit_response method"
  puts "File may have been modified. Check manually."
  exit 1
end
