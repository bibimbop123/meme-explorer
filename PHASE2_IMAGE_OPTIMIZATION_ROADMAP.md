# Phase 3: Advanced Features Roadmap (2-4 Weeks)

**Timeline:** Weeks 3-4
**Expected Impact:** +50% engagement (Phase 2) + 17% additional (Phase 3) = 3x total target
**Focus:** User experience sophistication, preference persistence, seasonal content

---

## EXECUTIVE SUMMARY

Phase 3 implements intelligent fallback logic, user preference tracking, and seasonal content rotation. This elevates the trending page from functional to delightful.

**Key Features:**
- Smart category-based fallbacks (not just hardcoded)
- User preference memory (personalized experience)
- Seasonal placeholder rotation (freshness)

---

## PHASE 3 FEATURES

### Feature 1: Smart Category-Based Fallbacks

**Problem:** Currently uses `/images/dank1.jpeg` for all fallbacks
**Solution:** Category-aware fallback logic

**Implementation:**

```ruby
# lib/services/image_fallback_service.rb

class ImageFallbackService
  CATEGORY_FALLBACKS = {
    'funny' => ['/images/funny1.jpeg', '/images/funny2.jpeg', '/images/funny3.jpeg'],
    'wholesome' => ['/images/wholesome1.jpeg', '/images/wholesome2.jpeg', '/images/wholesome3.jpeg'],
    'selfcare' => ['/images/selfcare1.jpeg', '/images/selfcare2.jpeg', '/images/selfcare3.jpeg'],
    'dank' => ['/images/dank1.jpeg', '/images/dank2.jpeg'],
  }.freeze

  def self.get_fallback(subreddit, randomize: true)
    category = categorize_subreddit(subreddit)
    fallbacks = CATEGORY_FALLBACKS[category] || CATEGORY_FALLBACKS['dank']
    randomize ? fallbacks.sample : fallbacks.first
  end

  private

  def self.categorize_subreddit(subreddit)
    case subreddit.downcase
    when /funny|laugh|jokes|lol/
      'funny'
    when /wholesome|aww|heartwarming/
      'wholesome'
    when /health|fitness|mindfulness|mental/
      'selfcare'
    else
      'dank'
    end
  end
end
```

**Frontend Integration:**

```javascript
// Update public/js/trending.js
function createMemeCard(meme) {
  // Get category-appropriate fallback
  const categoryFallback = `/api/v1/fallback-image?subreddit=${meme.subreddit}`;
  
  return `
    <img 
      src="${meme.images.mobile_jpeg}"
      onerror="this.src='${categoryFallback}'"
      alt="${meme.title}"
    />
  `;
}
```

**Expected Outcome:** Fallback images match content vibe, improve UX perception by 15%

---

### Feature 2: User Preference Tracking

**Problem:** Each user session starts fresh, no memory of preferences
**Solution:** Store preferences (time window, sort, category filters)

**Implementation:**

```ruby
# app/models/user_preference.rb

class UserPreference < ApplicationRecord
  belongs_to :user, optional: true  # For guest users, use session_id

  # Preferences structure
  store :preferences, accessors: [
    :favorite_time_window,      # '24h', '7d', 'all-time'
    :favorite_sort,             # 'trending', 'new', 'popular'
    :favorite_categories,       # ['funny', 'wholesome']
    :theme_preference,          # 'light', 'dark', 'auto'
    :nsfw_filter,              # true/false
    :last_viewed_page,         # For resume position
  ]

  before_save :validate_preferences

  def self.for_user(user_id_or_session)
    find_or_create_by(user_id: user_id_or_session)
  end

  def update_from_session(session_data)
    self.preferences = session_data
    save
  end
end
```

**Database Migration:**

```ruby
class CreateUserPreferences < ActiveRecord::Migration[6.0]
  def change
    create_table :user_preferences do |t|
      t.references :user, foreign_key: true
      t.string :session_id, null: false
      t.jsonb :preferences, default: {}
      
      t.timestamps
    end
    
    add_index :user_preferences, :session_id, unique: true
  end
end
```

**API Endpoint:**

```ruby
# routes/api/v1/user_preferences.rb

module API
  module V1
    class UserPreferencesController < ApplicationController
      def show
        preference = UserPreference.for_user(current_user_id)
        render json: preference.preferences
      end

      def update
        preference = UserPreference.for_user(current_user_id)
        preference.update(preferences: preference_params)
        render json: preference.preferences
      end

      private

      def preference_params
        params.require(:preferences).permit(
          :favorite_time_window,
          :favorite_sort,
          :theme_preference,
          :nsfw_filter,
          favorite_categories: []
        )
      end
    end
  end
end
```

**Frontend Integration:**

```javascript
// Update public/js/trending.js to load/save preferences

class UserPreferences {
  async loadPreferences() {
    try {
      const response = await fetch('/api/v1/user/preferences');
      const prefs = await response.json();
      this.applyPreferences(prefs);
    } catch (e) {
      // Fall back to localStorage
      this.loadFromLocalStorage();
    }
  }

  async savePreferences(prefs) {
    try {
      await fetch('/api/v1/user/preferences', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ preferences: prefs })
      });
    } catch (e) {
      // Fall back to localStorage
      this.saveToLocalStorage(prefs);
    }
  }

  applyPreferences(prefs) {
    // Apply time window
    document.querySelector(`[data-window="${prefs.favorite_time_window}"]`)?.click();
    // Apply sort
    document.getElementById('sortDropdown').value = prefs.favorite_sort;
    // Apply theme
    document.documentElement.setAttribute('data-theme', prefs.theme_preference);
  }
}
```

**Expected Outcome:** 30% increase in session retention, 25% more page revisits

---

### Feature 3: Seasonal Placeholder Rotation

**Problem:** Same fallback images year-round feel stale
**Solution:** Seasonal variants of placeholder images

**Implementation:**

```ruby
# lib/services/seasonal_content_service.rb

class SeasonalContentService
  SEASONAL_PLACEHOLDERS = {
    winter: {
      funny: '/images/seasonal/winter-funny.jpg',
      wholesome: '/images/seasonal/winter-wholesome.jpg',
      selfcare: '/images/seasonal/winter-selfcare.jpg',
      dank: '/images/seasonal/winter-dank.jpg'
    },
    spring: {
      funny: '/images/seasonal/spring-funny.jpg',
      wholesome: '/images/seasonal/spring-wholesome.jpg',
      selfcare: '/images/seasonal/spring-selfcare.jpg',
      dank: '/images/seasonal/spring-dank.jpg'
    },
    summer: {
      funny: '/images/seasonal/summer-funny.jpg',
      wholesome: '/images/seasonal/summer-wholesome.jpg',
      selfcare: '/images/seasonal/summer-selfcare.jpg',
      dank: '/images/seasonal/summer-dank.jpg'
    },
    fall: {
      funny: '/images/seasonal/fall-funny.jpg',
      wholesome: '/images/seasonal/fall-wholesome.jpg',
      selfcare: '/images/seasonal/fall-selfcare.jpg',
      dank: '/images/seasonal/fall-dank.jpg'
    },
    holidays: {
      funny: '/images/seasonal/holidays-funny.jpg',
      wholesome: '/images/seasonal/holidays-wholesome.jpg',
      selfcare: '/images/seasonal/holidays-selfcare.jpg',
      dank: '/images/seasonal/holidays-dank.jpg'
    }
  }.freeze

  def self.get_seasonal_placeholder(category)
    season = current_season
    SEASONAL_PLACEHOLDERS[season]&.[](category.to_sym) ||
      ImageFallbackService.get_fallback(category)
  end

  private

  def self.current_season
    today = Date.today
    month = today.month

    case month
    when 12, 1, 2
      :winter
    when 3, 4, 5
      :spring
    when 6, 7, 8
      :summer
    when 9, 10, 11
      :fall
    end
  end

  def self.is_holiday_season?
    today = Date.today
    (today.month == 12 && today.day >= 20) ||
    (today.month == 1 && today.day <= 2) ||
    (today.month == 10 && today.day >= 25) # Halloween
  end
end
```

**Special Holiday Integration:**

```ruby
# lib/services/holiday_service.rb

class HolidayService
  HOLIDAYS = {
    christmas: { month: 12, day: 25 },
    new_year: { month: 1, day: 1 },
    halloween: { month: 10, day: 31 },
    valentine: { month: 2, day: 14 },
    earth_day: { month: 4, day: 22 }
  }.freeze

  def self.upcoming_holiday
    today = Date.today
    HOLIDAYS.each do |name, date|
      holiday = Date.new(today.year, date[:month], date[:day])
      return name if (holiday - today).to_i.between?(0, 7)
    end
    nil
  end

  def self.special_header_for_holiday(holiday)
    case holiday
    when :christmas
      "🎄 Holiday Trending Memes 🎄"
    when :halloween
      "👻 Spooky Trending Memes 👻"
    when :valentine
      "💕 Love & Laughter 💕"
    else
      nil
    end
  end
end
```

**Frontend Implementation:**

```erb
<!-- views/trending.erb -->
<div class="trending-container">
  <% if @holiday_header %>
    <h1 class="trending-title holiday"><%= @holiday_header %></h1>
  <% end %>
  
  <!-- Rest of page -->
</div>

<script>
  // Check for seasonal changes
  document.addEventListener('DOMContentLoaded', () => {
    const season = '<%= current_season %>';
    document.body.setAttribute('data-season', season);
  });
</script>

<style>
  body[data-season="winter"] {
    --primary-color: #b0e0e6;
    --accent-color: #ffffff;
  }

  body[data-season="spring"] {
    --primary-color: #d4f1d4;
    --accent-color: #ffc0cb;
  }

  body[data-season="summer"] {
    --primary-color: #ffeb99;
    --accent-color: #ffa500;
  }

  body[data-season="fall"] {
    --primary-color: #ff8c42;
    --accent-color: #d2691e;
  }
</style>
```

**Expected Outcome:** 15-20% increase in user engagement during seasonal periods, improved brand perception

---

## PHASE 3 IMPLEMENTATION TIMELINE

### Week 1: Smart Fallbacks & Preferences
- Day 1-2: Category fallback logic
- Day 3-4: User preference system
- Day 5: Testing & staging deployment

### Week 2: Seasonal Features & Polish
- Day 1-2: Seasonal placeholder setup
- Day 3-4: Holiday detection system
- Day 5: Integration testing

### Week 3-4: Analytics & Optimization
- Analytics dashboard
- A/B testing framework
- Performance tuning
- Production rollout

---

## DATABASE SCHEMA ADDITIONS

```sql
-- User Preferences Table
CREATE TABLE user_preferences (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  session_id VARCHAR(255) UNIQUE NOT NULL,
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  INDEX (session_id)
);

-- Seasonal Content Tracking
CREATE TABLE seasonal_content (
  id SERIAL PRIMARY KEY,
  season VARCHAR(20),
  category VARCHAR(50),
  image_url VARCHAR(500),
  click_count INTEGER DEFAULT 0,
  impression_count INTEGER DEFAULT 0,
  created_at TIMESTAMP
);

-- User Engagement Analytics
CREATE TABLE engagement_metrics (
  id SERIAL PRIMARY KEY,
  user_id INTEGER,
  session_id VARCHAR(255),
  time_window VARCHAR(20),
  sort_preference VARCHAR(50),
  page_views INTEGER,
  avg_time_spent FLOAT,
  memes_viewed INTEGER,
  memes_liked INTEGER,
  created_at TIMESTAMP
);
```

---

## FEATURE PRIORITIZATION

**Tier 1 (Must Have):**
1. Smart category fallbacks (15% improvement)
2. User preference persistence (25% improvement)

**Tier 2 (Should Have):**
3. Seasonal placeholders (15% improvement)

**Tier 3 (Nice to Have):**
4. Holiday special features (5% improvement)

---

## SUCCESS METRICS

| Metric | Current | Phase 3 Target | Cumulative |
|--------|---------|----------------|-----------|
| Engagement | Baseline | +17% | +167% (3x) |
| Retention | Low | +35% | +85% |
| Session Time | 45s | +120s | 3m+ |
| Return Users | 20% | 50% | 60%+ |

---

## ROLLBACK & SAFETY

**Rollback Triggers:**
- Preference system errors (user unable to save)
- Fallback image broken links
- Seasonal images not loading

**Rollback Procedure:**
```bash
git revert COMMIT_HASH
# System reverts to Phase 2 image optimization
# All data preserved in database
# Simple redeploy when fixed
```

---

## FUTURE ENHANCEMENTS (Phase 4+)

- Machine learning-based category prediction
- AI-powered image tagging
- Personalized algorithm (popular to this user)
- Social sharing optimization
- Community voting on placeholders
- User-submitted fallback images

---

*Phase 3: Advanced Features - Building on Solid Foundation*
