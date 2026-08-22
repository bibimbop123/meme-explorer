#!/usr/bin/env ruby
# CLS (Cumulative Layout Shift) Fix - August 21, 2026
# Target: Reduce CLS from 0.309 to <0.1

require 'fileutils'

puts "🎯 CLS Optimization Deployment"
puts "Current CLS: 0.309 (needs improvement)"
puts "Target CLS: <0.1 (good)"
puts "=" * 60
puts ""

# Fix 1: Optimize Cookie Consent Banner
puts "Fix 1: Optimizing cookie consent banner CSS..."
cookie_css = File.read('public/css/cookie-consent.css')

# Add performance optimizations
optimized_banner = <<~CSS
/* EU Cookie Consent Banner - Monetag GDPR Compliance + CLS Optimized */
#cookie-consent-banner {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: #2c3e50;
  color: white;
  padding: 1.5rem;
  box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.3);
  z-index: 10000;
  
  /* CLS Optimization: GPU acceleration + containment */
  will-change: transform;
  contain: layout style paint;
  transform: translateZ(0); /* Force GPU layer */
  animation: slideUp 0.3s ease-out;
}

@keyframes slideUp {
  from { transform: translate3d(0, 100%, 0); }
  to { transform: translate3d(0, 0, 0); }
}
CSS

cookie_css.gsub!(
  /#cookie-consent-banner \{.*?\}/m,
  optimized_banner.strip
)

File.write('public/css/cookie-consent.css', cookie_css)
puts "✅ Cookie banner optimized with GPU acceleration"

# Fix 2: Reserve Ad Space (CRITICAL for CLS)
puts ""
puts "Fix 2: Creating ad space reservation CSS..."

ad_cls_fix = File.join('public', 'css', 'ad-cls-fix.css')
FileUtils.mkdir_p(File.dirname(ad_cls_fix))

File.write(ad_cls_fix, <<~CSS)
/* Ad Space Reservation - CLS Fix for Monetag Ads */

/* Reserve space for push notification subscriber placeholder */
.onesignal-slidedown-container,
.onesignal-bell-container {
  contain: layout style;
  min-height: 80px; /* Reserve space before load */
}

/* Reserve space for banner ads */
[data-zone],
[id*="propeller"],
[id*="monetag"],
.ad-container,
.ad-placement {
  contain: layout style paint;
  min-height: 250px; /* Standard banner height */
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: skeleton-loading 1.5s infinite;
  position: relative;
}

@keyframes skeleton-loading {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* Ad loaded state - remove skeleton */
[data-zone].ad-loaded,
[id*="propeller"].ad-loaded,
[id*="monetag"].ad-loaded,
.ad-container.ad-loaded,
.ad-placement.ad-loaded {
  background: none;
  animation: none;
  min-height: auto;
}

/* Specific Monetag ad zones */
#monetag-zone-271359 {
  min-height: 250px;
  contain: layout style;
}

/* Interstitial ads - no CLS impact (overlay) */
.interstitial-ad,
.overlay-ad {
  position: fixed !important;
  contain: layout style;
}

/* Mobile ad adjustments */
@media (max-width: 768px) {
  [data-zone],
  [id*="propeller"],
  [id*="monetag"],
  .ad-container,
  .ad-placement {
    min-height: 50px; /* Mobile banner height */
  }
}

/* Dark mode skeleton */
.dark-mode [data-zone],
.dark-mode [id*="propeller"],
.dark-mode [id*="monetag"],
.dark-mode .ad-container,
.dark-mode .ad-placement {
  background: linear-gradient(90deg, #2a2a2a 25%, #1a1a1a 50%, #2a2a2a 75%);
  background-size: 200% 100%;
}
CSS

puts "✅ Created ad-cls-fix.css with space reservation"

# Fix 3: Image Aspect Ratios
puts ""
puts "Fix 3: Adding image aspect ratio CSS..."

image_cls_fix = File.join('public', 'css', 'image-cls-fix.css')

File.write(image_cls_fix, <<~CSS)
/* Image Aspect Ratio - CLS Prevention */

/* Meme images - common aspect ratios */
.meme-image,
.meme-container img,
.random-meme-image,
img[src*="reddit"],
img[src*="imgur"] {
  aspect-ratio: 16 / 9;
  width: 100%;
  height: auto;
  object-fit: contain;
  background: #f5f5f5;
  contain: layout style;
}

/* Square images (profile pics, icons) */
.profile-image,
.achievement-icon,
.badge-icon {
  aspect-ratio: 1 / 1;
  width: 100%;
  height: auto;
  object-fit: cover;
  contain: layout style;
}

/* Vertical/portrait memes */
.meme-image.portrait,
.meme-container.portrait img {
  aspect-ratio: 9 / 16;
}

/* Placeholder while loading */
img:not([src]),
img[src=""],
img.loading {
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: skeleton-loading 1.5s infinite;
  min-height: 200px;
}

/* Lazy loaded images */
img[loading="lazy"] {
  contain: layout style;
}

/* Dark mode placeholders */
.dark-mode img:not([src]),
.dark-mode img[src=""],
.dark-mode img.loading {
  background: linear-gradient(90deg, #2a2a2a 25%, #1a1a1a 50%, #2a2a2a 75%);
}
CSS

puts "✅ Created image-cls-fix.css with aspect ratios"

# Fix 4: Content Visibility Optimizations
puts ""
puts "Fix 4: Adding content-visibility optimizations..."

content_visibility_css = File.join('public', 'css', 'content-visibility.css')

File.write(content_visibility_css, <<~CSS)
/* Content Visibility - Reduce Layout Calculations */

/* Off-screen content optimization */
.meme-list-item:not(:nth-child(-n+3)),
.leaderboard-row:not(:nth-child(-n+10)),
.achievement-card:not(:nth-child(-n+6)) {
  content-visibility: auto;
  contain-intrinsic-size: 0 300px; /* Estimated height */
}

/* Grid items */
.meme-grid .meme-card:not(:nth-child(-n+6)) {
  content-visibility: auto;
  contain-intrinsic-size: 300px 400px;
}

/* Comments/replies that are collapsed */
.comment-thread.collapsed,
.reply-container.hidden {
  content-visibility: hidden;
}

/* Footer - usually off-screen on load */
footer {
  content-visibility: auto;
  contain-intrinsic-size: 0 200px;
}

/* Sidebar widgets */
.sidebar-widget:not(:first-child) {
  content-visibility: auto;
  contain-intrinsic-size: 0 150px;
}
CSS

puts "✅ Created content-visibility.css"

# Fix 5: Update layout.erb to include new CSS files
puts ""
puts "Fix 5: Updating layout.erb to load CLS fix stylesheets..."

layout_file = 'views/layout.erb'
layout_content = File.read(layout_file)

# Add CLS fix stylesheets before closing </head>
cls_includes = <<~HTML
  
  <!-- 🎯 CLS Optimization Stylesheets -->
  <link rel="stylesheet" href="/css/ad-cls-fix.css">
  <link rel="stylesheet" href="/css/image-cls-fix.css">
  <link rel="stylesheet" href="/css/content-visibility.css">
HTML

unless layout_content.include?('ad-cls-fix.css')
  layout_content.gsub!(
    /(<\/head>)/,
    "#{cls_includes}\n\\1"
  )
  File.write(layout_file, layout_content)
  puts "✅ Updated layout.erb with CLS fix stylesheets"
else
  puts "⚠️  CLS fix stylesheets already included in layout.erb"
end

# Fix 6: Add JavaScript to mark ads as loaded
puts ""
puts "Fix 6: Creating ad-loaded detector script..."

ad_loaded_js = File.join('public', 'js', 'ad-loaded-detector.js')

File.write(ad_loaded_js, <<~JAVASCRIPT)
// Ad Loaded Detector - Remove skeleton when ad appears
// Prevents CLS by pre-reserving space, then removing skeleton

(function() {
  'use strict';
  
  // Monitor for ad elements loading
  const adSelectors = [
    '[data-zone]',
    '[id*="propeller"]',
    '[id*="monetag"]',
    '.ad-container',
    '.ad-placement'
  ];
  
  function markAdAsLoaded(element) {
    // Only mark if it has actual content
    if (element.children.length > 0 || element.innerHTML.trim().length > 100) {
      element.classList.add('ad-loaded');
      console.log('✅ Ad loaded, removing skeleton:', element);
    }
  }
  
  // Use MutationObserver to detect when ads load
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1) { // Element node
          adSelectors.forEach(selector => {
            // Check if the node itself matches
            if (node.matches && node.matches(selector)) {
              setTimeout(() => markAdAsLoaded(node), 100);
            }
            // Check children
            node.querySelectorAll && node.querySelectorAll(selector).forEach(ad => {
              setTimeout(() => markAdAsLoaded(ad), 100);
            });
          });
        }
      });
    });
  });
  
  // Start observing
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
  
  // Also check existing elements on load
  document.addEventListener('DOMContentLoaded', () => {
    adSelectors.forEach(selector => {
      document.querySelectorAll(selector).forEach(ad => {
        setTimeout(() => markAdAsLoaded(ad), 500);
      });
    });
  });
  
  console.log('🎯 Ad Loaded Detector initialized - CLS prevention active');
})();
JAVASCRIPT

puts "✅ Created ad-loaded-detector.js"

# Update layout.erb to include the detector script
layout_content = File.read(layout_file)
ad_detector_include = <<~HTML
  
  <!-- 🎯 Ad Loaded Detector - CLS Prevention -->
  <script src="/js/ad-loaded-detector.js" defer></script>
HTML

unless layout_content.include?('ad-loaded-detector.js')
  layout_content.gsub!(
    /(<!-- 🍪 EU Cookie Consent.*?<script src="\/js\/cookie-consent\.js"><\/script>)/m,
    "\\1#{ad_detector_include}"
  )
  File.write(layout_file, layout_content)
  puts "✅ Added ad-loaded-detector.js to layout.erb"
else
  puts "⚠️  ad-loaded-detector.js already included"
end

# Summary
puts ""
puts "=" * 60
puts "✅ CLS Optimization Complete!"
puts "=" * 60
puts ""
puts "Fixes Applied:"
puts "1. ✅ Cookie consent banner - GPU acceleration + containment"
puts "2. ✅ Ad space reservation - min-height skeleton loaders"
puts "3. ✅ Image aspect ratios - prevent image CLS"
puts "4. ✅ Content visibility - reduce layout calculations"
puts "5. ✅ Ad loaded detector - remove skeletons when ads load"
puts ""
puts "New Files Created:"
puts "  • public/css/ad-cls-fix.css"
puts "  • public/css/image-cls-fix.css"
puts "  • public/css/content-visibility.css"
puts "  • public/js/ad-loaded-detector.js"
puts ""
puts "Files Modified:"
puts "  • public/css/cookie-consent.css (optimized)"
puts "  • views/layout.erb (includes added)"
puts ""
puts "Expected Results:"
puts "  CLS: 0.309 → <0.1 ✅"
puts "  LCP: Improved (reduced layout work)"
puts "  FID: Unchanged"
puts "  SEO: Better Core Web Vitals score"
puts ""
puts "Next Steps:"
puts "1. Test locally: ruby scripts/start_dev_server.sh"
puts "2. Check console: Look for '🎯 Ad Loaded Detector initialized'"
puts "3. Verify CLS in DevTools → Lighthouse → Performance"
puts "4. Deploy to production"
puts "5. Monitor Core Web Vitals in Search Console"
puts ""
puts "🎯 CLS optimization deployment complete!"
