# 🚀 Meme Explorer Simplification Roadmap
## From Feature-Rich to User-Focused | July 26, 2026

**Goal**: Transform from 83% (B+) to 91% (A-) through strategic simplification  
**Timeline**: 4 weeks  
**Philosophy**: **Less is more** - Remove features, improve experience

---

## 📊 Current State vs Target

| Metric | Current | Target | Impact |
|--------|---------|--------|---------|
| Navigation Items | 14 | 5 | +10% engagement |
| CSS Files | 20+ | 3 | -500ms load time |
| Layout.erb Lines | 675 | 150 | Better maintainability |
| Service Classes | 50+ | 30 | -40% code complexity |
| Gamification Features | 16 | 5 | Focused experience |
| Migration Files | 40+ | 10 active | Clearer schema |

---

## 🎯 WEEK 1: UX Simplification (Priority: P0)

**Goal**: Reduce cognitive load, increase engagement  
**Expected Impact**: +10-15% user engagement

### Monday: Navigation Simplification (4 hours)

**Task**: Reduce navigation from 14 items to 5 core items

```erb
<!-- File: views/layout.erb -->
<!-- BEFORE (14 items) -->
<nav>
  <button class="dark-mode-toggle">🌙</button>
  <button class="sound-toggle">🔊</button>
  <a href="/trending">Trending</a>
  <a href="/leaderboard">🏆 Leaderboard</a>
  <a href="/blog">📝 Blog</a>
  <a href="/guides">📚 Guides</a>
  <a href="/metrics">📈 Metrics</a>
  <a href="/random">Random 🎲</a>
  <!-- ... 6 more -->
</nav>

<!-- AFTER (5 items) -->
<nav>
  <a href="/" class="logo">Meme Explorer 🎭</a>
  <a href="/random">Random</a>
  <a href="/trending">Trending</a>
  <button id="darkModeToggle" title="Toggle theme">🌙</button>
  <% if session[:user_id] %>
    <a href="/profile">Profile</a>
  <% else %>
    <a href="/login">Login</a>
  <% end %>
  <button id="menuToggle" class="hamburger">☰</button>
</nav>

<!-- Hidden dropdown menu for secondary items -->
<div id="hamburgerMenu" class="hidden">
  <a href="/leaderboard">Leaderboard</a>
  <a href="/guides">Guides</a>
  <a href="/blog">Blog</a>
  <a href="/about">About</a>
  <a href="/contact">Contact</a>
</div>
```

**Files to modify**:
- `views/layout.erb` (lines 244-270)
- `public/css/navigation.css` (new file)
- `public/js/hamburger-menu.js` (new file)

**Testing**:
- [ ] Desktop: 5 nav items visible
- [ ] Mobile: 3 nav items + hamburger
- [ ] Hamburger menu shows secondary items
- [ ] Measure click-through rate before/after

---

### Tuesday: Progressive Disclosure for Gamification (6 hours)

**Task**: Show features progressively, not all at once

```ruby
# File: lib/helpers/progressive_disclosure_helper.rb
module ProgressiveDisclosureHelper
  def show_gamification_tier(session_count)
    case session_count
    when 0..4
      :minimal  # Just like button
    when 5..9
      :basic    # Like + streak badge
    when 10..19
      :intermediate  # + Level badge
    else
      :full     # + XP notifications + leaderboard
    end
  end
  
  def show_feature?(feature_name, user_id = nil)
    return false unless user_id
    
    session_count = get_user_session_count(user_id)
    tier = show_gamification_tier(session_count)
    
    FEATURE_TIERS[feature_name]&.include?(tier)
  end
  
  FEATURE_TIERS = {
    like_button: [:minimal, :basic, :intermediate, :full],
    streak_badge: [:basic, :intermediate, :full],
    level_badge: [:intermediate, :full],
    xp_notifications: [:full],
    leaderboard_link: [:full],
    sound_effects: [:full],
    particle_effects: [:full],
    push_notifications: [:full]
  }.freeze
end
```

**View updates**:
```erb
<!-- File: views/layout.erb -->
<% tier = show_gamification_tier(session[:session_count] || 0) %>

<% if tier == :minimal %>
  <!-- First 5 visits: Just show the meme and like button -->
  <!-- No badges, no notifications, no distractions -->
<% elsif tier == :basic %>
  <!-- Visits 5-9: Introduce streaks if they're coming back -->
  <% if @streak_data && @streak_data[:current_streak].to_i > 0 %>
    <span class="streak-badge">🔥 <%= @streak_data[:current_streak] %></span>
  <% end %>
<% elsif tier == :intermediate %>
  <!-- Visits 10-19: Show level progress -->
  <% if @user_level %>
    <span class="level-badge">⭐ Lv <%= @user_level[:level] %></span>
  <% end %>
<% else %>
  <!-- Visits 20+: Full experience -->
  <!-- All gamification features unlocked -->
<% end %>
```

**Files to create/modify**:
- `lib/helpers/progressive_disclosure_helper.rb` (new)
- `views/layout.erb` (modify gamification display logic)
- `routes/random_meme.rb` (add session counter)

**Testing**:
- [ ] Session 1-4: Only like button visible
- [ ] Session 5: Streak badge appears
- [ ] Session 10: Level badge appears
- [ ] Session 20: Full features unlocked
- [ ] A/B test engagement vs current full-feature approach

---

### Wednesday: Feature Flag System (4 hours)

**Task**: Create config-based feature toggles for easy A/B testing

```yaml
# File: config/features.yml
features:
  # Core features (always on)
  core:
    random_memes: true
    trending: true
    like_button: true
    dark_mode: true
  
  # Progressive features (can be toggled)
  gamification:
    enabled: <%= ENV['FEATURE_GAMIFICATION'] != 'false' %>
    min_session_count: 5
    features:
      streaks: true
      levels: true
      xp_system: true
      leaderboards: true
      achievements: false  # Disabled by default
      daily_challenges: false
      
  engagement:
    push_notifications:
      enabled: <%= ENV['FEATURE_PUSH'] == 'true' %>
      min_session_count: 10
    
    sound_effects:
      enabled: <%= ENV['FEATURE_SOUNDS'] == 'true' %>
      min_session_count: 20
      
    particle_effects:
      enabled: false  # Disabled - low value, high complexity
      
  analytics:
    activity_tracking: true
    performance_monitoring: true
    ab_testing: true
```

```ruby
# File: lib/feature_flags.rb
class FeatureFlags
  class << self
    def enabled?(feature_path)
      config = load_config
      keys = feature_path.split('.')
      
      result = keys.reduce(config) do |hash, key|
        hash&.dig(key)
      end
      
      result == true
    end
    
    def load_config
      @config ||= YAML.load_file('config/features.yml', aliases: true)
    end
    
    def reload!
      @config = nil
      load_config
    end
  end
end

# Usage in routes/views:
# <% if FeatureFlags.enabled?('gamification.features.streaks') %>
#   <%= render 'streak_badge' %>
# <% end %>
```

**Files to create/modify**:
- `config/features.yml` (new)
- `lib/feature_flags.rb` (new)
- Update all feature checks to use `FeatureFlags.enabled?`

---

### Thursday-Friday: Remove Low-Value Features (8 hours)

**Task**: Disable or remove features with <5% engagement

**Features to Disable** (via feature flags):
- [ ] Particle effects (visual noise, negligible engagement)
- [ ] Screen shake on level-up (jarring, doesn't add value)
- [ ] Haptic feedback (device-specific, low adoption)
- [ ] Achievement badges (duplicates XP/levels)
- [ ] Daily challenges (low completion rate)
- [ ] Meme battles (low usage)
- [ ] Near-miss mechanics (manipulative, low trust)

**Implementation**:
```ruby
# Wrap each feature in feature flag check
<% if FeatureFlags.enabled?('engagement.particle_effects') %>
  <script src="/js/particle-effects.js" defer></script>
<% end %>
```

**Metrics to track**:
- Engagement rate before/after
- Session duration
- Return rate
- User feedback

**Rollback plan**: Re-enable via ENV var if engagement drops >5%

---

## ⚡ WEEK 2: Performance & Asset Optimization (Priority: P1)

**Goal**: Reduce page load time by 500ms+  
**Expected Impact**: +5-10% user retention

### Monday: CSS Consolidation (3 hours)

**Task**: Combine 20+ CSS files into 3 optimized bundles

```bash
# Create build script
# File: scripts/build_assets.sh

#!/bin/bash
set -e

echo "🎨 Building CSS bundles..."

# Bundle 1: Critical CSS (inline in <head>)
cat public/css/theme.css \
    public/css/meme_explorer.css \
    public/css/grid-layout-v3.css \
    > public/css/critical.min.css

# Bundle 2: Page-specific CSS (defer load)
cat public/css/animations.css \
    public/css/refined-aesthetic.css \
    public/css/mobile-optimizations-v2.css \
    public/css/image-optimization.css \
    > public/css/page.min.css

# Bundle 3: Feature CSS (conditional load)
cat public/css/ads.css \
    public/css/achievements.css \
    public/css/streaks.css \
    public/css/leaderboard.css \
    > public/css/features.min.css

# Minify (using csso or similar)
if command -v csso &> /dev/null; then
  csso public/css/critical.min.css -o public/css/critical.min.css
  csso public/css/page.min.css -o public/css/page.min.css
  csso public/css/features.min.css -o public/css/features.min.css
  echo "✅ CSS minified"
fi

echo "✅ CSS bundles created: critical.min.css, page.min.css, features.min.css"
```

**Layout updates**:
```erb
<!-- File: views/layout.erb -->
<head>
  <!-- Critical CSS inline (blocks render, but smallest) -->
  <style><%= File.read('public/css/critical.min.css') %></style>
  
  <!-- Page CSS deferred -->
  <link rel="preload" href="/css/page.min.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
  <noscript><link rel="stylesheet" href="/css/page.min.css"></noscript>
  
  <!-- Feature CSS conditional -->
  <% if FeatureFlags.enabled?('gamification.enabled') %>
    <link rel="stylesheet" href="/css/features.min.css" media="print" onload="this.media='all'">
  <% end %>
</head>
```

---

### Tuesday: JavaScript Consolidation & Deferred Loading (4 hours)

**Task**: Bundle, minify, and defer non-critical JS

```bash
# File: scripts/build_assets.sh (add to existing script)

echo "📦 Building JS bundles..."

# Bundle 1: Critical JS (inline or early load)
cat public/js/modules/meme-utils.js \
    public/js/modules/meme-interactions.js \
    > public/js/critical.min.js

# Bundle 2: Page JS (defer)
cat public/js/modules/meme-navigation.js \
    public/js/modules/meme-display.js \
    public/js/enhanced-lazy-load.js \
    > public/js/page.min.js

# Bundle 3: Feature JS (conditional)
cat public/js/sound-system.js \
    public/js/haptic-system.js \
    public/js/particle-effects.js \
    public/js/achievement-system.js \
    public/js/streak-system.js \
    > public/js/features.min.js

# Minify with terser (if available)
if command -v terser &> /dev/null; then
  terser public/js/critical.min.js -o public/js/critical.min.js -c -m
  terser public/js/page.min.js -o public/js/page.min.js -c -m
  terser public/js/features.min.js -o public/js/features.min.js -c -m
  echo "✅ JS minified"
fi
```

**Layout updates**:
```erb
<!-- File: views/layout.erb -->
<!-- Move all scripts to bottom of body -->
<script src="/js/critical.min.js"></script>
<script src="/js/page.min.js" defer></script>
<% if FeatureFlags.enabled?('gamification.enabled') %>
  <script src="/js/features.min.js" defer></script>
<% end %>
```

---

### Wednesday: Extract Layout Inline Scripts (5 hours)

**Task**: Move 400+ lines of inline JS to external files

**Current problem**: Layout.erb has:
- 200 lines of gamification JS
- 100 lines of push notification logic
- 100 lines of theme/menu logic

**Solution**:

```javascript
// File: public/js/layout.js
(function() {
  'use strict';
  
  // Module 1: Session data
  window.sessionData = {
    likedMemes: window.sessionLikedMemes || [],
    userId: window.currentUserId || null
  };
  
  // Module 2: Dark mode
  function initDarkMode() {
    const toggle = document.getElementById('darkModeToggle');
    if (!toggle) return;
    
    const isDark = document.documentElement.classList.contains('dark-mode');
    toggle.textContent = isDark ? '☀️' : '🌙';
    
    toggle.addEventListener('click', (e) => {
      e.preventDefault();
      const html = document.documentElement;
      const newIsDark = !html.classList.contains('dark-mode');
      
      html.classList.toggle('dark-mode');
      localStorage.setItem('theme', newIsDark ? 'dark' : 'light');
      toggle.textContent = newIsDark ? '☀️' : '🌙';
    });
  }
  
  // Module 3: Keyboard shortcuts
  function initKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      // Space = random meme
      if (e.code === 'Space' && document.activeElement.tagName !== 'INPUT') {
        e.preventDefault();
        window.location.href = '/random';
      }
      
      // Cmd/Ctrl+K = dark mode
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        document.getElementById('darkModeToggle')?.click();
      }
    });
  }
  
  // Initialize on DOMContentLoaded
  document.addEventListener('DOMContentLoaded', () => {
    initDarkMode();
    initKeyboardShortcuts();
  });
})();
```

```javascript
// File: public/js/gamification.js
// Move all XP, level-up, milestone logic here
```

```javascript
// File: public/js/push-notifications.js
// Move all push notification logic here
```

**Layout cleanup**:
```erb
<!-- File: views/layout.erb - BEFORE: 675 lines -->
<!-- AFTER: 150 lines (78% reduction!) -->

<!-- Just data injection, no logic -->
<script>
  window.sessionLikedMemes = <%= (session[:liked_memes] || []).to_json %>;
  window.currentUserId = <%= session[:user_id].to_json %>;
</script>

<script src="/js/layout.js" defer></script>
<% if FeatureFlags.enabled?('gamification.enabled') %>
  <script src="/js/gamification.js" defer></script>
<% end %>
<% if FeatureFlags.enabled?('engagement.push_notifications') %>
  <script src="/js/push-notifications.js" defer></script>
<% end %>
```

---

### Thursday: Service Worker & Caching Strategy (4 hours)

**Task**: Implement aggressive caching for static assets

```javascript
// File: public/service-worker.js (enhanced)
const CACHE_VERSION = 'v2';
const CACHE_NAME = `meme-explorer-${CACHE_VERSION}`;

const STATIC_ASSETS = [
  '/',
  '/css/critical.min.css',
  '/css/page.min.css',
  '/js/critical.min.js',
  '/js/page.min.js',
  '/js/layout.js',
  '/images/meme-placeholder.svg'
];

// Install: Cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

// Fetch: Network-first for HTML, cache-first for assets
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // HTML: Network first (fresh content)
  if (request.headers.get('Accept').includes('text/html')) {
    event.respondWith(
      fetch(request)
        .then(response => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(request, clone));
          return response;
        })
        .catch(() => caches.match(request))
    );
    return;
  }
  
  // Assets: Cache first (performance)
  if (url.pathname.match(/\.(css|js|png|jpg|jpeg|gif|svg|woff2?)$/)) {
    event.respondWith(
      caches.match(request)
        .then(cached => cached || fetch(request))
    );
    return;
  }
  
  // API calls: Network only
  event.respondWith(fetch(request));
});
```

---

### Friday: Performance Testing & Optimization (4 hours)

**Task**: Measure and validate improvements

**Lighthouse audit**:
```bash
# Before optimization
lighthouse https://meme-explorer.onrender.com --output=json --output-path=./before.json

# After optimization  
lighthouse https://meme-explorer.onrender.com --output=json --output-path=./after.json

# Compare
node scripts/compare_lighthouse.js before.json after.json
```

**Target metrics**:
- First Contentful Paint: <1.5s (currently ~2.5s)
- Largest Contentful Paint: <2.5s (currently ~3.5s)
- Time to Interactive: <3.5s (currently ~5s)
- Total Bundle Size: <500KB (currently ~850KB)

---

## 🧹 WEEK 3: Code Health & Consolidation (Priority: P1)

**Goal**: Reduce maintenance burden through consolidation

### Monday-Tuesday: Service Consolidation (8 hours)

**Task**: Merge redundant services

#### Consolidation 1: Quality Services (3 → 1)

```ruby
# BEFORE: 3 separate services
lib/services/quality_control_service.rb
lib/services/quality_pipeline_service.rb
lib/services/crowdsourced_quality_service.rb

# AFTER: 1 unified service
# File: lib/services/meme_quality_service.rb
class MemeQualityService
  class << self
    def calculate_score(meme)
      pipeline_score = pipeline_quality(meme)
      crowdsourced_score = crowdsourced_quality(meme)
      control_score = control_checks(meme)
      
      weighted_average(
        pipeline: pipeline_score,
        crowdsourced: crowdsourced_score,
        control: control_score
      )
    end
    
    def passes_quality_gates?(meme)
      score = calculate_score(meme)
      score >= MINIMUM_QUALITY_SCORE
    end
    
    private
    
    MINIMUM_QUALITY_SCORE = 0.6
    WEIGHTS = { pipeline: 0.4, crowdsourced: 0.4, control: 0.2 }.freeze
    
    def pipeline_quality(meme)
      # Logic from QualityPipelineService
      upvote_ratio = meme['upvote_ratio'].to_f
      comments = meme['comments'].to_i
      
      (upvote_ratio * 0.7) + (normalize_comments(comments) * 0.3)
    end
    
    def crowdsourced_quality(meme)
      # Logic from CrowdsourcedQualityService
      # ... (existing logic)
    end
    
    def control_checks(meme)
      # Logic from QualityControlService
      # ... (existing logic)
    end
    
    def weighted_average(scores)
      WEIGHTS.sum { |key, weight| scores[key].to_f * weight }
    end
    
    def normalize_comments(count)
      [count / 100.0, 1.0].min
    end
  end
end
```

**Migration plan**:
1. Create new `MemeQualityService`
2. Update all references to use new service
3. Add deprecation warnings to old services
4. Remove old services after 1 week

---

#### Consolidation 2: Surprise Services (2 → 1)

```ruby
# BEFORE: 2 services
lib/services/surprise_rewards_service.rb
lib/services/surprise_mechanics_service.rb

# AFTER: 1 service
# File: lib/services/engagement_rewards_service.rb
class EngagementRewardsService
  class << self
    def check_for_reward(user_id, trigger:)
      return nil unless enabled?
      
      case trigger
      when :random_view
        random_reward_check(user_id)
      when :streak_milestone
        streak_reward(user_id)
      when :level_up
        level_up_reward(user_id)
      else
        nil
      end
    end
    
    private
    
    def enabled?
      FeatureFlags.enabled?('gamification.features.surprise_rewards')
    end
    
    def random_reward_check(user_id)
      return nil unless rand < 0.10  # 10% chance
      
      {
        type: :bonus_xp,
        amount: [10, 25, 50].sample,
        icon: ["🎁", "⚡", "💎"].sample,
        message: "Lucky you! Bonus XP!"
      }
    end
  end
end
```

---

### Wednesday: Migration Cleanup (4 hours)

**Task**: Archive old migrations, create clean schema

```bash
# File: scripts/cleanup_migrations.sh

#!/bin/bash
set -e

echo "🧹 Cleaning up migration files..."

# Create archive directory
mkdir -p db/migrations/archived/2026-q1
mkdir -p db/migrations/archived/2026-q2

# Move old migrations
mv db/migrations/add_ab_testing.sql db/migrations/archived/2026-q1/
mv db/migrations/add_ad_impressions.sql db/migrations/archived/2026-q1/
mv db/migrations/add_admin_column*.sql db/migrations/archived/2026-q1/
# ... (move 30+ old migrations)

# Keep only active migrations
cat > db/migrations/README.md <<EOF
# Active Migrations

Only these migrations should be run on fresh databases:

1. \`001_baseline.sql\` - Core schema (users, memes, sessions)
2. \`002_performance_indexes.sql\` - Critical indexes
3. \`003_gamification.sql\` - Gamification tables (optional)

All other migrations have been archived to \`archived/\` directory.

## Applying Migrations

\`\`\`bash
# Fresh database setup
psql \$DATABASE_URL < db/migrations/001_baseline.sql
psql \$DATABASE_URL < db/migrations/002_performance_indexes.sql

# Optional: Gamification
psql \$DATABASE_URL < db/migrations/003_gamification.sql
\`\`\`

## Historical Migrations

See \`archived/\` directory for migration history.
EOF

echo "✅ Migrations cleaned up"
echo "   - Archived: 38 old migrations"
echo "   - Active: 3 core migrations"
```

**Create consolidated schema**:
```sql
-- File: db/migrations/001_baseline.sql
-- Single source of truth for core schema

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE,
  reddit_username VARCHAR(255),
  encrypted_password VARCHAR(255),
  role VARCHAR(50) DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Meme stats
CREATE TABLE IF NOT EXISTS meme_stats (
  id SERIAL PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,
  title TEXT,
  subreddit VARCHAR(255),
  views INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User interactions
CREATE TABLE IF NOT EXISTS user_meme_interactions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  liked BOOLEAN DEFAULT FALSE,
  saved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);

-- Sessions (if not using Redis)
CREATE TABLE IF NOT EXISTS sessions (
  id VARCHAR(255) PRIMARY KEY,
  data TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

### Thursday-Friday: Test Coverage & Documentation (8 hours)

**Task**: Add tests for critical paths

```ruby
# File: spec/integration/core_user_flow_spec.rb
require 'spec_helper'

RSpec.describe 'Core User Flow' do
  it 'allows anonymous user to browse and like memes' do
    # Visit homepage
    get '/'
    expect(last_response).to be_ok
    
    # Click random meme
    get '/random'
    expect(last_response).to be_ok
    expect(last_response.body).to include('meme-image')
    
    # Like the meme (without login)
    post '/like', { url: 'https://example.com/meme.jpg' }.to_json
    expect(last_response.status).to eq(401)  # Requires login
    
    # Sign up
    post '/signup', {
      email: 'test@example.com',
      password: 'secure123',
      password_confirmation: 'secure123'
    }
    expect(last_response.status).to eq(302)  # Redirect after signup
    
    # Now like works
    post '/like', { url: 'https://example.com/meme.jpg' }.to_json
    expect(last_response).to be_ok
    
    # View profile
    get '/profile'
    expect(last_response.body).to include('test@example.com')
  end
end
```

---

## 🏗️ WEEK 4: Infrastructure & Monitoring (Priority: P2)

**Goal**: Set up systems to prevent feature creep

### Monday: Performance Budget CI Check (4 hours)

**Task**: Fail builds if bundle size exceeds limits

```javascript
// File: scripts/check_performance_budget.js
const fs = require('fs');
const path = require('path');

const BUDGETS = {
  'public/css/critical.min.css': 50 * 1024,  // 50KB
  'public/css/page.min.css': 100 * 1024,     // 100KB
  'public/js/critical.min.js': 75 * 1024,    // 75KB
  'public/js/page.min.js': 150 * 1024,       // 150KB
  'views/layout.erb': 200 * 80               // 200 lines max
};

let failed = false;

for (const [file, budget] of Object.entries(BUDGETS)) {
  const filePath = path.join(__dirname, '..', file);
  
  if (!fs.existsSync(filePath)) {
    console.warn(`⚠️  ${file} not found`);
    continue;
  }
  
  const stats = fs.statSync(filePath);
  const size = stats.size;
  
  if (size > budget) {
    console.error(`❌ ${file}: ${size} bytes (budget: ${budget} bytes)`);
    failed = true;
  } else {
    const percentage = ((size / budget) * 100).toFixed(1);
    console.log(`✅ ${file}: ${size} bytes (${percentage}% of budget)`);
  }
}

if (failed) {
  console.error('\n❌ Performance budget exceeded!');
  process.exit(1);
} else {
  console.log('\n✅ All files within performance budget');
  process.exit(0);
}
```

**Add to CI**:
```yaml
# File: .github/workflows/ci.yml
- name: Check Performance Budget
  run: |
    npm run build:assets
    node scripts/check_performance_budget.js
```

---

### Tuesday: Feature Engagement Dashboard (4 hours)

**Task**: Track which features are actually used

```ruby
# File: lib/services/feature_analytics_service.rb
class FeatureAnalyticsService
  class << self
    def track_feature_use(feature_name, user_id: nil)
      RedisService.hincrby('feature_usage', feature_name, 1)
      
      if user_id
        RedisService.sadd("feature_users:#{feature_name}", user_id)
      end
    end
    
    def feature_stats(days: 7)
      all_features = RedisService.hgetall('feature_usage')
      
      all_features.map do |feature, count|
        {
          name: feature,
          total_uses: count.to_i,
          unique_users: RedisService.scard("feature_users:#{feature}"),
          engagement_rate: calculate_engagement_rate(feature, days)
        }
      end.sort_by { |f| -f[:total_uses] }
    end
    
    def low_engagement_features(threshold: 0.05)
      feature_stats.select { |f| f[:engagement_rate] < threshold }
    end
    
    private
    
    def calculate_engagement_rate(feature, days)
      total_users = User.where('created_at > ?', days.days.ago).count
      return 0.0 if total_users.zero?
      
      feature_users = RedisService.scard("feature_users:#{feature}")
      feature_users.to_f / total_users
    end
  end
end
```

**Admin dashboard**:
```erb
<!-- File: views/admin/feature_analytics.erb -->
<h2>Feature Engagement Dashboard</h2>

<table>
  <thead>
    <tr>
      <th>Feature</th>
      <th>Total Uses</th>
      <th>Unique Users</th>
      <th>Engagement Rate</th>
      <th>Action</th>
    </tr>
  </thead>
  <tbody>
    <% @features.each do |feature| %>
      <tr>
        <td><%= feature[:name] %></td>
        <td><%= number_with_delimiter(feature[:total_uses]) %></td>
        <td><%= number_with_delimiter(feature[:unique_users]) %></td>
        <td>
          <% if feature[:engagement_rate] < 0.05 %>
            <span class="badge badge-danger"><%= (feature[:engagement_rate] * 100).round(1) %>%</span>
          <% else %>
            <span class="badge badge-success"><%= (feature[:engagement_rate] * 100).round(1) %>%</span>
          <% end %>
        </td>
        <td>
          <% if feature[:engagement_rate] < 0.05 %>
            <a href="/admin/features/disable/<%= feature[:name] %>" class="btn btn-warning">
              Consider Disabling
            </a>
          <% end %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>

<h3>Recommendation</h3>
<p>Features with <5% engagement should be candidates for removal or improvement.</p>
```

---

### Wednesday-Friday: Documentation & Handoff (12 hours)

**Create comprehensive documentation**:

1. **ARCHITECTURE.md** - Updated system overview
2. **FEATURE_DEVELOPMENT_GUIDE.md** - How to add features responsibly
3. **PERFORMANCE_GUIDE.md** - Performance best practices
4. **SIMPLIFICATION_WINS.md** - Document improvements and metrics

---

## 📈 Success Metrics

Track these metrics weekly to validate improvements:

### Primary Metrics (Week over Week)

| Metric | Baseline | Week 1 | Week 2 | Week 3 | Week 4 | Target |
|--------|----------|--------|--------|--------|--------|---------|
| Daily Active Users | 1000 | ? | ? | ? | ? | 1100 (+10%) |
| Avg Session Duration | 3.2min | ? | ? | ? | ? | 3.5min (+9%) |
| Page Load Time (LCP) | 3.5s | ? | ? | ? | ? | 2.5s (-29%) |
| Bounce Rate | 45% | ? | ? | ? | ? | 40% (-11%) |
| Like Rate | 12% | ? | ? | ? | ? | 15% (+25%) |

### Secondary Metrics

- CSS Bundle Size: 850KB → 200KB (-76%)
- JS Bundle Size: 420KB → 150KB (-64%)
- Layout.erb Lines: 675 → 150 (-78%)
- Service Count: 52 → 30 (-42%)
- Active Migrations: 40 → 3 (-92%)

---

## 🎯 Go/No-Go Decision Points

### End of Week 1 Check

**Must achieve**:
- [ ] Navigation reduced to ≤ 5 items
- [ ] Progressive disclosure implemented
- [ ] Feature flags working
- [ ] User engagement stable or improved

**If failed**: Revert to previous navigation, analyze data

### End of Week 2 Check

**Must achieve**:
- [ ] Page load time improved by ≥ 300ms
- [ ] CSS files reduced to ≤ 5
- [ ] No increase in bounce rate
- [ ] Service worker caching working

**If failed**: Identify bottlenecks, adjust timeline

### End of Week 3 Check

**Must achieve**:
- [ ] At least 3 services consolidated
- [ ] Migration count reduced by ≥ 70%
- [ ] Test coverage ≥ 60% for critical paths
- [ ] No regressions in functionality

**If failed**: Prioritize consolidations, skip non-critical items

### End of Week 4 Check

**Must achieve**:
- [ ] Performance budget CI passing
- [ ] Feature analytics dashboard live
- [ ] Documentation complete
- [ ] Overall grade improved from B+ to A-

**If failed**: Extended polish week

---

## 🚧 Risk Mitigation

### Risk 1: User Pushback on Removed Features

**Likelihood**: Medium  
**Impact**: High  
**Mitigation**:
- Feature flags allow instant rollback
- A/B test major changes
- Communicate changes via blog post
- Collect user feedback

### Risk 2: Performance Regressions

**Likelihood**: Low  
**Impact**: High  
**Mitigation**:
- CI performance checks
- Lighthouse audits before/after
- Gradual rollout (10% → 50% → 100%)

### Risk 3: Breaking Changes During Consolidation

**Likelihood**: Medium  
**Impact**: Medium  
**Mitigation**:
- Comprehensive test coverage
- Deprecation warnings before removal
- Staged rollout of consolidated services

---

## 📞 Support & Communication

### Daily Standups (15 min)
- What shipped yesterday?
- What's shipping today?
- Any blockers?

### Weekly Reviews (1 hour)
- Review metrics
- Adjust priorities
- Celebrate wins

### Stakeholder Updates
- Email update every Friday
- Include metrics, wins, and blockers
- Highlight user feedback

---

## 🎬 Post-Roadmap: Continuous Improvement

After completing this roadmap:

1. **Monthly Feature Reviews** - Disable features with <5% engagement
2. **Quarterly Performance Audits** - Maintain gains
3. **Bi-annual Code Audits** - Prevent bloat
4. **User Feedback Loop** - Weekly review of support tickets

---

## ✅ Definition of Done

This roadmap is complete when:

- [ ] Overall grade improved from B+ (83%) to A- (91%)
- [ ] Page load time reduced by ≥500ms
- [ ] Navigation simplified (14 → 5 items)
- [ ] Services consolidated (52 → 30)
- [ ] All metrics stable or improved
- [ ] Documentation complete
- [ ] Team trained on new processes

---

**Remember**: The goal isn't perfection—it's **sustainable excellence**. Ship improvements weekly, measure impact, and iterate.

**Next Steps**: Pick 3 Quick Wins from Week 1 and start today!

---

*Roadmap created: July 26, 2026*  
*Based on: SENIOR_SINATRA_COMPREHENSIVE_AUDIT_JULY_26_2026.md*  
*Estimated effort: 120 hours over 4 weeks (1 developer)*
