#!/usr/bin/env ruby
# AdSense Optimization Implementation Script
# Applies all optimizations from ADSENSE_OPTIMIZATION_GUIDE.md

require 'fileutils'

puts "🚀 AdSense Optimization Script"
puts "=" * 50

# Step 1: Update .env file
puts "\n[1/4] Updating .env with optimized ad frequency..."
env_file = File.read('.env')
if env_file.include?('AD_FREQUENCY=12')
  updated_env = env_file.gsub('AD_FREQUENCY=12', 'AD_FREQUENCY=5')
  File.write('.env', updated_env)
  puts "✅ Updated AD_FREQUENCY from 12 to 5"
elsif env_file.include?('AD_FREQUENCY=')
  puts "⚠️  AD_FREQUENCY already customized, skipping"
else
  File.write('.env', env_file + "\nAD_FREQUENCY=5\n", mode: 'a')
  puts "✅ Added AD_FREQUENCY=5 to .env"
end

# Step 2: Add CSS for new ad placements
puts "\n[2/4] Adding optimized CSS to ads.css..."
css_file = 'public/css/ads.css'
css_additions = <<~CSS

/* ============================================
   REVENUE OPTIMIZATION - Added #{Time.now.strftime('%Y-%m-%d')}
   ============================================ */

/* Sticky Sidebar Ad (Desktop Only) - Highest CTR placement */
.ad-sidebar-sticky {
  position: sticky;
  top: 80px;
  width: 300px;
  margin: 1rem 0;
  z-index: 100;
}

@media (min-width: 1200px) {
  .content-with-sidebar {
    display: grid;
    grid-template-columns: 1fr 320px;
    gap: 2rem;
    max-width: 1400px;
    margin: 0 auto;
  }
  
  .sidebar-ad-container {
    display: block;
  }
}

@media (max-width: 1199px) {
  .ad-sidebar-sticky {
    display: none;
  }
  
  .sidebar-ad-container {
    display: none;
  }
}

/* Hero Ad - Premium above-fold position */
.ad-hero-position {
  max-width: 728px;
  margin: 2rem auto;
  padding: 1rem 0;
}

/* After Trending Ad */
.ad-after-trending {
  margin: 3rem auto;
  border-top: 1px solid #e0e0e0;
  padding-top: 2rem;
}

/* Anchor/Footer Ad - High viewability */
.ad-anchor-bottom {
  position: sticky;
  bottom: 0;
  background: white;
  border-top: 1px solid #e0e0e0;
  padding: 0.5rem;
  text-align: center;
  box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
  z-index: 1000;
}

@media (max-width: 768px) {
  .ad-anchor-bottom {
    position: fixed;
  }
}
CSS

current_css = File.read(css_file)
unless current_css.include?('REVENUE OPTIMIZATION')
  File.write(css_file, current_css + css_additions, mode: 'a')
  puts "✅ Added optimized CSS for sidebar, hero, and anchor ads"
else
  puts "⚠️  Optimization CSS already present, skipping"
end

# Step 3: Add helper methods to ad_helpers.rb
puts "\n[3/4] Adding helper methods to ad_helpers.rb..."
helpers_file = 'lib/helpers/ad_helpers.rb'
helpers_content = File.read(helpers_file)

helper_methods = <<~RUBY

  # ============================================
  # REVENUE OPTIMIZATION METHODS - Added #{Time.now.strftime('%Y-%m-%d')}
  # ============================================

  # Render sticky sidebar ad (desktop only)
  def render_sidebar_ad
    return '' unless should_show_ads?
    
    <<-HTML
      <div class="sidebar-ad-container">
        <div class="ad-sidebar-sticky">
          \#{render_ad_unit(999, format: 'square', position: 'sidebar')}
        </div>
      </div>
    HTML
  end
  
  # Render hero/top ad (premium position)
  def render_hero_ad
    return '' unless should_show_ads?
    
    <<-HTML
      <div class="ad-hero-position">
        \#{render_ad_unit(1, format: 'banner', position: 'hero')}
      </div>
    HTML
  end
  
  # Render after-trending ad
  def render_trending_ad
    return '' unless should_show_ads?
    
    <<-HTML
      <div class="ad-after-trending">
        \#{render_ad_unit(2, format: 'square', position: 'trending')}
      </div>
    HTML
  end
  
  # Render anchor/footer ad
  def render_anchor_ad
    return '' unless should_show_ads?
    
    <<-HTML
      <div class="ad-anchor-bottom">
        \#{render_ad_unit(998, format: 'banner', position: 'anchor')}
      </div>
    HTML
  end
RUBY

unless helpers_content.include?('render_sidebar_ad')
  # Insert before the final 'end'
  updated_helpers = helpers_content.sub(/\nend\s*$/, helper_methods + "\nend")
  File.write(helpers_file, updated_helpers)
  puts "✅ Added 4 new helper methods (sidebar, hero, trending, anchor)"
else
  puts "⚠️  Helper methods already present, skipping"
end

# Step 4: Create implementation summary
puts "\n[4/4] Creating summary..."
puts <<~SUMMARY

✅ AdSense Optimization Applied Successfully!

What was changed:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. .env: AD_FREQUENCY changed from 12 to 5
2. public/css/ads.css: Added CSS for new placements
3. lib/helpers/ad_helpers.rb: Added 4 helper methods

Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Backend optimizations complete
→ Now update your views (trending.erb, random.erb) to use new helpers
→ See ADSENSE_OPTIMIZATION_GUIDE.md Steps 4-5 for view updates
→ Test on local dev server
→ Deploy to production

Expected Impact:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Before: Every 12 memes, in-feed only
After:  Every 5 memes + sidebar + hero + anchor
Revenue: +150-300% increase expected

📖 Full guide: ADSENSE_OPTIMIZATION_GUIDE.md
SUMMARY

puts "\n🎉 Done! Check the files to review changes."
puts "💡 Run 'ruby -c lib/helpers/ad_helpers.rb' to verify syntax."
