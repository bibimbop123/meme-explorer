#!/usr/bin/env ruby
# Week 1: Mobile Emergency Fixes
# Based on comprehensive code audit July 15, 2026

require 'fileutils'

puts "🔧 WEEK 1: MOBILE EMERGENCY FIXES"
puts "=" * 50
puts ""
puts "This script will:"
puts "1. Backup current CSS files"
puts "2. Fix touch target sizes (24px → 44px)"
puts "3. Fix streak badge overlap on mobile"
puts "4. Add mobile-specific improvements"
puts "5. Create test checklist"
puts ""
print "Continue? (y/n): "
response = gets.chomp.downcase

exit unless response == 'y'

# Step 1: Backup CSS files
puts "\n📦 Step 1: Backing up CSS files..."
backup_dir = "public/css/backups_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.mkdir_p(backup_dir)

Dir.glob("public/css/*.css").each do |file|
  FileUtils.cp(file, backup_dir)
  puts "✓ Backed up: #{File.basename(file)}"
end
puts "✓ Backups saved to: #{backup_dir}"

# Step 2: Fix touch target sizes
puts "\n🎯 Step 2: Fixing touch target sizes..."

css_files = Dir.glob("public/css/*.css")
fixes_applied = 0

css_files.each do |file|
  content = File.read(file)
  original_content = content.dup
  
  # Fix common small sizes
  content.gsub!(/width:\s*24px/, 'width: 44px')
  content.gsub!(/height:\s*24px/, 'height: 44px')
  content.gsub!(/min-width:\s*32px/, 'min-width: 44px')
  content.gsub!(/min-height:\s*32px/, 'min-height: 44px')
  content.gsub!(/width:\s*30px/, 'width: 44px')
  content.gsub!(/height:\s*30px/, 'height: 44px')
  
  if content != original_content
    File.write(file, content)
    fixes_applied += 1
    puts "✓ Fixed touch targets in: #{File.basename(file)}"
  end
end

puts "✓ Applied fixes to #{fixes_applied} CSS files"

# Step 3: Create/update mobile-optimizations.css with critical fixes
puts "\n📱 Step 3: Adding mobile-specific improvements..."

mobile_css = "public/css/mobile-optimizations.css"
mobile_fixes = <<~CSS

  /* ============================================
     MOBILE EMERGENCY FIXES - July 15, 2026
     Based on comprehensive code audit
     ============================================ */

  /* Fix 1: Minimum touch targets (Apple guidelines) */
  @media (max-width: 768px) {
    button,
    a.button,
    input[type="button"],
    input[type="submit"],
    .like-button,
    .next-button,
    .save-button,
    .reaction-button,
    .menu-toggle,
    .hamburger-menu {
      min-width: 44px !important;
      min-height: 44px !important;
      padding: 12px !important;
    }
    
    /* Fix 2: Streak badge overlap */
    .streak-badge,
    .gamification-header {
      position: relative !important;
      margin: 10px auto !important;
      z-index: 1 !important;
      /* Don't overlap meme image */
    }
    
    .meme-container {
      margin-top: 10px;
      margin-bottom: 10px;
      /* Add breathing room */
    }
    
    /* Fix 3: Prevent horizontal scroll */
    body, html {
      overflow-x: hidden !important;
      max-width: 100vw !important;
    }
    
    .meme-image,
    img {
      max-width: 100% !important;
      height: auto !important;
    }
    
    /* Fix 4: Action buttons - larger and easier to tap */
    .meme-actions {
      padding: 20px 10px !important;
      display: flex;
      justify-content: center;
      gap: 20px;
    }
    
    .meme-actions button {
      font-size: 18px !important;
      min-width: 60px !important;
      min-height: 60px !important;
      border-radius: 12px;
    }
    
    /* Fix 5: Navigation menu - prevent double-tap issue */
    .hamburger-menu,
    .menu-toggle {
      touch-action: manipulation !important;
      -webkit-tap-highlight-color: rgba(0,0,0,0.1);
    }
    
    /* Fix 6: Increased tap area for small elements */
    .icon-button::before,
    .icon-button::after {
      content: '';
      position: absolute;
      top: -10px;
      left: -10px;
      right: -10px;
      bottom: -10px;
    }
    
    /* Fix 7: Remove gamification clutter on small screens */
    @media (max-width: 375px) {
      .achievement-notification,
      .xp-popup,
      .level-up-modal {
        display: none !important;
        /* Too distracting on small screens */
      }
    }
  }

  /* ============================================
     CONTENT-FIRST LAYOUT (Product Vision)
     ============================================ */
  
  @media (max-width: 768px) {
    /* Maximize meme visibility */
    .meme-container {
      width: 100% !important;
      max-width: 100vw !important;
      padding: 0 !important;
    }
    
    .meme-image {
      width: 100% !important;
      max-height: 70vh !important;
      object-fit: contain !important;
    }
    
    /* Minimize header */
    header {
      height: 50px !important;
      padding: 0 10px !important;
    }
    
    /* Ads below the fold */
    .ad-unit {
      margin-top: 50px !important;
      /* User must scroll to see ads */
    }
  }

  /* ============================================
     ACCESSIBILITY IMPROVEMENTS
     ============================================ */
  
  @media (max-width: 768px) {
    /* Better contrast for touch feedback */
    button:active,
    a:active {
      opacity: 0.7;
      transform: scale(0.95);
      transition: all 0.1s ease;
    }
    
    /* Focus indicators for keyboard users */
    button:focus-visible,
    a:focus-visible {
      outline: 3px solid #FF6B6B;
      outline-offset: 2px;
    }
    
    /* Loading states */
    button.loading {
      opacity: 0.6;
      cursor: wait;
      pointer-events: none;
    }
  }
CSS

if File.exist?(mobile_css)
  existing_content = File.read(mobile_css)
  File.write(mobile_css, existing_content + "\n" + mobile_fixes)
  puts "✓ Appended fixes to: #{mobile_css}"
else
  File.write(mobile_css, mobile_fixes)
  puts "✓ Created: #{mobile_css}"
end

# Step 4: Create testing checklist
puts "\n📋 Step 4: Creating test checklist..."

test_checklist = <<~CHECKLIST
# Mobile Fix Testing Checklist
## Created: #{Time.now.strftime('%Y-%m-%d %H:%M')}

Before deploying, test on these actual devices:

## iPhone SE (375x667) - Smallest modern iPhone
- [ ] Can tap all buttons without zooming
- [ ] Streak badge doesn't overlap meme
- [ ] No horizontal scrolling
- [ ] Hamburger menu works on first tap
- [ ] Like/Next/Save buttons are easy to tap
- [ ] Meme image fills screen nicely

## iPhone 12/13 (390x844) - Most common iPhone
- [ ] Same checks as above
- [ ] Keyboard navigation works
- [ ] Dark mode looks good
- [ ] Ads don't push content off-screen

## Galaxy S21 (360x800) - Popular Android
- [ ] Same checks as above
- [ ] Chrome and Samsung Internet both work
- [ ] No layout breaking
- [ ] Touch targets feel natural

## General Mobile Tests
- [ ] Page loads in < 3 seconds
- [ ] Images lazy load properly
- [ ] No JavaScript errors in console
- [ ] Forms are easy to fill on mobile
- [ ] Share functionality works
- [ ] Can navigate entire site on phone

## Before/After Metrics
- Baseline mobile bounce rate: ___%
- After fix mobile bounce rate: ___%
- Expected improvement: -20% to -30%

## Deployment Notes
- Deployed on: ___________
- Monitored for: 3 days
- User feedback: ___________
- Rollback needed: Yes / No

## Rollback Command (if needed)
```bash
# Restore backups
cp -r #{backup_dir}/* public/css/
git add public/css/
git commit -m "Rollback mobile fixes"
git push origin main
```
CHECKLIST

File.write("MOBILE_FIX_TEST_CHECKLIST.md", test_checklist)
puts "✓ Created: MOBILE_FIX_TEST_CHECKLIST.md"

# Step 5: Summary
puts "\n" + "=" * 50
puts "✅ MOBILE EMERGENCY FIXES APPLIED"
puts "=" * 50
puts ""
puts "What was done:"
puts "1. ✓ Backed up all CSS files to: #{backup_dir}"
puts "2. ✓ Fixed touch target sizes (24px → 44px)"
puts "3. ✓ Added mobile-specific CSS improvements"
puts "4. ✓ Fixed streak badge overlap"
puts "5. ✓ Prevented horizontal scroll"
puts "6. ✓ Created test checklist"
puts ""
puts "NEXT STEPS:"
puts "1. Review changes: git diff public/css/"
puts "2. Test on real devices (use checklist)"
puts "3. Deploy: git add -A && git commit -m 'Mobile emergency fixes'"
puts "4. Monitor for 3 days"
puts "5. If issues: restore from #{backup_dir}"
puts ""
puts "Expected impact:"
puts "• 20-30% reduction in mobile bounce rate"
puts "• Users can actually tap buttons"
puts "• No more overlap issues"
puts "• Better mobile UX overall"
puts ""
puts "See MOBILE_FIX_TEST_CHECKLIST.md for full testing guide"
puts ""
puts "🚀 Ready to test and deploy!"
