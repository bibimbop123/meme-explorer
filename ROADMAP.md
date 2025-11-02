# Meme Explorer - Product Roadmap

## Current Status: Executing Phase 1 & 2

This roadmap outlines the strategic development plan for Meme Explorer, a Reddit-powered meme discovery and social platform.

---

## Phase 1: Weighted Random Selection (Core Engagement) ✅ ACTIVE

**Objective:** Replace pure random selection with intelligent weighted selection based on meme popularity and engagement.

**What's Being Activated:**
- `weighted_random_select()` - Scores memes by engagement: `sqrt(likes * 2 + views)`
- Trending pool from database (popularity-driven)
- Fresh pool (recent additions)
- Exploration pool (random discovery)

**User Impact:**
- Users see more engaging content
- Better content surfacing from database
- Increased like/view engagement

**Success Metrics:**
- 15% increase in likes/views
- Improved session engagement time
- Better retention on second visit

---

## Phase 2: Personalized Recommendations (Smart Discovery) ✅ ACTIVE

**Objective:** Personalize meme feeds based on user preferences, time of day, and viewing history.

**What's Being Activated:**
- `get_intelligent_pool()` - 70% trending, 20% fresh, 10% exploration split
- `apply_user_preferences()` - Boost subreddits user has liked
- `update_user_preference()` - Track user interests on likes
- `navigate_meme()` - Intelligent navigation with diversity constraints
- Subreddit diversity enforcement (no back-to-back same subreddit)

**Who Gets It:**
- Logged-in users with 10+ meme exposures (established users)
- New users still get Phase 1 (warm-up period)

**User Impact:**
- Recommendations improve over time as preferences are learned
- Less repetitive content (different subreddits)
- Higher-quality meme discovery

**Success Metrics:**
- 25% increase in session time for personalized users
- 10% increase in save/collection activity
- Improved user retention (40% week2 retention)

---

## Phase 3: Spaced Repetition & Advanced AI (Future - Q3 2025)

**Objective:** Advanced personalization using exponential decay algorithm and machine learning scoring.

**Features (Not Yet Active):**
- `navigate_meme_v3()` - Spaced repetition prevents recently-shown memes
- `should_exclude_from_exposure()` - Exponential decay: 1h, 4h, 16h, 64h intervals
- `calculate_personalized_score()` - ML-like scoring combining popularity + preferences
- `get_time_based_pools()` - Peak hours (80% trending), off-hours (60% trending)

**Expected Impact:**
- Even better personalization
- Reduced content fatigue
- Higher accuracy in recommendations

---

## Technical Architecture

### Database Schema
- `users` - Authentication (OAuth + email/password)
- `meme_stats` - Global engagement metrics (likes, views)
- `user_meme_stats` - Per-user interactions (likes, saves)
- `user_meme_exposure` - Tracking for spaced repetition
- `user_subreddit_preferences` - Learned user preferences
- `saved_memes` - User collections
- `broken_images` - URL health tracking

### Data Flow
1. User sees meme → tracked in `user_meme_exposure`
2. User likes → updates `meme_stats` (global) + `user_meme_stats` + `user_subreddit_preferences`
3. Next navigation → pools selected by phase logic
4. Meme scored & ranked by engagement
5. User sees next meme with diversity constraints

### Caching Strategy
- Redis: Session data, access tokens, meme cache (2min TTL)
- Local YAML: Fallback memes (always available)
- Database: Primary engagement metrics
- API: Reddit OAuth for fresh memes (60s refresh)

---

## Implementation Timeline

### Week 1-2: Phase 1 Rollout
- ✅ Weighted selection algorithm active
- ✅ Pool distribution in place
- ✅ A/B testing setup
- Test with production traffic

### Week 3-6: Phase 2 Launch
- ✅ Preference tracking on likes
- ✅ Intelligent routing for logged-in users
- ✅ Gradual rollout (5% → 25% → 100%)
- Monitor engagement metrics

### Week 7-12: Stabilization
- Load testing
- Database optimization
- Edge case handling
- Documentation

### Q2 2025: Phase 2 Expansion
- Onboarding with preference selection
- Email notifications
- User engagement dashboard
- Social features (share, follow)

### Q3 2025: Phase 3 Launch
- Spaced repetition rollout
- Advanced ML scoring
- Performance optimization
- Content quality features

---

## Key Success Factors

✅ **Leveraging Existing Code** - Phases 1-3 already implemented, just need activation
✅ **Gradual Rollout** - Feature flags and staged deployment reduce risk
✅ **Data-Driven** - Metrics track each phase's impact
✅ **User Experience** - Seamless transitions, no disruption
✅ **Fallback Strategy** - Always have content (local memes + API)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Database overload at scale | Query optimization, indexing, caching strategy |
| Reddit API rate limits | OAuth2 + fallback to local memes |
| User confusion during phase transition | Feature flags, A/B testing, documentation |
| Broken image URLs | Automated tracking + admin removal |
| Session data loss | Redis backup strategy |

---

## Metrics Dashboard

**Phase 1 KPIs:**
- Avg likes per meme (trending vs random)
- Session engagement time
- Return visitor rate

**Phase 2 KPIs:**
- Personalization impact (preference > non-pref)
- Session time increase
- Save/collection rate
- Subreddit diversity score

**Phase 3 KPIs (Future):**
- Content fatigue reduction
- Spaced repetition effectiveness
- ML model accuracy

---

## How to Deploy Phases

```ruby
# In routes (app.rb):

# Phase 1 (Current)
get "/random" do
  @meme = navigate_meme(direction: "next")  # Uses weighted selection
  erb :random
end

# Phase 2 (Active for logged-in users)
# navigate_meme() checks user_id and routes accordingly:
# - New users (< 10 views) → Phase 1 pools
# - Established users → Phase 2 personalized pools

# Phase 3 (Future - switch navigate_meme_v3)
# @meme = navigate_meme_v3(direction: "next")
```

---

**Status:** Phases 1 & 2 now active. Monitor metrics and prepare Phase 3 for Q3 launch.
