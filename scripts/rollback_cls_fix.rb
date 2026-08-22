#!/usr/bin/env ruby
# Rollback CLS Fix - Remove problematic skeleton loaders
# Keep ONLY the beneficial optimizations

require 'fileutils'

puts "🔄 Rolling back problematic CLS fixes..."
puts "=" * 60

# Delete the problematic CSS files
puts "Step 1: Removing skeleton loader CSS (caused MORE CLS)..."
File.delete('public/css/ad-cls-fix.css') if File.exist?('public/css/ad-cls-fix.css')
puts "✅ Removed ad-cls-fix.css"

# Keep image-cls-fix.css and content-visibility.css - they're good
puts "✅ Keeping image-cls-fix.css (beneficial)"
puts "✅ Keeping content-visibility.css (beneficial)"

# Remove the ad detector script
puts ""
puts "Step 2: Removing ad-loaded-detector.js..."
File.delete('public/js/ad-loaded-detector.js') if File.exist?('public/js/ad-loaded-detector.js')
puts "✅ Removed ad-loaded-detector.js"

# Update layout.erb to remove the problematic includes
puts ""
puts "Step 3: Updating layout.erb..."
layout_file = 'views/layout.erb'
layout_content = File.read(layout_file)

# Remove ad-cls-fix.css include
layout_content.gsub!(
  /<link rel="stylesheet" href="\/css\/ad-cls-fix\.css">\n?/,
  ''
)

# Remove ad-loaded-detector.js include
layout_content.gsub!(
  /<!-- 🎯 Ad Loaded Detector.*?<script src="\/js\/ad-loaded-detector\.js".*?<\/script>\n?/m,
  ''
)

File.write(layout_file, layout_content)
puts "✅ Updated layout.erb"

puts ""
puts "=" * 60
puts "✅ Rollback Complete!"
puts "=" * 60
puts ""
puts "Kept (beneficial fixes):"
puts "  ✅ Cookie consent optimization (GPU acceleration)"
puts "  ✅ Image aspect ratios (image-cls-fix.css)"
puts "  ✅ Content visibility (content-visibility.css)"
puts ""
puts "Removed (causing problems):"
puts "  ❌ Ad skeleton loaders (ad-cls-fix.css)"
puts "  ❌ Ad loaded detector (ad-loaded-detector.js)"
puts ""
puts "Why removed:"
puts "  • Skeleton loaders reserved 250px space"
puts "  • When Monetag ads don't load, skeletons collapse"
puts "  • This causes WORSE CLS (0.409 vs 0.309)"
puts ""
puts "Actual problem to fix:"
puts "  🚨 Monetag ads aren't loading at all!"
puts "  → Check Monetag zone configuration"
puts "  → Verify data-zone='271359' is correct"
puts "  → Check if domain is approved by Monetag"
puts ""
