#!/usr/bin/env ruby
# Cleanup dead file references from layout.erb
# Removes references to 17 deleted files causing console errors

puts "🧹 Cleaning up dead file references..."

file = 'views/layout.erb'
content = File.read(file)

# Dead CSS files
dead_css = [
  '<link rel="stylesheet" href="/css/phase2-improvements.css">',
  '<link rel="stylesheet" href="/css/gallery-polish.css">',
  '<link rel="stylesheet" href="/css/loading-skeletons.css">',
  '<link rel="stylesheet" href="/css/simplified-ui.css">'
]

# Dead JS files  
dead_js = [
  '<script src="/js/cookie-consent.js"></script>',
  '<script src="/js/sound-system.js"></script>',
  '<script src="/js/haptic-system.js"></script>',
  '<script src="/js/particle-effects.js"></script>',
  '<script src="/js/activity-tracker.js"></script>',
  '<script src="/js/surprise-rewards.js"></script>',
  '<script src="/js/content-feedback.js"></script>',
  '<script src="/js/reactions-v2.js" defer></script>',
  '<script src="/js/keyboard-shortcuts.js" defer></script>',
  '<script src="/js/collapsible-gamification.js" defer></script>',
  '<script src="/js/pwa-install.js" defer></script>',
  '<script src="/js/video-player.js" defer></script>',
  '<script src="/js/hamburger-menu.js" defer></script>'
]

removed = 0

(dead_css + dead_js).each do |dead_ref|
  if content.include?(dead_ref)
    content.gsub!(dead_ref, '')
    removed += 1
    puts "  ❌ Removed: #{dead_ref[0..60]}..."
  end
end

# Clean up cookie consent comment
content.gsub!('<!-- 🍪 EU Cookie Consent - bundled in main.js -->', '')
content.gsub!('  <!-- PropellerAds loaded conditionally via cookie-consent.js (GDPR compliance) -->', '')

File.write(file, content)

puts "\n✅ Cleanup complete!"
puts "   Removed #{removed} dead references"
puts "   No more console errors!"
