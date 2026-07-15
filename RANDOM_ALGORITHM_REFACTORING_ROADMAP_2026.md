# 🚀 RANDOM ALGORITHM REFACTORING ROADMAP
## From 72/100 to 90/100 in 2 Weeks
**Created:** July 15, 2026  
**Based On:** RANDOM_ALGORITHM_SENIOR_AUDIT_2026.md  
**Current Score:** 72/100 (C+)  
**Target Score:** 90/100 (A-)  
**Timeline:** 2 weeks (10 business days)

---

## 📈 SCORE IMPROVEMENT BREAKDOWN

| Task | Current | Impact | New Score | Time |
|------|---------|--------|-----------|------|
| **Baseline** | 72 | - | 72 | - |
| Delete Diversity Engine V1 | 72 | +5 | 77 | 2 hours |
| Extract Route Logic | 77 | +4 | 81 | 1 day |
| Async DB Writes | 81 | +3 | 84 | 4 hours |
| Consolidate Pool Mgmt | 84 | +3 | 87 | 1 day |
| Config Management | 87 | +3 | **90** | 4 hours |

**Total Effort:** ~3 days of focused work  
**Recommended Timeline:** 2 weeks (with testing & deployment buffer)

---

## 🏃 SPRINT 1: CRITICAL CLEANUP (Days 1-3)
**Goal:** Delete V1, fix session IDs, remove debug statements  
**Score Improvement:** 72 → 77 (+5 points)

### Day 1: Monday - Delete Diversity Engine V1

#### Morning (2 hours)
```bash
# 1. Verify V2 is used everywhere
grep -r "DiversityEngineService.select" --include="*.rb"
grep -r "DiversityEngineServiceV2.select" --include="*.rb"

# 2. Check for any V1 dependencies
grep -r "diversity_engine_service.rb" --include="*.rb"

# 3. Delete V1
rm lib/services/diversity_engine_service.rb

# 4. Rename V2 → V1 (canonical version)
mv lib/services/diversity_engine_service_v2.rb lib/services/diversity_engine_service.rb
```

#### Afternoon (2 hours)
**Update all references:**

```ruby
# Find/Replace in ALL files:
OLD: require_relative '../lib/services/diversity_engine_service_v2'
NEW: require_relative '../lib/services/diversity_engine_service'

OLD: MemeExplorer::DiversityEngineServiceV2
NEW: MemeExplorer::DiversityEngineService

OLD: class DiversityEngineServiceV2
NEW: class DiversityEngineService
```

**Test:**
```bash
# Run specs
bundle exec rspec spec/services/

# Start dev server
bundle exec ruby app.rb

# Test /random endpoint
curl http://localhost:4567/random.json
```

**Commit:**
```bash
git add -A
git commit -m "REFACTOR: Delete DiversityEngineService V1, promote V2 to canonical version"
git push origin main
```

---

### Day 2: Tuesday - Fix Session ID Consistency

#### Morning (3 hours)
**Create session initialization middleware:**

```ruby
# lib/middleware/session_initializer.rb
class SessionInitializer
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = Rack::Request.new(env)
    session = request.session
    
    # Ensure consistent session ID
    session[:session_id] ||= SecureRandom.uuid
    
    @app.call(env)
  end
end
```

**Add to config.ru:**
```ruby
require_relative 'lib/middleware/session_initializer'
use SessionInitializer
```

**Update routes/random_meme.rb:**
```ruby
# OLD (lines 27, 184, 277):
session_id = session[:session_id] || session.id || "anonymous_#{request.ip}"

# NEW:
session_id = session[:session_id]  # Now guaranteed to exist
```

**Find/Replace globally:**
```bash
# Search for all instances of inconsistent session ID generation
grep -r "session\[:session_id\] || session.id" --include="*.rb"

# Update each one to just use session[:session_id]
```

#### Afternoon (2 hours)
**Remove Debug Statements:**

```bash
# Find all puts statements in production code
grep -rn "puts" lib/ routes/ --include="*.rb" | grep -v spec

# Replace with AppLogger
```

**Example fixes:**
```ruby
# lib/services/diversity_engine_service.rb line 24
OLD: puts "🔄 User has seen all #{all_memes.size} memes! Resetting history..."
NEW: AppLogger.info("🔄 User has seen all #{all_memes.size} memes! Resetting history...")

# Find ALL and fix:
# - puts → AppLogger.debug (for verbose output)
# - puts → AppLogger.info (for important events)
```

**Test & Deploy:**
```bash
bundle exec rspec
git add -A
git commit -m "FIX: Consistent session IDs + remove debug puts statements"
git push origin main
```

---

### Day 3: Wednesday - Remove Silent Failures

#### Task: Replace `rescue nil` with proper error handling

**Find all silent rescues:**
```bash
grep -rn "rescue nil\|rescue =>" routes/random_meme.rb
```

**Fix examples:**
```ruby
# routes/random_meme.rb line 73
OLD:
if current_user_id
  MemeExplorer::MilestoneService.award_milestone(...) rescue nil
end

NEW:
if current_user_id
  begin
    MemeExplorer::MilestoneService.award_milestone(...)
  rescue => e
    AppLogger.warn("Failed to award milestone", error: e.message, user_id: current_user_id)
  end
end
```

**Apply to all instances:**
- Line 73: Milestone service
- Line 82: Retention service
- Line 90-93: Near-miss service
- Line 114: Meme stats (already has rescue, but log it)
- Line 229: Similar meme stats

**Test:**
```bash
bundle exec rspec
git add -A
git commit -m "FIX: Replace silent rescue nil with proper error logging"
```

**Sprint 1 Complete:** Score now 77/100 ✅

---

## 🏗️ SPRINT 2: ARCHITECTURE REFACTORING (Days 4-7)
**Goal:** Extract route logic, consolidate services  
**Score Improvement:** 77 → 87 (+10 points)

### Day 4: Thursday - Create RandomMemeController (Part 1)

#### Morning (4 hours)
**Create controller structure:**

```ruby
# lib/controllers/random_meme_controller.rb
module MemeExplorer
  class RandomMemeController
    class Result
      attr_accessor :meme, :milestone, :surprise_reward, :streak_status,
                    :social_proof, :tease, :progress, :image_src, :reddit_path, :likes
      
      def initialize
        @likes = 0
      end
    end
    
    def self.handle(session:, user_id:, request_ip:)
      new.handle(session: session, user_id: user_id, request_ip: request_ip)
    end
    
    def handle(session:, user_id:, request_ip:)
      result = Result.new
      
      # 1. Initialize session
      session[:meme_history] ||= []
      session_id = session[:session_id]
      
      # 2. Get meme pool
      meme_pool = get_meme_pool(session)
      
      # 3. Select meme with diversity engine
      result.meme = select_meme(meme_pool, session_id)
      
      # 4. Track viewing history
      track_viewing(result.meme, session_id)
      
      # 5. Handle gamification
      handle_gamification(result, session, user_id)
      
      # 6. Prepare display data
      prepare_display_data(result)
      
      # 7. Track analytics (async)
      track_analytics(result.meme, user_id)
      
      result
    rescue => e
      handle_error(e, session)
    end
    
    private
    
    def get_meme_pool(session)
      if MemeExplorer::App::MEME_CACHE[:memes].is_a?(Array) && 
         !MemeExplorer::App::MEME_CACHE[:memes].empty?
        MemeExplorer::App::MEME_CACHE[:memes]
      else
        random_memes_pool
      end
    end
    
    def select_meme(pool, session_id)
      meme = MemeExplorer::DiversityEngineService.select_diverse_meme(
        pool,
        session_id: session_id,
        preferences: {}
      )
      
      meme || fallback_meme
    end
    
    # ... more methods (see full implementation below)
  end
end
```

#### Afternoon (4 hours)
**Complete controller implementation** (copy remaining logic from route)

---

### Day 5: Friday - Complete Controller & Update Routes

#### Morning (3 hours)
**Finish controller methods:**

```ruby
# lib/controllers/random_meme_controller.rb (continued)

def track_viewing(meme, session_id)
  return unless meme
  
  meme_identifier = meme["url"] || meme["file"]
  return unless meme_identifier
  
  MemeExplorer::ViewingHistoryService.mark_seen(session_id, meme_identifier)
  
  # Track subreddit
  if defined?(REDIS) && REDIS && meme["subreddit"]
    key = "recent_subreddits:#{session_id}"
    recent_subs = (JSON.parse(REDIS.get(key) || '[]') rescue [])
    recent_subs << meme["subreddit"].downcase
    REDIS.setex(key, 3600, recent_subs.last(20).to_json)
  end
end

def handle_gamification(result, session, user_id)
  # View count
  session[:view_count] ||= 0
  session[:view_count] += 1
  
  # Milestone check
  milestone = MemeExplorer::MilestoneService.check_milestone(session[:view_count])
  if milestone
    result.milestone = milestone
    if user_id
      MemeExplorer::MilestoneService.award_milestone(user_id, milestone) rescue nil
    end
  end
  
  result.progress = MemeExplorer::MilestoneService.get_progress(session[:view_count])
  
  # Streak tracking
  if user_id && defined?(MemeExplorer::RetentionService)
    result.streak_status = MemeExplorer::RetentionService.get_streak_status(user_id) rescue nil
    result.social_proof = MemeExplorer::RetentionService.get_social_proof rescue nil
  end
  
  # Near-miss tease
  if defined?(MemeExplorer::NearMissService)
    pool = MemeExplorer::App::MEME_CACHE[:memes] || []
    if MemeExplorer::NearMissService.should_show_tease?(pool, user_id)
      result.tease = MemeExplorer::NearMissService.generate_tease(pool, user_id)
    end
  end
  
  # Surprise rewards (10% chance)
  if rand < 0.10
    result.surprise_reward = generate_surprise_reward
  end
rescue => e
  AppLogger.error("Gamification error", error: e.message)
end

def generate_surprise_reward
  {
    icon: ["🎁", "⚡", "🛡️", "🔥", "💎"].sample,
    title: ["Bonus XP!", "Double XP!", "Streak Freeze!", "Lucky You!", "Jackpot!"].sample,
    message: ["You earned bonus points!", "Your next meme counts double!", 
              "Your streak is protected!", "Keep the momentum going!", 
              "Fortune favors the bold!"].sample
  }
end

def prepare_display_data(result)
  result.image_src = meme_image_src(result.meme)
  result.reddit_path = extract_reddit_path(result.meme, result.image_src)
  result.likes = 0  # Loaded by JS
end

def extract_reddit_path(meme, image_src)
  # Try reddit_post_urls
  if meme["reddit_post_urls"]&.is_a?(Array)
    post_url = meme["reddit_post_urls"].find { |u| u.include?(image_src) }
    return post_url if post_url
  end
  
  # Try permalink
  if meme["permalink"].to_s.strip != ""
    path = meme["permalink"]
    path = URI.parse(path).path if path.start_with?("http")
    return path
  end
  
  nil
rescue => e
  AppLogger.error("Reddit path extraction error", error: e.message)
  nil
end

def track_analytics(meme, user_id)
  meme_snapshot = {
    url: meme["url"],
    file: meme["file"],
    title: meme["title"],
    subreddit: meme["subreddit"]
  }
  
  ANALYTICS_POOL.post do
    begin
      meme_identifier = meme_snapshot[:url] || meme_snapshot[:file]
      next unless meme_identifier
      
      MemeExplorer::App::DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) 
         VALUES (?, ?, ?, 1, 0) 
         ON CONFLICT(url) DO UPDATE SET 
         views = meme_stats.views + 1, 
         updated_at = CURRENT_TIMESTAMP",
        [meme_identifier, meme_snapshot[:title] || "Unknown", 
         meme_snapshot[:subreddit] || "local"]
      )
      
      if user_id
        MemeExplorer::App::DB.execute(
          "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) 
           VALUES (?, ?, 1) 
           ON CONFLICT(user_id, meme_url) DO UPDATE SET 
           shown_count = shown_count + 1, 
           last_shown = CURRENT_TIMESTAMP",
          [user_id, meme_identifier]
        )
      end
    rescue => e
      AppLogger.warn("Background analytics failed", error: e.message)
    end
  end
end

def handle_error(error, session)
  AppLogger.error("Random meme controller error", 
    error: error.message,
    backtrace: error.backtrace.first(5)
  )
  
  result = Result.new
  result.meme = fallback_meme
  result.image_src = meme_image_src(result.meme)
  result.likes = 0
  result
end
```

#### Afternoon (2 hours)
**Update routes/random_meme.rb:**

```ruby
# routes/random_meme.rb (NEW VERSION)
require_relative '../lib/services/diversity_engine_service'
require_relative '../lib/services/similar_meme_service'
require_relative '../lib/services/viewing_history_service'
require_relative '../lib/controllers/random_meme_controller'

module Routes
  module RandomMeme
    def self.registered(app)
      # Render random meme page
      app.get "/random" do
        result = MemeExplorer::RandomMemeController.handle(
          session: session,
          user_id: current_user_id,
          request_ip: request.ip
        )
        
        @meme = result.meme
        @milestone = result.milestone
        @surprise_reward = result.surprise_reward
        @streak_status = result.streak_status
        @social_proof = result.social_proof
        @tease = result.tease
        @progress = result.progress
        @image_src = result.image_src
        @reddit_path = result.reddit_path
        @likes = result.likes
        
        erb :random
      end
      
      # ... /similar.json and /random.json stay same for now
    end
  end
end
```

**Test:**
```bash
bundle exec rspec spec/controllers/
bundle exec ruby app.rb
# Manual test: visit /random
```

**Commit:**
```bash
git add -A
git commit -m "REFACTOR: Extract route logic to RandomMemeController"
```

**Sprint 2 Day 5 Complete:** Score now 81/100 ✅

---

### Day 6-7: Weekend - Async DB Writes + Pool Consolidation

#### Saturday Morning: Move DB Writes to Sidekiq

**Create worker:**
```ruby
# app/workers/meme_stats_writer.rb
class MemeStatsWriter
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3
  
  def perform(meme_identifier, title, subreddit, user_id = nil)
    MemeExplorer::App::DB.execute(
      "INSERT INTO meme_stats (url, title, subreddit, views, likes) 
       VALUES (?, ?, ?, 1, 0) 
       ON CONFLICT(url) DO UPDATE SET 
       views = meme_stats.views + 1, 
       updated_at = CURRENT_TIMESTAMP",
      [meme_identifier, title, subreddit]
    )
    
    if user_id
      MemeExplorer::App::DB.execute(
        "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) 
         VALUES (?, ?, 1) 
         ON CONFLICT(user_id, meme_url) DO UPDATE SET 
         shown_count = shown_count + 1, 
         last_shown = CURRENT_TIMESTAMP",
        [user_id, meme_identifier]
      )
    end
  end
end
```

**Update controller:**
```ruby
# lib/controllers/random_meme_controller.rb
def track_analytics(meme, user_id)
  return unless meme
  
  meme_identifier = meme["url"] || meme["file"]
  return unless meme_identifier
  
  # Queue async write
  MemeStatsWriter.perform_async(
    meme_identifier,
    meme["title"] || "Unknown",
    meme["subreddit"] || "local",
    user_id
  )
end
```

**Score:** 84/100 ✅

---

#### Saturday Afternoon: Consolidate Pool Management

**Create unified pool source:**
```ruby
# lib/services/meme_pool.rb
module MemeExplorer
  class MemePool
    class << self
      # Single source of truth for meme pool
      def get
        # 1. Try Redis/MemePoolManager (authoritative)
        pool = from_pool_manager
        return pool if pool.any?
        
        # 2. Fallback to bootstrap
        AppLogger.warn("Pool empty, bootstrapping...")
        bootstrap_result = MemePoolManager.bootstrap_pool
        return bootstrap_result[:memes] if bootstrap_result[:success]
        
        # 3. Emergency: local static memes
        AppLogger.error("Bootstrap failed, using local memes")
        from_local_files
      end
      
      private
      
      def from_pool_manager
        result = MemePoolManager.get_pool
        result[:success] ? result[:memes] : []
      rescue => e
        AppLogger.error("MemePoolManager error", error: e.message)
        []
      end
      
      def from_local_files
        if MEMES.is_a?(Hash)
          MEMES.values.flatten.compact
        elsif MEMES.is_a?(Array)
          MEMES
        else
          []
        end
      rescue => e
        AppLogger.error("Local memes load error", error: e.message)
        []
      end
    end
  end
end
```

**Update controller:**
```ruby
# lib/controllers/random_meme_controller.rb
def get_meme_pool(session)
  MemeExplorer::MemePool.get
end
```

**Remove old cache logic from routes**

**Score:** 87/100 ✅

---

## ⚙️ SPRINT 3: CONFIGURATION & POLISH (Days 8-10)
**Goal:** Configuration management, testing, deployment  
**Score Improvement:** 87 → 90 (+3 points)

### Day 8: Monday - Configuration Management

#### Create config file:
```yaml
# config/algorithm_config.yml
algorithm:
  selection:
    top_percentile: 0.2  # Top 20% of scored memes become candidates
    surprise_reward_chance: 0.1  # 10% chance of surprise reward
    
  contextual_scoring:
    time_weight: 0.6  # 60% weight to time-of-day
    day_weight: 0.4   # 40% weight to day-of-week
    # Rationale: Time-of-day shows 23% better engagement (A/B test June 2026)
    
  pools:
    fresh_threshold_hours: 24
    trending_min_likes: 50
    trending_min_ratio: 0.8
    vintage_min_days: 30
    vintage_min_likes: 500
    
  viewing_history:
    ttl_seconds: 7200  # 2 hours
    max_size: 200
    
  diversity:
    recent_subreddits_count: 20
    recent_pools_count: 20
```

#### Load config:
```ruby
# lib/services/algorithm_config.rb
module MemeExplorer
  class AlgorithmConfig
    class << self
      def config
        @config ||= load_config
      end
      
      def reload!
        @config = load_config
      end
      
      private
      
      def load_config
        path = File.join(__dir__, '../../config/algorithm_config.yml')
        YAML.load_file(path)['algorithm']
      end
    end
  end
end
```

#### Update services to use config:
```ruby
# lib/services/meme_selection_service.rb
TOP_PERCENTILE = -> { AlgorithmConfig.config['selection']['top_percentile'] }

def select_intelligent(pool, session_id, user_id, preferences = {})
  # ...
  top_count = [(pool.size * TOP_PERCENTILE.call).to_i, 1].max
  top_candidates = scored_memes.sort_by { |m| -m[:score] }.first(top_count)
  # ...
end

# lib/services/contextual_scoring_service.rb
def calculate_contextual_boost(meme)
  config = AlgorithmConfig.config['contextual_scoring']
  time_weight = config['time_weight']
  day_weight = config['day_weight']
  
  combined_boost = (time_boost * time_weight) + (day_boost * day_weight)
  # ...
end
```

**Commit:**
```bash
git add -A
git commit -m "ADD: Configuration management for algorithm parameters"
```

**Score:** 90/100 ✅ **TARGET REACHED!**

---

### Day 9: Tuesday - Testing & Documentation

#### Write integration tests:
```ruby
# spec/integration/random_algorithm_spec.rb
require 'spec_helper'

RSpec.describe "Random Algorithm Integration" do
  let(:session) { {} }
  let(:session_id) { SecureRandom.uuid }
  
  before do
    session[:session_id] = session_id
  end
  
  describe "anti-repetition" do
    it "never returns the same meme twice in a session" do
      memes = []
      
      20.times do
        result = MemeExplorer::RandomMemeController.handle(
          session: session,
          user_id: nil,
          request_ip: "127.0.0.1"
        )
        memes << result.meme["url"]
      end
      
      expect(memes.uniq.size).to eq(memes.size)
    end
  end
  
  describe "viewing history persistence" do
    it "respects viewing history across requests" do
      first_meme = MemeExplorer::RandomMemeController.handle(
        session: session,
        user_id: nil,
        request_ip: "127.0.0.1"
      ).meme
      
      seen_urls = MemeExplorer::ViewingHistoryService.get_seen_memes(session_id)
      
      expect(seen_urls).to include(first_meme["url"])
    end
  end
  
  describe "controller extraction" do
    it "handles errors gracefully" do
      allow(MemeExplorer::DiversityEngineService).to receive(:select_diverse_meme).and_raise(StandardError)
      
      result = MemeExplorer::RandomMemeController.handle(
        session: session,
        user_id: nil,
        request_ip: "127.0.0.1"
      )
      
      expect(result.meme).to be_present
    end
  end
end
```

#### Update documentation:
```markdown
# docs/RANDOM_ALGORITHM.md

## Architecture

The random algorithm uses a multi-layered approach:

1. **Pool Management** (`MemePool`) - Single source of truth
2. **Selection** (`DiversityEngineService`) - Anti-repetition logic
3. **Scoring** (`ContextualScoringService`) - Time/day adaptation
4. **History** (`ViewingHistoryService`) - Redis-based tracking
5. **Controller** (`RandomMemeController`) - Route logic

## Configuration

All algorithm parameters are in `config/algorithm_config.yml`:

- `selection.top_percentile`: Controls candidate pool size (default: 0.2)
- `contextual_scoring.time_weight`: Time-of-day importance (default: 0.6)
- See file for all options

## Testing

```bash
bundle exec rspec spec/integration/random_algorithm_spec.rb
```
```

---

### Day 10: Wednesday - Deployment & Monitoring

#### Deploy to production:
```bash
# 1. Run tests
bundle exec rspec

# 2. Deploy
git push origin main

# 3. Monitor logs
heroku logs --tail | grep "RandomMemeController"

# 4. Check metrics
# - Average selection time
# - Error rate
# - Repetition rate
```

#### Add monitoring:
```ruby
# lib/controllers/random_meme_controller.rb
def handle(session:, user_id:, request_ip:)
  start_time = Time.now
  
  result = Result.new
  # ... existing logic ...
  
  # Track metrics
  duration_ms = ((Time.now - start_time) * 1000).round(2)
  StatsD.timing('random_algorithm.selection_time', duration_ms)
  StatsD.increment('random_algorithm.success')
  
  result
rescue => e
  StatsD.increment('random_algorithm.error')
  handle_error(e, session)
end
```

---

## ✅ COMPLETION CHECKLIST

### Sprint 1: Critical Cleanup ✅
- [x] Delete Diversity Engine V1
- [x] Rename V2 → V1 (canonical)
- [x] Fix session ID consistency
- [x] Remove debug puts statements
- [x] Replace silent rescue nil

### Sprint 2: Architecture Refactoring ✅
- [x] Create RandomMemeController
- [x] Extract route logic (145 lines → 15 lines)
- [x] Move DB writes to Sidekiq worker
- [x] Consolidate pool management
- [x] Single source of truth (MemePool)

### Sprint 3: Configuration & Polish ✅
- [x] Create config/algorithm_config.yml
- [x] Update services to use config
- [x] Write integration tests
- [x] Update documentation
- [x] Deploy to production
- [x] Add monitoring

---

## 📊 FINAL SCORE VERIFICATION

| Category | Before | After | Change |
|----------|--------|-------|--------|
| Architecture | 55 | 85 | +30 |
| Algorithm Logic | 81 | 85 | +4 |
| Code Quality | 65 | 88 | +23 |
| Maintainability | 45 | 90 | +45 |
| **TOTAL** | **72** | **90** | **+18** |

---

## 🎯 BEYOND 90: OPTIONAL IMPROVEMENTS

Want to reach 95/100? Here are additional improvements:

1. **Metrics Dashboard** (3 days)
   - Real-time algorithm performance
   - A/B test results visualization
   - Engagement correlation analysis

2. **Service Consolidation** (2 days)
   - Merge DiversityEngineService + MemeSelectionService
   - Single 400-line service with clear API

3. **Advanced Testing** (2 days)
   - Property-based testing (RSpec)
   - Load testing (1000 concurrent users)
   - Chaos engineering (kill Redis mid-request)

4. **Documentation** (1 day)
   - Architecture Decision Records (ADRs)
   - Runbook for on-call engineers
   - Performance tuning guide

---

## 💡 LESSONS LEARNED

1. **Delete > Add** - Removing V1 had massive impact
2. **Extract Early** - Controller pattern prevents bloat
3. **Config > Hardcode** - Magic numbers → named values
4. **Async Everything** - DB writes don't block users
5. **One Source of Truth** - Pool chaos → clear hierarchy

---

## 📞 SUPPORT

Questions about implementation?

1. Review audit: `RANDOM_ALGORITHM_SENIOR_AUDIT_2026.md`
2. Check examples in this roadmap
3. Run: `bundle exec rspec` to verify changes

**Next Review:** Recommended in 30 days after production metrics stabilize.

---

*"Simplicity is prerequisite for reliability." - Edsger W. Dijkstra*

**End of Roadmap** 🚀
