# iFunny-Style Features Implementation - COMPLETE ✅

## Overview

This document describes the complete implementation of iFunny-style features including **smart pools**, **collaborative filtering**, and **session-based learning**. These features transform the meme recommendation algorithm from basic randomization to an intelligent, personalized system that learns and adapts in real-time.

## 🎯 Features Implemented

### 1. Smart Pools Management System
**Location:** `lib/services/smart_pools_service.rb`

**What it does:**
- Dynamically optimizes pool weights based on performance data
- Tracks which content pools (trending, fresh, vintage, etc.) perform best
- Personalizes pool selection for individual users
- A/B tests different pool configurations

**Key Methods:**
- `get_optimized_pool_weights(user_id:, session_id:)` - Returns optimized weights
- `track_pool_selection(pool_type, meme, session_id:, user_id:)` - Tracks usage
- `get_pool_analytics(days:)` - Performance metrics
- `create_experiment(name, variants)` - A/B testing

### 2. Session-Based Learning
**Location:** `lib/services/session_learning_service.rb`

**What it does:**
- Learns user preferences in real-time during their session
- Tracks subreddit preferences, humor type preferences, and time-of-day patterns
- Predicts what users will like based on current session
- Uses both Redis (fast) and database (persistent) storage

**Key Methods:**
- `learn_from_interaction(session_id, meme, interaction_type, user_id:, duration:)` - Learn from user actions
- `get_session_preferences(session_id)` - Get learned preferences
- `predict_preference_score(session_id, meme)` - Predict like probability
- `get_learned_recommendations(session_id, memes, limit:)` - Top recommendations

**Learning Stages:**
1. **Exploration** (0-20% confidence) - Still learning preferences
2. **Learning** (20-50% confidence) - Building profile
3. **Confident** (50-80% confidence) - Good understanding
4. **Expert** (80-100% confidence) - Strong personalization

### 3. Collaborative Filtering
**Location:** `lib/services/enhanced_random_selector.rb` + `app/workers/collaborative_filtering_worker.rb`

**What it does:**
- Finds users with similar tastes using Jaccard similarity
- Recommends memes that similar users enjoyed
- Calculates user-user and meme-meme similarity matrices
- Runs background calculations to keep recommendations fresh

**How it works:**
1. Tracks all user interactions in `user_interactions` table
2. Background worker calculates user similarities (Jaccard index)
3. Stores similarities in `user_similarity` table
4. Uses similarities to recommend memes liked by similar users

### 4. Frontend Tracking Integration
**Location:** `public/js/ifunny-tracking.js`

**What it tracks:**
- Meme views (when they enter viewport)
- View duration (how long user watched)
- Likes, skips, shares
- Session metrics (total duration, memes viewed, engagement rate)

**Features:**
- IntersectionObserver for accurate view tracking
- localStorage for client-side learning
- sendBeacon for reliable tracking on page unload
- Debug mode: `window.iFunnyTracking.getSessionAnalytics()`

### 5. Enhanced Random Selector
**Location:** `lib/services/enhanced_random_selector.rb`

**Improvements over basic random:**
1. **Engagement Rate Tracking** - iFunny's "smile_rate" (likes/views)
2. **User Profile Building** - Learns what each user enjoys
3. **Collaborative Filtering** - "Users like you also liked..."
4. **Content Similarity Detection** - Avoids showing duplicates
5. **Discovery Bonus** - Rewards content outside filter bubble
6. **Adaptive Selection Strategy** - Epsilon-greedy exploration/exploitation

## 📊 Database Schema

### New Tables Created

**`user_interactions`** - All user interactions
```sql
- user_id, session_id, meme_id, meme_url
- interaction_type (view, like, skip, share)
- duration_seconds, pool_type, humor_type
- engagement_rate, created_at
```

**`user_similarity`** - Collaborative filtering
```sql
- user_id_a, user_id_b
- similarity_score (0.0-1.0)
- common_likes, last_calculated
```

**`pool_performance`** - Smart pool analytics
```sql
- pool_type, date
- selections, likes, skips
- avg_duration, engagement_rate
```

**`session_learning`** - Real-time learning
```sql
- session_id, user_id
- learning_type (subreddit_preference, humor_preference, time_preference)
- key, value, confidence, sample_size
```

**`meme_recommendations`** - Cached recommendations
```sql
- user_id, meme_id, recommendation_score
- source (collaborative, content_based, hybrid, pool)
- expires_at
```

**`meme_similarity`** - Content-based filtering
```sql
- meme_id_a, meme_id_b
- similarity_score, similarity_type
```

**`user_engagement_patterns`** - Time-based patterns
```sql
- user_id, hour_of_day, day_of_week
- avg_session_length, engagement_rate
```

**`algorithm_experiments`** - A/B testing
```sql
- experiment_name, variant
- pool_weights (JSONB), metrics
```

## 🚀 Installation & Setup

### Step 1: Run Database Migration

```bash
# Run the migration script
ruby scripts/run_ifunny_migration.rb
```

This creates all necessary tables for both SQLite and PostgreSQL.

### Step 2: Schedule Background Worker

Add to `config/initializers/sidekiq.rb`:

```ruby
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = {
      'collaborative_filtering' => {
        'cron' => '0 */6 * * *',  # Every 6 hours
        'class' => 'CollaborativeFilteringWorker',
        'queue' => 'low_priority'
      }
    }
    
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end
```

### Step 3: Add Frontend Tracking

Add to `views/layout.erb` (before closing `</body>`):

```erb
<script src="/js/ifunny-tracking.js"></script>
```

### Step 4: Use Enhanced Random Endpoint

Update your random meme route to use enhanced selector:

```ruby
# In app.rb or routes
get '/random' do
  all_memes = MemeService.get_all_memes
  session_id = session[:session_id] ||= SecureRandom.uuid
  user_id = session[:user_id]
  
  # Use enhanced selector instead of basic random
  selected = EnhancedRandomSelector.select_meme(
    all_memes,
    session_id: session_id,
    user_id: user_id
  )
  
  erb :random, locals: { meme: selected }
end
```

Or use the API endpoint directly:

```javascript
// Frontend
const response = await fetch('/api/random/enhanced');
const data = await response.json();
// data.meme contains the selected meme
// data.metadata contains algorithm info
```

## 📈 Usage Examples

### Track User Interaction

```ruby
# When user likes a meme
SessionLearningService.learn_from_interaction(
  session_id,
  meme,
  'like',
  user_id: current_user_id,
  duration: 15  # seconds
)

# When user skips
SessionLearningService.learn_from_interaction(
  session_id,
  meme,
  'skip',
  user_id: current_user_id
)
```

### Get Session Analytics

```ruby
analytics = SessionLearningService.get_session_analytics(session_id)
# => {
#   confidence: 0.65,
#   total_interactions: 32,
#   top_subreddits: {"dankmemes"=>0.8, "memes"=>0.7},
#   top_humor_types: {"dark"=>0.9, "wholesome"=>0.5},
#   learning_stage: "confident"
# }
```

### Get Pool Performance

```ruby
analytics = SmartPoolsService.get_pool_analytics(days: 7)
# => {
#   "trending" => {
#     selections: 450,
#     likes: 180,
#     engagement_rate: 0.40,
#     like_rate: 40.0
#   },
#   "fresh" => { ... }
# }
```

### Get Collaborative Recommendations

```ruby
recommendations = EnhancedRandomSelector.send(
  :get_collaborative_recommendations,
  user_id,
  limit: 20
)
# => ["meme_id_1", "meme_id_2", ...]  # Ranked by recommendation strength
```

## 🎮 Frontend Debug Mode

Open browser console and try:

```javascript
// Get current session analytics
window.getSessionAnalytics()
// => {duration: 245, memesViewed: 15, likes: 6, engagementRate: "40.0%", ...}

// Get current viewing meme
window.iFunnyTracking.getCurrentMeme()

// Force end current view
window.iFunnyTracking.forceEndView()

// Get total memes viewed
window.iFunnyTracking.getMemesViewedCount()
```

## 🔄 How It All Works Together

### 1. User Opens App
- Session tracking starts
- Frontend loads `ifunny-tracking.js`
- Session ID created

### 2. User Requests Meme
1. **EnhancedRandomSelector** is called
2. **Layer 1: Diversity Engine** selects content pool (trending/fresh/etc.)
3. **Smart Pools Service** optimizes pool weights based on performance
4. **Layer 2: Enhanced Ranking** scores memes using:
   - Engagement rate (iFunny's "smile_rate")
   - User preference match (session learning)
   - Collaborative filtering boost
   - Humor score, source quality, freshness
   - Content similarity penalty
   - Discovery bonus
5. **Layer 3: Smart Selection** uses epsilon-greedy strategy
6. Meme returned with metadata

### 3. User Interacts
- Frontend tracks view duration
- User likes/skips meme
- **Session Learning Service** updates preferences in real-time
- Interaction saved to `user_interactions` table
- Pool performance updated

### 4. Background Processing
- Every 6 hours: **CollaborativeFilteringWorker** runs
- Calculates user-user similarities (Jaccard index)
- Updates `user_similarity` table
- Cleans up expired recommendations

### 5. Next Meme Request
- Algorithm now knows more about user
- Uses learned preferences for better ranking
- Collaborative filtering provides recommendations
- Cycle repeats, getting smarter each time

## 📊 Key Metrics to Monitor

1. **Engagement Rate**: `likes / views` per pool
2. **Session Duration**: How long users stay
3. **Memes Per Session**: Content consumption rate
4. **Learning Confidence**: How well we know user preferences
5. **Pool Performance**: Which pools drive engagement
6. **Similarity Scores**: Quality of collaborative filtering

## 🆚 iFunny vs Our Approach

### What iFunny Does Better:
- Deep ML models (ALS, LightGBM)
- Scales to millions of users
- More sophisticated ranking

### What We Do Better:
✅ **Forced diversity** - No filter bubbles
✅ **Cold start handled** - Fresh pool surfaces new content
✅ **Serendipity built-in** - Discovery is core
✅ **Simpler to implement** - No ML infrastructure needed
✅ **Faster to iterate** - Rule-based tweaking

### Hybrid Approach:
We combine the best of both:
- iFunny's engagement tracking + our diversity pools
- iFunny's collaborative filtering + our serendipity
- iFunny's user profiling + our session learning

## 🎯 API Endpoints

### GET `/api/random/enhanced`
Returns intelligently selected meme with metadata

**Response:**
```json
{
  "success": true,
  "meme": { ... },
  "algorithm": "enhanced",
  "metadata": {
    "pool_type": "trending",
    "rank_score": 8.42,
    "engagement_rate": 35.6,
    "user_affinity": 0.85,
    "selection_time_ms": 12.34
  }
}
```

### POST `/api/random/track`
Track user interaction

**Body:**
```json
{
  "meme_id": "url_or_id",
  "type": "like|skip|share|view",
  "duration": 15
}
```

### GET `/api/random/profile`
Get user profile (requires login)

**Response:**
```json
{
  "total_views": 150,
  "total_likes": 60,
  "engagement_rate": 40.0,
  "preferred_subreddits": ["dankmemes", "wholesomememes"],
  "preferred_humor_types": ["dark", "wholesome"]
}
```

### GET `/api/random/recommendations`
Get collaborative recommendations (requires login)

**Response:**
```json
{
  "success": true,
  "recommendations": ["meme_id_1", "meme_id_2", ...],
  "count": 20
}
```

## 🔧 Configuration

Pool weights can be customized in `lib/services/smart_pools_service.rb`:

```ruby
default_weights = {
  trending: 30,    # What's hot now (30%)
  fresh: 25,       # Brand new content (25%)
  vintage: 15,     # Classics (15%)
  random: 20,      # Surprise variety (20%)
  serendipity: 10  # Hidden gems (10%)
}
```

Learning rate in session learning (higher = faster adaptation):

```ruby
alpha = 0.3  # Learning rate (0.1 = slow, 0.5 = fast)
```

## 🐛 Troubleshooting

### No recommendations showing?
- Run migration: `ruby scripts/run_ifunny_migration.rb`
- Check user has interactions in database
- Verify Redis is running

### Session learning not working?
- Check Redis connection
- Verify `ifunny-tracking.js` is loaded
- Check browser console for errors

### Background worker not running?
- Start Sidekiq: `bundle exec sidekiq`
- Check `config/initializers/sidekiq.rb`
- Manually trigger: `CollaborativeFilteringWorker.perform_async`

## 📚 Related Documentation

- `IFUNNY_VS_OUR_APPROACH.md` - Comparison with iFunny
- `ENHANCED_ALGORITHM_COMPLETE_2026.md` - Enhanced random selector
- `DIVERSITY_ENGINE_COMPLETE_2026.md` - Diversity pools
- Database schema: `db/migrations/add_ifunny_features.sql`

## ✅ Next Steps

1. **Run the migration** to create tables
2. **Add frontend tracking** script to layout
3. **Schedule background worker** for collaborative filtering
4. **Monitor metrics** to tune pool weights
5. **A/B test** different configurations
6. **Scale up** as user base grows

---

**Implementation Date:** May 2026  
**Status:** ✅ Complete and Production-Ready  
**Maintainer:** Development Team  
