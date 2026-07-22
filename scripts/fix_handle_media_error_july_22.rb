#!/usr/bin/env ruby
# Fix handleMediaError undefined error - July 22, 2026
# This script adds the missing handleMediaError function to meme-display.js

require 'fileutils'

puts "🔧 Fixing handleMediaError undefined error..."

# Define the function to add
handle_media_error_function = <<~JS


  // Image error handler - shows fallback when image fails to load
  function handleMediaError(img) {
    if (!img.dataset.errorHandled) {
      img.dataset.errorHandled = 'true';
      
      // Try fallback URL first if available
      const fallbackUrl = img.dataset.fallback;
      if (fallbackUrl && img.src !== fallbackUrl) {
        img.src = fallbackUrl;
        return;
      }
      
      // Show placeholder
      img.src = '/images/meme-placeholder.svg';
      img.alt = 'Image failed to load';
      console.warn('Image failed to load:', img.dataset.originalSrc || img.src);
    }
  }
JS

# Add to meme-display.js
display_js_path = 'public/js/modules/meme-display.js'

if File.exist?(display_js_path)
  content = File.read(display_js_path)
  
  # Check if function already exists
  if content.include?('function handleMediaError')
    puts "✅ handleMediaError already exists in meme-display.js"
  else
    # Add before the last closing brace or at the end
    if content =~ /}\s*$/
      content = content.sub(/}\s*$/, "#{handle_media_error_function}}")
    else
      content += handle_media_error_function
    end
    
    File.write(display_js_path, content)
    puts "✅ Added handleMediaError function to meme-display.js"
  end
else
  puts "❌ meme-display.js not found"
  exit 1
end

puts "✅ Fix complete!"
puts ""
puts "📋 Next steps:"
puts "1. Commit: git add public/js/modules/meme-display.js"
puts "2. Commit: git commit -m 'Add handleMediaError function to fix image error handling'"
puts "3. Deploy: git push origin main"
