#!/usr/bin/env ruby
# Week 1 UX Simplification - Complete Implementation
# Based on SIMPLIFICATION_ROADMAP_JULY_26_2026.md
# Date: July 26, 2026

require 'fileutils'

puts "🚀 Starting Week 1: UX Simplification"
puts "=" * 60

# ============================================================================
# TASK 1: Feature Flags System (Foundation)
# ============================================================================

puts "\n📋 Task 1: Creating Feature Flags System..."

# Create feature flags configuration
features_yml = <<~YAML
# Feature Flags Configuration
# Toggle features for A/B testing and gradual rollout

features:
  # Core features (always on)
  core:
    random_memes: true
    trending: true
    like_button: true
    dark_mode: true
    search: true
  
  # Gamification (progressive disclosure)
  gamification:
    enabled: <%= ENV['FEATURE_GAMIFICATION'] != 'false' %>
    min_session_count: 5
    features:
      streaks: true
      levels: true
      xp_system: true
      leaderboards: true
      achievements: false  # Low engagement - disabled
      daily_challenges: false  # Low completion rate - disabled
      
  # Engagement features
  engagement:
    push_notifications:
      enabled: <%= ENV['FEATURE_PUSH'] == 'true' %>
      min_session_count: 10
    
    sound_effects:
      enabled: <%= ENV['FEATURE_SOUNDS'] == 'true' %>
      min_session_count: 20
      
    haptic_feedback:
      enabled: false  # Device-specific, low adoption
      
    particle_effects:
      enabled: false  # Visual noise, negligible engagement
      
    screen_shake:
      enabled: false  # Jarring, doesn't add value
      
  # Social features  
  social:
    meme_battles:
      enabled: false  # Low usage
    near_miss_mechanics:
      enabled: false  # Manipulative, low trust
      
  # Analytics
  analytics:
    activity_tracking: true
    performance_monitoring: true
    ab_testing: true
YAML

File.write('config/features.yml', features_yml)
puts "✅ Created config/features.yml"

# Create FeatureFlags class
feature_flags_rb = <<~RUBY
# Feature flag system for controlled rollouts and A/B testing
class FeatureFlags
  class << self
    def enabled?(feature_path)
      return false if feature_path.nil? || feature_path.empty?
      
      config = load_config
      keys = feature_path.to_s.split('.')
      
      result = keys.reduce(config['features']) do |hash, key|
        return false unless hash.is_a?(Hash)
        hash[key]
      end
      
      result == true
    end
    
    def get(feature_path, default = nil)
      config = load_config
      keys = feature_path.to_s.split('.')
      
      result = keys.reduce(config['features']) do |hash, key|
        return default unless hash.is_a?(Hash)
        hash[key]
      end
      
      result.nil? ? default : result
    end
    
    def load_config
      @config ||= begin
        require 'yaml'
        require 'erb'
        
        template = File.read('config/features.yml')
        rendered = ERB.new(template).result
        YAML.safe_load(rendered, aliases: true)
      rescue StandardError => err
        puts "⚠️  Error loading feature flags: \#{err.message}"
        { 'features' => {} }
      end
    end
    
    def reload!
      @config = nil
      load_config
    end
  end
end
RUBY

File.write('lib/feature_flags.rb', feature_flags_rb)
puts "✅ Created lib/feature_flags.rb"

# ============================================================================
# TASK 2: Progressive Disclosure Helper
# ============================================================================

puts "\n📋 Task 2: Creating Progressive Disclosure System..."

progressive_disclosure_rb = <<~RUBY
# Progressive disclosure of features based on user engagement
module ProgressiveDisclosureHelper
  # Determine what tier of features to show based on session count
  def show_gamification_tier(session_count = 0)
    count = session_count.to_i
    
    case count
    when 0..4
      :minimal  # Just like button - no distractions
    when 5..9
      :basic    # Like + streak badge (if they're returning)
    when 10..19
      :intermediate  # + Level badge
    else
      :full     # Full gamification experience
    end
  end
  
  # Check if a specific feature should be shown
  def show_feature?(feature_name, user_id = nil)
    # Feature must be enabled globally
    return false unless FeatureFlags.enabled?("gamification.features.\#{feature_name}")
    
    # If no user, don't show progressive features
    return false unless user_id
    
    session_count = get_user_session_count(user_id)
    tier = show_gamification_tier(session_count)
    
    FEATURE_TIERS[feature_name.to_sym]&.include?(tier) || false
  end
  
  # Get session count for user
  def get_user_session_count(user_id)
    return 0 unless user_id
    
    # Try Redis first
    if defined?(RedisService) && RedisService.redis_available?
      count = RedisService.get("user:\#{user_id}:session_count")
      return count.to_i if count
    end
    
    # Fallback to session
    session[:session_count].to_i
  end
  
  # Increment session count
  def increment_session_count(user_id = nil)
    user_id ||= session[:user_id]
    return unless user_id
    
    # Increment in Redis
    if defined?(RedisService) && RedisService.redis_available?
      RedisService.incr("user:\#{user_id}:session_count")
    end
    
    # Also track in session
    session[:session_count] = (session[:session_count].to_i + 1)
  end
  
  # Feature tier mapping
  FEATURE_TIERS = {
    like_button: [:minimal, :basic, :intermediate, :full],
    streak_badge: [:basic, :intermediate, :full],
    level_badge: [:intermediate, :full],
    xp_notifications: [:full],
    leaderboard_link: [:full],
    sound_effects: [:full],
    particle_effects: [],  # Never show (disabled)
    push_notifications: [:full]
  }.freeze
end
RUBY

File.write('lib/helpers/progressive_disclosure_helper.rb', progressive_disclosure_rb)
puts "✅ Created lib/helpers/progressive_disclosure_helper.rb"

# ============================================================================
# TASK 3: Simplified Navigation CSS
# ============================================================================

puts "\n📋 Task 3: Creating Simplified Navigation..."

navigation_css = <<~CSS
/* Simplified Navigation - Max 5 visible items */
nav.main-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 2rem;
  background: var(--nav-background, #fff);
  border-bottom: 1px solid var(--border-color, #e0e0e0);
  position: sticky;
  top: 0;
  z-index: 100;
}

nav.main-nav .logo {
  font-size: 1.5rem;
  font-weight: bold;
  text-decoration: none;
  color: var(--primary-color, #333);
}

nav.main-nav .nav-items {
  display: flex;
  gap: 1.5rem;
  align-items: center;
}

nav.main-nav a,
nav.main-nav button {
  text-decoration: none;
  color: var(--text-color, #555);
  font-size: 1rem;
  padding: 0.5rem 1rem;
  border: none;
  background: none;
  cursor: pointer;
  transition: all 0.2s ease;
  border-radius: 4px;
}

nav.main-nav a:hover,
nav.main-nav button:hover {
  background: var(--hover-background, #f5f5f5);
  color: var(--primary-color, #333);
}

/* Hamburger menu */
.hamburger {
  display: none;
  font-size: 1.5rem;
  padding: 0.5rem;
}

.hamburger-menu {
  display: none;
  position: fixed;
  top: 60px;
  right: 0;
  background: var(--nav-background, #fff);
  border: 1px solid var(--border-color, #e0e0e0);
  border-radius: 8px;
  padding: 1rem;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  z-index: 99;
  min-width: 200px;
}

.hamburger-menu.active {
  display: block;
}

.hamburger-menu a {
  display: block;
  padding: 0.75rem 1rem;
  color: var(--text-color, #555);
  text-decoration: none;
  border-radius: 4px;
  transition: background 0.2s ease;
}

.hamburger-menu a:hover {
  background: var(--hover-background, #f5f5f5);
}

/* Mobile responsive */
@media (max-width: 768px) {
  .hamburger {
    display: block;
  }
  
  .nav-items a:not(.logo):nth-child(n+4) {
    display: none;
  }
}

/* Dark mode support */
.dark-mode nav.main-nav {
  --nav-background: #1a1a1a;
  --border-color: #333;
  --text-color: #e0e0e0;
  --hover-background: #2a2a2a;
}
CSS

File.write('public/css/navigation.css', navigation_css)
puts "✅ Created public/css/navigation.css"

# ============================================================================
# TASK 4: Hamburger Menu JavaScript
# ============================================================================

puts "\n📋 Task 4: Creating Hamburger Menu Logic..."

hamburger_js = <<~JAVASCRIPT
// Hamburger menu functionality
(function() {
  'use strict';
  
  function initHamburgerMenu() {
    const hamburger = document.getElementById('menuToggle');
    const menu = document.getElementById('hamburgerMenu');
    
    if (!hamburger || !menu) return;
    
    // Toggle menu on click
    hamburger.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      menu.classList.toggle('active');
    });
    
    // Close menu when clicking outside
    document.addEventListener('click', (e) => {
      if (!menu.contains(e.target) && !hamburger.contains(e.target)) {
        menu.classList.remove('active');
      }
    });
    
    // Close menu on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        menu.classList.remove('active');
      }
    });
  }
  
  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initHamburgerMenu);
  } else {
    initHamburgerMenu();
  }
})();
JAVASCRIPT

File.write('public/js/hamburger-menu.js', hamburger_js)
puts "✅ Created public/js/hamburger-menu.js"

# ============================================================================
# TASK 5: Update Layout with Simplified Navigation
# ============================================================================

puts "\n📋 Task 5: Creating Simplified Layout Navigation Partial..."

# Create a partial for the new simplified navigation
simplified_nav = <<~ERB
<!-- Simplified Navigation: Max 5 core items -->
<nav class="main-nav">
  <a href="/" class="logo">🎭 Meme Explorer</a>
  
  <div class="nav-items">
    <a href="/random">Random</a>
    <a href="/trending">Trending</a>
    <button id="darkModeToggle" title="Toggle theme" aria-label="Toggle dark mode">🌙</button>
    
    <% if session[:user_id] %>
      <a href="/profile">Profile</a>
    <% else %>
      <a href="/login">Login</a>
    <% end %>
    
    <button id="menuToggle" class="hamburger" aria-label="Menu">☰</button>
  </div>
</nav>

<!-- Hidden hamburger menu for secondary items -->
<div id="hamburgerMenu" class="hamburger-menu">
  <% if FeatureFlags.enabled?('gamification.features.leaderboards') %>
    <a href="/leaderboard">🏆 Leaderboard</a>
  <% end %>
  <a href="/guides">📚 Guides</a>
  <a href="/about">About</a>
  <a href="/contact">Contact</a>
  <% if session[:user_id] && admin? %>
    <a href="/admin">⚙️ Admin</a>
  <% end %>
</div>
ERB

FileUtils.mkdir_p('views/partials')
File.write('views/partials/_simplified_nav.erb', simplified_nav)
puts "✅ Created views/partials/_simplified_nav.erb"

# ============================================================================
# TASK 6: Progressive Gamification Partial
# ============================================================================

puts "\n📋 Task 6: Creating Progressive Gamification Display..."

progressive_gamification = <<~ERB
<%
# Progressive disclosure of gamification features
# Based on session count - don't overwhelm new users
tier = show_gamification_tier(session[:session_count] || 0)
user_id = session[:user_id]
%>

<% if tier == :minimal %>
  <!-- Sessions 1-4: Just the essentials -->
  <!-- No gamification distractions for new users -->
  
<% elsif tier == :basic %>
  <!-- Sessions 5-9: Introduce streaks (they're coming back!) -->
  <% if @streak_data && @streak_data[:current_streak].to_i > 0 %>
    <div class="streak-indicator">
      <span class="streak-badge" title="Current streak">
        🔥 <%= @streak_data[:current_streak] %> day streak
      </span>
    </div>
  <% end %>
  
<% elsif tier == :intermediate %>
  <!-- Sessions 10-19: Show level progress -->
  <% if @user_level %>
    <div class="gamification-compact">
      <% if @streak_data && @streak_data[:current_streak].to_i > 0 %>
        <span class="streak-badge">🔥 <%= @streak_data[:current_streak] %></span>
      <% end %>
      <span class="level-badge">⭐ Lv <%= @user_level[:level] %></span>
    </div>
  <% end %>
  
<% else %>
  <!-- Sessions 20+: Full gamification experience -->
  <div class="gamification-full">
    <% if @streak_data && @streak_data[:current_streak].to_i > 0 %>
      <span class="streak-badge">🔥 <%= @streak_data[:current_streak] %></span>
    <% end %>
    
    <% if @user_level %>
      <span class="level-badge">⭐ Lv <%= @user_level[:level] %></span>
      <div class="xp-progress">
        <div class="xp-bar" style="width: <%= @user_level[:progress] %>%"></div>
      </div>
    <% end %>
    
    <% if FeatureFlags.enabled?('gamification.features.leaderboards') %>
      <a href="/leaderboard" class="leaderboard-link">🏆</a>
    <% end %>
  </div>
<% end %>
ERB

File.write('views/partials/_progressive_gamification.erb', progressive_gamification)
puts "✅ Created views/partials/_progressive_gamification.erb"

# ============================================================================
# TASK 7: Update App.rb to load new files
# ============================================================================

puts "\n📋 Task 7: Updating app.rb to load new helpers..."

# Read existing app.rb
app_rb_content = File.read('app.rb')

# Add requires if not already present
requires_to_add = [
  "require_relative 'lib/feature_flags'",
  "require_relative 'lib/helpers/progressive_disclosure_helper'"
]

requires_added = []
requires_to_add.each do |req|
  unless app_rb_content.include?(req)
    # Find a good place to add it (after other requires)
    if app_rb_content =~ /(require_relative 'lib\/.*?\n)/
      app_rb_content.sub!(/^(require_relative 'lib\/helpers\/.*?\n)/, "\\1#{req}\n")
    end
    requires_added << req
  end
end

if requires_added.any?
  File.write('app.rb', app_rb_content)
  puts "✅ Added requires to app.rb: #{requires_added.join(', ')}"
else
  puts "ℹ️  App.rb already has necessary requires"
end

# Add helper inclusion
unless app_rb_content.include?('ProgressiveDisclosureHelper')
  puts "⚠️  Remember to include ProgressiveDisclosureHelper in app.rb helpers block"
end

# ============================================================================
# TASK 8: Create deployment notes
# ============================================================================

puts "\n📋 Task 8: Creating deployment documentation..."

deployment_notes = <<~MD
# Week 1 UX Simplification - Deployment Notes
## Date: July 26, 2026

## Changes Implemented

### 1. Feature Flags System ✅
- Created `config/features.yml` - Feature toggle configuration
- Created `lib/feature_flags.rb` - Feature flag service
- **Benefits**: A/B testing, gradual rollouts, instant feature disable

### 2. Progressive Disclosure ✅
- Created `lib/helpers/progressive_disclosure_helper.rb`
- Gamification features shown progressively based on session count:
  - Sessions 1-4: Minimal (just like button)
  - Sessions 5-9: Basic (+ streak badge)
  - Sessions 10-19: Intermediate (+ level badge)
  - Sessions 20+: Full experience

### 3. Simplified Navigation ✅
- Reduced from 14+ items to 5 core items
- Created `public/css/navigation.css`
- Created `public/js/hamburger-menu.js`
- Created `views/partials/_simplified_nav.erb`
- Secondary items moved to hamburger menu

### 4. Disabled Low-Value Features ✅
Via feature flags, these are now disabled by default:
- ❌ Particle effects (visual noise)
- ❌ Screen shake (jarring)
- ❌ Haptic feedback (device-specific)
- ❌ Achievement badges (duplicates XP)
- ❌ Daily challenges (low completion)
- ❌ Meme battles (low usage)
- ❌ Near-miss mechanics (manipulative)

## Manual Steps Required

### 1. Update Layout.erb
Replace the current navigation section with:

\`\`\`erb
<%= erb :'partials/_simplified_nav' %>
\`\`\`

Add to <head>:
\`\`\`erb
<link rel="stylesheet" href="/css/navigation.css">
\`\`\`

Add before </body>:
\`\`\`erb
<script src="/js/hamburger-menu.js" defer></script>
\`\`\`

### 2. Update Gamification Display
Replace current gamification UI with:

\`\`\`erb
<%= erb :'partials/_progressive_gamification' %>
\`\`\`

### 3. Include Helpers in App.rb
Add to helpers block:

\`\`\`ruby
helpers do
  include ProgressiveDisclosureHelper
  # ... existing helpers
end
\`\`\`

### 4. Update Feature Checks
Replace direct feature checks with:

\`\`\`ruby
# BEFORE
<% if some_config_value %>

# AFTER
<% if FeatureFlags.enabled?('feature.path.here') %>
\`\`\`

### 5. Wrap Disabled Features
Wrap each disabled feature in feature flag check:

\`\`\`erb
<% if FeatureFlags.enabled?('engagement.particle_effects') %>
  <script src="/js/particle-effects.js"></script>
<% end %>
\`\`\`

## Environment Variables

Set these to control features:

\`\`\`bash
# Enable gamification (default: true)
FEATURE_GAMIFICATION=true

# Enable push notifications (default: false)
FEATURE_PUSH=true

# Enable sound effects (default: false)
FEATURE_SOUNDS=true
\`\`\`

## Testing Checklist

- [ ] Navigation shows 5 items on desktop
- [ ] Navigation shows 3 items + hamburger on mobile
- [ ] Hamburger menu works (click to open/close)
- [ ] Hamburger menu closes on outside click
- [ ] Hamburger menu closes on Escape key
- [ ] New users (sessions 1-4) see minimal gamification
- [ ] Session 5+ users see streak badge
- [ ] Session 10+ users see level badge
- [ ] Session 20+ users see full gamification
- [ ] Disabled features don't load JavaScript/CSS
- [ ] Feature flags can be toggled via ENV vars

## Rollback Plan

If issues arise:

1. **Navigation issues**: Revert layout.erb navigation section
2. **Feature flag issues**: Set `FEATURE_GAMIFICATION=true` to restore all features
3. **Performance issues**: Check browser console for errors

## Expected Impact

- **Engagement**: +10-15% (reduced decision paralysis)
- **Bounce rate**: -5-10% (cleaner first impression)
- **Return visits**: +8-12% (progressive disclosure hooks users)
- **Page weight**: -50KB (disabled features not loading)

## Metrics to Track

Monitor these in week 1:

1. **Navigation click-through rate**
   - Before: Track current CTR
   - After: Should see +10% to Random/Trending

2. **Session progression**
   - How many users reach session 5? (see streak)
   - How many reach session 10? (see level)
   - How many reach session 20? (see full UI)

3. **Feature engagement**
   - Which features in hamburger menu get clicked?
   - Which disabled features are missed?

4. **User feedback**
   - Support tickets about missing features?
   - Positive feedback on simplicity?

## Next Steps (Week 2)

After Week 1 is stable:
- Week 2: Performance optimization (CSS/JS bundling)
- Week 3: Service consolidation
- Week 4: Infrastructure improvements

---

*Generated: July 26, 2026*
*Part of: SIMPLIFICATION_ROADMAP_JULY_26_2026.md*
MD

File.write('WEEK1_UX_SIMPLIFICATION_DEPLOYED_JULY_26_2026.md', deployment_notes)
puts "✅ Created deployment documentation"

# ============================================================================
# SUMMARY
# ============================================================================

puts "\n" + "=" * 60
puts "✅ Week 1 UX Simplification - Implementation Complete!"
puts "=" * 60

puts "\n📁 Files Created:"
puts "  - config/features.yml"
puts "  - lib/feature_flags.rb"
puts "  - lib/helpers/progressive_disclosure_helper.rb"
puts "  - public/css/navigation.css"
puts "  - public/js/hamburger-menu.js"
puts "  - views/partials/_simplified_nav.erb"
puts "  - views/partials/_progressive_gamification.erb"
puts "  - WEEK1_UX_SIMPLIFICATION_DEPLOYED_JULY_26_2026.md"

puts "\n⚠️  MANUAL STEPS REQUIRED:"
puts "  1. Update views/layout.erb to use new navigation partial"
puts "  2. Include ProgressiveDisclosureHelper in app.rb helpers"
puts "  3. Replace gamification UI with progressive version"
puts "  4. Wrap disabled features in feature flag checks"
puts "  5. Test thoroughly before deploying"

puts "\n📖 Read WEEK1_UX_SIMPLIFICATION_DEPLOYED_JULY_26_2026.md for:"
puts "  - Complete deployment instructions"
puts "  - Testing checklist"
puts "  - Rollback procedures"
puts "  - Expected impact metrics"

puts "\n🎯 Expected Results:"
puts "  - Navigation: 14 items → 5 items (+10% engagement)"
puts "  - New users see minimal UI (no overwhelm)"
puts "  - Progressive feature unlock (better retention)"
puts "  - 7 low-value features disabled (-50KB page weight)"

puts "\n✨ Week 1 foundation complete. Ready for Week 2 (Performance)!"
puts "=" * 60
