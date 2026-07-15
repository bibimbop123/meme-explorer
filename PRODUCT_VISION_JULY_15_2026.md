# Product Vision - Meme Explorer
## Decided: July 15, 2026

---

## 🎯 The Decision

**Meme Explorer is a Simple Meme Browser.**

Like TikTok but for static memes. Quick, endless discovery. Minimal UI, maximum content.

---

## What This Means

### Core Value Proposition
**"The fastest way to discover great memes from Reddit"**

### User Experience
- Open app → See funny meme → Swipe/click for next → Repeat
- No learning curve
- No explanations needed
- Instant gratification

### Design Philosophy
**Content First, Everything Else Second**

---

## What We ARE

✅ **Fast** - <100ms to show next meme  
✅ **Simple** - No tutorials needed  
✅ **Endless** - Never run out of content  
✅ **Personalized** - Gets better the more you use it (subtle, background)  
✅ **Mobile-first** - Optimized for phones  
✅ **Ad-supported** - But ads don't dominate the experience  

---

## What We Are NOT

❌ **Gamified** - No forced achievements, levels, or XP  
❌ **Social network** - No profiles, followers, or feeds  
❌ **Curated** - No editorial voice or curator notes  
❌ **Educational** - Not teaching meme history  
❌ **Complex** - No feature explanations needed  

---

## Feature Priorities

### Core Features (Must Have)
1. **Random meme discovery** - The main action
2. **Like button** - Simple positive feedback
3. **Next button** - Core navigation
4. **Save for later** - Basic collection
5. **Trending** - What's popular now
6. **Categories** - Browse by mood/type

### Secondary Features (Nice to Have)
7. **Search** - Find specific memes
8. **Share** - Send to friends
9. **Dark mode** - Visual preference
10. **Keyboard shortcuts** - Power user feature

### Optional Features (Hidden Until Earned)
11. **Streak tracking** - For engaged users only (shown after 7 days)
12. **Personal stats** - Available in profile, not pushed
13. **Collections** - Advanced organization (not featured prominently)

### Features to REMOVE
❌ Curator notes  
❌ Rarity badges  
❌ Quality signals  
❌ XP notifications  
❌ Level system  
❌ Achievement popups  
❌ Surprise rewards  
❌ Leaderboards (or hide by default)  
❌ Battle system  
❌ Near-miss mechanics  
❌ Particle effects  
❌ Sound effects  
❌ Haptic feedback  

---

## User Journey

### First-Time User (Anonymous)
```
1. Land on homepage
2. See a funny meme immediately
3. Laugh
4. Click "Next" (or swipe)
5. See another meme
6. After 5 memes, subtle prompt: "Like this? Sign up to save favorites"
7. Continue browsing (no forced signup)
```

### Returning User (Logged In)
```
1. Open app
2. See meme (personalized based on history)
3. Like it (heart animation, no fanfare)
4. Next meme
5. After 20+ memes in session: "You've been scrolling for 10 minutes 😅 Take a break?"
6. Optional: Check trending, saved memes
```

### Power User (7+ days active)
```
1. Keyboard shortcuts work (Space, L, S)
2. Stats available in profile (but not pushed)
3. Streak shown subtly in corner (not blocking content)
4. Collections feature unlocked
5. Advanced filters available
```

---

## Design System

### Typography
**Single font system:**
- Primary: Inter (clean, modern sans-serif)
- Fallback: System font

**Remove:**
- ❌ Crimson Pro (too formal)
- ❌ Comic Neue (too playful)

### Colors
**Simple palette:**
- Background: `#FFFFFF` (light) / `#1A1A1A` (dark)
- Primary: `#FF6B6B` (like button, accents)
- Text: `#333333` (light) / `#E0E0E0` (dark)
- Borders: `#E5E5E5` (light) / `#333333` (dark)

### Layout
**Mobile:**
```
┌─────────────────┐
│ [Logo]     [☰]  │ ← 50px header
├─────────────────┤
│                 │
│                 │
│     [MEME]      │ ← 80% of viewport
│                 │
│                 │
├─────────────────┤
│  ❤️  →  💾       │ ← 60px actions
└─────────────────┘
```

**Desktop:**
```
┌──────────────────────────────┐
│ [Logo]  Random  Trending  ☰  │ ← 60px header
├──────────────────────────────┤
│                              │
│         [MEME 800px]         │ ← Centered, large
│                              │
├──────────────────────────────┤
│    ❤️ Like    → Next    💾 Save   │ ← 80px actions
├──────────────────────────────┤
│  [ Optional Ad Unit ]        │ ← Below fold
└──────────────────────────────┘
```

---

## Metrics That Matter

### Primary Metric
**Memes Viewed Per Session**
- Target: >10 (currently: ?)
- Why: Measures core engagement

### Secondary Metrics
1. **Session Duration** - Target: >5 minutes
2. **Return Rate (Next Day)** - Target: >40%
3. **Like Rate** - Target: >30% of memes viewed
4. **Mobile vs Desktop** - Expect 70/30 split

### Quality Metrics
1. **Broken Image Rate** - Target: <2%
2. **Load Time (Random Meme)** - Target: <100ms
3. **Error Rate** - Target: <1%

### Revenue Metrics
1. **RPM (Revenue Per Mille)** - Revenue per 1000 pageviews
2. **Ad Viewability** - Target: >70%
3. **User satisfaction** - Track alongside revenue (don't sacrifice UX for $$$)

---

## Technical Implications

### What Gets Simplified
1. **60+ services → 20 services**
2. **30+ database tables → 15 tables**
3. **15+ CSS files → 3 files** (layout, theme, mobile)
4. **20+ JS files → 5 files** (core, lazy-loaded features)

### What Gets Removed
- Gamification workers (achievements, streaks, levels)
- Curator notes service
- Surprise rewards
- Near-miss mechanics
- Sound/haptic systems
- Particle effects
- Battle system
- A/B testing framework (if not used)

### What Gets Kept (But Hidden)
- Basic streak tracking (show after 7 days)
- User stats (in profile, not prominent)
- Collections (available but not featured)
- Personalization (works in background, invisible)

---

## Implementation Plan

### Phase 1: Simplify UI (Week 3-4)
**Remove clutter, focus on content**

**Changes:**
- Move gamification to settings (hidden by default)
- Remove curator notes from main flow
- Remove quality/rarity signals
- Reduce to ONE ad per page
- Increase meme size to 70% of viewport
- Add keyboard shortcuts

**Files to modify:**
- `views/random.erb` - Strip down to essentials
- `views/layout.erb` - Simplify header
- `public/css/simplified-ui.css` - New minimal stylesheet
- `config/feature_flags.yml` - Add "show_gamification" flag (default: false)

**Expected Impact:**
- Content visibility: 30% → 70%
- Cognitive load: -60%
- First-time retention: +30%

### Phase 2: Remove Unused Code (Week 5-8)
**Delete features that don't serve core experience**

**Services to Remove:**
- `lib/services/curator_notes_service.rb`
- `lib/services/surprise_rewards_service.rb`
- `lib/services/near_miss_service.rb`
- `lib/services/surprise_mechanics_service.rb`
- `lib/services/humor_optimizer_service.rb`

**Routes to Remove:**
- `routes/battles.rb` (if not used)
- Gamification endpoints (move to optional API)

**Database Tables to Remove:**
- `meme_battles`
- `meme_elo_ratings`
- `ab_test_assignments` (if not used)

**JavaScript to Remove:**
- `public/js/sound-system.js`
- `public/js/haptic-system.js`
- `public/js/particle-effects.js`
- `public/js/achievement-system.js` (or make optional)

### Phase 3: Performance (Week 11-12)
**Make it fast**

**Targets:**
- Random meme: <100ms
- Trending page: <200ms
- Mobile Lighthouse: >90

**Optimizations:**
- Composite database indexes
- Aggressive caching (5min for trending)
- Eager load queries (fix N+1)
- Code splitting (lazy load non-essentials)
- Image lazy loading
- CDN for static assets

---

## AdSense Strategy

### Placement Philosophy
**"One Great Ad > Three Bad Ads"**

### Desktop
```
Header: Logo + Nav (no ads)
Main: Meme (large, unobstructed)
Actions: Like/Next/Save
---
Below fold: ONE 728x90 banner OR 336x280 rectangle
```

### Mobile
```
Header: Logo + Menu
Main: Meme (full width, tall)
Actions: Large touch targets
---
Far below fold: ONE 320x50 banner
```

### Rules
1. Never put ads between header and meme
2. Never put ads between meme and actions
3. Ads must be below the fold on mobile
4. Maximum 1 ad unit per page view
5. Track user satisfaction alongside revenue

---

## Content Strategy

### Subreddit Focus
**Top Tier (Always Active):**
- r/memes
- r/funny
- r/dankmemes
- r/wholesomememes
- r/meirl

**Second Tier (Rotate Based on Trends):**
- Category-specific (animals, gaming, etc.)
- Trending subreddits
- User-requested additions

### Quality Filter
**Simple approach:**
- Minimum score: 500 upvotes
- Maximum age: 7 days
- Broken image filter: Active
- User reports: Remove after 3 reports

**Remove:**
- Complex quality scoring
- Crowdsourced ratings
- Contextual scoring
- Multiple quality columns in DB

---

## Success Criteria (12 Weeks)

### User Engagement
- [ ] Memes viewed per session: +30% from baseline
- [ ] Session duration: +25% from baseline
- [ ] Next-day return rate: +15% from baseline
- [ ] Mobile bounce rate: <40%

### Performance
- [ ] Random meme load: <100ms
- [ ] Trending page load: <200ms
- [ ] Mobile Lighthouse score: >90
- [ ] Error rate: <1%

### Technical Health
- [ ] Services: 60+ → ~20 (67% reduction)
- [ ] Database tables: 30+ → ~15 (50% reduction)
- [ ] Test coverage: 60%+ on critical paths
- [ ] Code complexity: -50%

### Revenue
- [ ] Ad viewability: >70%
- [ ] RPM maintained or improved
- [ ] User satisfaction stable (don't sacrifice UX)

---

## What Success Looks Like

### 6 Months from Now
- New users immediately understand what to do
- Mobile experience is flawless
- Performance is noticeably fast
- Code is maintainable by any developer
- Users describe us as "like TikTok but for memes"

### User Quotes We Want
- "This is so simple, I love it"
- "I can't stop scrolling"
- "Found 20 memes in 5 minutes"
- "Works great on my phone"
- "No annoying popups or achievements"

### User Quotes We Don't Want
- "What's this XP thing?"
- "Too many things on screen"
- "App is slow on mobile"
- "Ads everywhere"
- "Why do I need a tutorial?"

---

## Decision Authority

### Core Product Decisions
**Product Owner** decides on:
- Feature priorities
- UI changes
- User flow modifications

### Technical Decisions
**Tech Lead** decides on:
- Architecture changes
- Performance optimizations
- Code refactoring approach

### Revenue Decisions
**Business Owner** decides on:
- Ad placement
- Monetization strategy
- Growth initiatives

### Guiding Principle
**When in doubt, choose simplicity over features.**

---

## Rollback Clause

**If after 8 weeks:**
- DAU drops >15%
- Revenue drops >20%
- Users explicitly request gamification back

**Then:**
- Survey users to understand why
- Consider making gamification opt-in
- Re-evaluate product vision
- Don't panic-revert everything

**But likely:**
- Simpler experience will improve engagement
- Reduced complexity will improve retention
- Focus on core will increase satisfaction

---

## Final Commitment

**We commit to:**
1. Putting content first
2. Making mobile experience excellent
3. Removing features that don't serve core value
4. Measuring what matters
5. Staying simple

**We will NOT:**
1. Add features without user validation
2. Sacrifice UX for vanity metrics
3. Make the app complex to seem sophisticated
4. Copy competitors without understanding why
5. Build features because they're "cool"

---

**This is our product vision. Everything else flows from this decision.**

**Approved by:** [Your Name]  
**Date:** July 15, 2026  
**Review Date:** October 15, 2026 (3 months)

---

## Next Steps (This Week)

1. **Announce the decision** to team
2. **Create feature flag** for simplified UI
3. **Design simplified random meme page** (mockup)
4. **Get user feedback** on mockup (5-10 people)
5. **Begin Week 1 fixes** (mobile, performance, Redis)

**Let's build something people love. 🚀**
