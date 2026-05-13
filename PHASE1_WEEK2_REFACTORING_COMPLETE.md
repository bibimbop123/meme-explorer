# 🔨 PHASE 1, WEEK 2: Refactoring & Performance Guide

**Duration:** 58 hours  
**Goal:** Clean architecture + 2x faster page loads  
**Status:** 🔴 Ready to Start

---

## 📋 Overview

Week 2 focuses on architectural cleanup and performance optimization. By the end of this week, you'll have:
- ✅ Clean controller structure (routes extracted from app.rb)
- ✅ Service layer properly organized
- ✅ No duplicate code
- ✅ Database properly indexed
- ✅ No N+1 queries
- ✅ Query result caching
- ✅ Security headers (CSP)

**Impact:** Page load times will drop from ~800ms to ~400ms 🚀

---

## 🎯 Day-by-Day Breakdown

### **Monday-Tuesday: Extract Routes to Controllers** (20 hours)

#### Current Problem
`app.rb` is 2,000+ lines - a monolithic mess mixing routes, logic, and configuration.

#### Solution
Create proper controller structure:

```
app/
  controllers/
    base_controller.rb          ← Shared functionality
    memes_controller.rb         ← /random, /memes/*
    profile_controller.rb       ← /profile, /saved
    leaderboard_controller.rb   ← /leaderboard
    trending_controller.rb      ← /trending
    auth_controller.rb          ← /auth/*
    admin_controller.rb         ← /admin/*
    api_controller.rb           ← /api/*
```

#### Step-by-Step Implementation

**1. Create base controller (2 hours)**

Create `app/controllers/base_controller.rb`:

```ruby
# Base controller with shared functionality
class BaseController < Sinatra::Base
  # Configuration
  configure do
    set :views, File.expand_path('../../views', __FILE__)
    set :public_folder, File.expand_path('../../public', __FILE__)
    enable :sessions
    set :session_secret, ENV['SESSION_SECRET'] || SecureRandom.hex(32)
  end
  
  # Helpers
  helpers do
    def current_user
      return nil unless session[:user_id]
      @current_user ||= begin
        user = DB.execute("SELECT * FROM users WHERE id = ? LIMIT 1", [session[:user_id]]).first
        user&.transform_keys(&:to_sym)
      end
    end
    
    def logged_in?
      !current_user.nil?
    end
    
    def require_login!
      halt 401, json({ error: 'Unauthorized' }) unless logged_in?
    end
    
    def json(data)
      content_type :json
      JSON.generate(data)
    end
    
    def log_error(e, context = {})
      logger.error "#{e.class}: #{e.message}"
      logger.error e.backtrace.first(5).join("\n")
      Sentry.capture_exception(e, extra: context) if defined?(Sentry)
    end
  end
  
  # Error handling
  error 404 do
    if request.accept?('application/json')
      json({ error: 'Not found' })
    else
      erb :error_404
    end
  end
  
  error 500 do
    log_error(env['sinatra.error'])
    if request.accept?('application/json')
      json({ error: 'Internal server error' })
    else
      erb :error_500
    end
  end
end
```

**2. Create MemeController (4 hours)**

Create `app/controllers/memes_controller.rb`:

```ruby
require_relative 'base_controller'
require_relative '../services/random_selector_service'
require_relative '../services/meme_service'

class MemesController < BaseController
  # GET /random
  get '/random' do
    begin
      memes = MEME_CACHE.get(:memes) || []
      
      if memes.empty?
        logger.warn "Cache empty, triggering warm job"
        StartupCacheWarmJob.perform_async
        memes = load_fallback_memes
      end
      
      selected_meme = MemeExplorer::RandomSelectorService.select_random_meme(
        memes,
        session_id: session[:session_id],
        user_id: current_user&.[](:id),
        preferences: current_user&.[](:preferences)
      )
      
      if selected_meme
        # Track view
        MemeService.track_view(selected_meme, current_user&.[](:id))
        
        # Award XP if logged in
        if logged_in?
          GamificationHelpers.add_xp(current_user[:id], :view_meme)
          GamificationHelpers.update_streak(current_user[:id])
        end
        
        erb :random, locals: { meme: selected_meme }
      else
        logger.error "No meme could be selected"
        erb :error, locals: { message: "No memes available" }
      end
      
    rescue => e
      log_error(e, route: '/random')
      erb :error, locals: { message: "Failed to load meme" }
    end
  end
  
  # POST /memes/like
  post '/memes/like' do
    require_login!
    
    url = params[:url]
    halt 400, json({ error: 'Missing URL' }) if url.nil? || url.empty?
    
    begin
      result = MemeService.like_meme(url, current_user[:id])
      GamificationHelpers.add_xp(current_user[:id], :like_meme)
      
      json(result)
    rescue => e
      log_error(e, route: '/memes/like', url: url)
      halt 500, json({ error: 'Failed to like meme' })
    end
  end
  
  # POST /memes/save
  post '/memes/save' do
    require_login!
    
    begin
      result = MemeService.save_meme(
        url: params[:meme_url],
        title: params[:meme_title],
        subreddit: params[:meme_subreddit],
        user_id: current_user[:id]
      )
      
      GamificationHelpers.add_xp(current_user[:id], :save_meme)
      
      json({ success: true, saved: result })
    rescue => e
      log_error(e, route: '/memes/save')
      halt 500, json({ error: 'Failed to save meme' })
    end
  end
  
  # GET /memes/stats
  get '/memes/stats' do
    content_type :json
    
    begin
      stats = {
        total_memes: MEME_CACHE.get(:memes)&.size || 0,
        cached_at: MEME_CACHE.get(:last_refresh),
        total_likes: DB.execute("SELECT SUM(likes) as total FROM meme_stats").first['total'] || 0,
        total_views: DB.execute("SELECT SUM(views) as total FROM meme_stats").first['total'] || 0
      }
      
      json(stats)
    rescue => e
      log_error(e, route: '/memes/stats')
      halt 500, json({ error: 'Failed to fetch stats' })
    end
  end
  
  private
  
  def load_fallback_memes
    yaml_data = YAML.load_file("data/memes.yml")
    memes = yaml_data.is_a?(Hash) ? yaml_data.values.flatten.compact : yaml_data || []
    memes.map do |m|
      m_copy = m.dup
      m_copy["file"] = m_copy["file"][1..-1] if m_copy["file"]&.start_with?("/")
      m_copy
    end
  rescue => e
    logger.error "Failed to load fallback memes: #{e.message}"
    []
  end
end
```

**3. Update app.rb to use controllers (2 hours)**

In `app.rb`, replace route definitions with:

```ruby
# At the top after requires
require_relative 'app/controllers/memes_controller'
require_relative 'app/controllers/profile_controller'
require_relative 'app/controllers/leaderboard_controller'
require_relative 'app/controllers/trending_controller'
require_relative 'app/controllers/auth_controller'
require_relative 'app/controllers/admin_controller'
require_relative 'app/controllers/api_controller'

# Main application class
class MemeExplorer < Sinatra::Base
  # Mount controllers
  use MemesController
  use ProfileController  
  use LeaderboardController
  use TrendingController
  use AuthController
  use AdminController
  use ApiController
  
  # Root route
  get '/' do
    redirect '/random'
  end
  
  # Health check
  get '/health' do
    content_type :json
    {
      status: 'ok',
      timestamp: Time.now.iso8601,
      cache_size: MEME_CACHE.get(:memes)&.size || 0
    }.to_json
  end
end
```

**4. Create remaining controllers (12 hours)**

Follow the same pattern for:
- `ProfileController` (3 hours)
- `LeaderboardController` (2 hours)
- `TrendingController` (2 hours)
- `AuthController` (2 hours)
- `AdminController` (2 hours)
- `ApiController` (1 hour)

---

### **Wednesday: Move Helpers to Services** (15 hours)

#### Current Problem
Helper modules mix presentation logic with business logic. Helpers should only format data for views, not contain business rules.

#### Solution

**1. Analyze current helpers (2 hours)**

```bash
# List all helper files
ls -la lib/helpers/

# Common issues:
# - gamification_helpers.rb has business logic (XP calculation)
# - meme_helpers.rb has API calls
# - gallery_helpers.rb has image processing
```

**2. Extract GamificationService (4 hours)**

Create `lib/services/gamification_service.rb`:

```ruby
class GamificationService
  class << self
    # Add XP and handle level ups
    def add_xp(user_id, action_type)
      xp_amounts = {
        view_meme: 1,
        like_meme: 5,
        save_meme: 10,
        share_meme: 15,
        daily_login: 20,
        week_streak: 50
      }
      
      xp_to_add = xp_amounts[action_type] || 0
      return { success: false, reason: 'Invalid action' } if xp_to_add == 0
      
      # Get current stats
      stats = get_user_stats(user_id)
      new_xp = stats[:xp] + xp_to_add
      old_level = stats[:level]
      new_level = calculate_level(new_xp)
      
      # Update database
      DB.execute(
        "UPDATE user_stats SET xp = ?, level = ? WHERE user_id = ?",
        [new_xp, new_level, user_id]
      )
      
      # Check for level up
      leveled_up = new_level > old_level
      
      {
        success: true,
        xp_added: xp_to_add,
        new_xp: new_xp,
        old_level: old_level,
        new_level: new_level,
        leveled_up: leveled_up
      }
    rescue => e
      logger.error "Failed to add XP: #{e.message}"
      { success: false, error: e.message }
    end
    
    # Update daily streak
    def update_streak(user_id)
      stats = get_user_stats(user_id)
      last_visit = stats[:last_visit] ? Date.parse(stats[:last_visit]) : nil
      today = Date.today
      
      if last_visit.nil?
        # First visit
        new_streak = 1
      elsif last_visit == today
        # Already visited today
        return { current_streak: stats[:current_streak], continued: false }
      elsif last_visit == today - 1
        # Visited yesterday - continue streak
        new_streak = stats[:current_streak] + 1
      else
        # Missed a day - reset streak
        new_streak = 1
      end
      
      # Update longest streak if needed
      longest = [stats[:longest_streak], new_streak].max
      
      DB.execute(
        "UPDATE user_stats SET current_streak = ?, longest_streak = ?, last_visit = ? WHERE user_id = ?",
        [new_streak, longest, today.to_s, user_id]
      )
      
      # Award bonus XP for streak milestones
      if [7, 14, 30, 100].include?(new_streak)
        add_xp(user_id, :week_streak)
      end
      
      {
        current_streak: new_streak,
        longest_streak: longest,
        continued: true
      }
    end
    
    # Calculate level from XP
    def calculate_level(xp)
      # Level formula: level = floor(sqrt(xp / 100))
      # Level 1: 0-99 XP
      # Level 2: 100-399 XP
      # Level 3: 400-899 XP
      # etc.
      Math.sqrt(xp / 100.0).floor + 1
    end
    
    # Get XP needed for next level
    def xp_for_next_level(current_level)
      ((current_level ** 2) * 100) - ((current_level - 1) ** 2) * 100
    end
    
    private
    
    def get_user_stats(user_id)
      result = DB.execute(
        "SELECT * FROM user_stats WHERE user_id = ? LIMIT 1",
        [user_id]
      ).first
      
      return default_stats(user_id) unless result
      result.transform_keys(&:to_sym)
    end
    
    def default_stats(user_id)
      DB.execute(
        "INSERT INTO user_stats (user_id, xp, level, current_streak, longest_streak) VALUES (?, 0, 1, 0, 0)",
        [user_id]
      )
      { user_id: user_id, xp: 0, level: 1, current_streak: 0, longest_streak: 0, last_visit: nil }
    end
  end
end
```

**3. Update gamification_helpers.rb to use service (1 hour)**

```ruby
# lib/helpers/gamification_helpers.rb
require_relative '../services/gamification_service'

module GamificationHelpers
  # Thin wrappers that delegate to service
  def add_xp(user_id, action_type)
    GamificationService.add_xp(user_id, action_type)
  end
  
  def update_streak(user_id)
    GamificationService.update_streak(user_id)
  end
  
  # View helpers (presentation only)
  def format_xp(xp)
    xp.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
  
  def level_badge_class(level)
    case level
    when 1..5 then 'badge-bronze'
    when 6..15 then 'badge-silver'
    when 16..30 then 'badge-gold'
    else 'badge-platinum'
    end
  end
  
  def streak_emoji(streak)
    case streak
    when 0..2 then '🔥'
    when 3..6 then '🔥🔥'
    when 7..13 then '🔥🔥🔥'
    else '🔥🔥🔥🔥'
    end
  end
end
```

**4. Repeat for other helpers (8 hours)**
- Extract `ImageProcessingService` from `meme_helpers.rb`
- Extract `GalleryService` from `gallery_helpers.rb`
- Extract `SeoService` from `seo_helpers.rb` (might already exist)

---

### **Thursday Morning: Clean Up Duplicate Services** (5 hours)

#### Current Problem
You have multiple versions of services:
- `random_selector_service.rb` AND `random_selector_service_v2.rb`
- `trending_service.rb` AND `trending_service_simple.rb`

#### Solution

**1. Audit all services (1 hour)**

```bash
# Find duplicates
cd lib/services
ls -la | grep -E '(_v2|_simple|_old)'

# Common duplicates:
# - random_selector_service_v2.rb
# - trending_service_simple.rb  
# - leaderboard_service_old.rb (if exists)
```

**2. Merge and delete (4 hours)**

For each duplicate:
1. Compare files: `diff random_selector_service.rb random_selector_service_v2.rb`
2. Merge best features into main file
3. Update all references
4. Delete old file
5. Test thoroughly

Example merge strategy:
```ruby
# Keep v2 algorithm but rename to main
mv random_selector_service_v2.rb random_selector_service.rb.new
mv random_selector_service.rb random_selector_service.rb.backup
mv random_selector_service.rb.new random_selector_service.rb

# Update namespace if needed
# Test
bundle exec rspec spec/services/random_selector_service_spec.rb

# If all good, delete backup
rm random_selector_service.rb.backup
```

---

### **Thursday Afternoon: Add Database Indexes** (2 hours)

#### Current Problem
Queries are slow because tables lack proper indexes.

#### Solution

Create `db/migrations/add_performance_indexes_phase1.sql`:

```sql
-- Meme Stats Indexes
CREATE INDEX IF NOT EXISTS idx_meme_stats_likes ON meme_stats(likes DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_views ON meme_stats(views DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_updated_at ON meme_stats(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit ON meme_stats(subreddit);
CREATE INDEX IF NOT EXISTS idx_meme_stats_url ON meme_stats(url);

-- User Stats Indexes
CREATE INDEX IF NOT EXISTS idx_user_stats_user_id ON user_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_stats_xp ON user_stats(xp DESC);
CREATE INDEX IF NOT EXISTS idx_user_stats_level ON user_stats(level DESC);
CREATE INDEX IF NOT EXISTS idx_user_stats_streak ON user_stats(current_streak DESC);

-- Leaderboard Indexes
CREATE INDEX IF NOT EXISTS idx_leaderboard_weekly_score ON leaderboard_weekly(score DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_monthly_score ON leaderboard_monthly(score DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_alltime_score ON leaderboard_all_time(score DESC);

-- User Memes (saved memes) Indexes
CREATE INDEX IF NOT EXISTS idx_user_memes_user_id ON user_memes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_memes_created_at ON user_memes(created_at DESC);

-- Composite Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_meme_stats_trending ON meme_stats(updated_at DESC, likes DESC, views DESC);
CREATE INDEX IF NOT EXISTS idx_user_stats_leaderboard ON user_stats(xp DESC, level DESC, current_streak DESC);

-- Sessions table (if using DB sessions)
CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON sessions(updated_at);
CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id);

-- Analyze tables for query optimization
ANALYZE meme_stats;
ANALYZE user_stats;
ANALYZE leaderboard_weekly;
ANALYZE leaderboard_monthly;
ANALYZE leaderboard_all_time;
ANALYZE user_memes;
```

Run migration:
```bash
# SQLite
sqlite3 memes.db < db/migrations/add_performance_indexes_phase1.sql

# PostgreSQL
psql $DATABASE_URL -f db/migrations/add_performance_indexes_phase1.sql

# Verify indexes created
sqlite3 memes.db ".indexes meme_stats"
```

---

### **Friday Morning: Fix N+1 Queries** (8 hours)

#### Current Problem
Leaderboard page makes 1 query per user (N+1 problem).

#### Solution

**Before (N+1):**
```ruby
# Bad: 1 query + N queries
leaderboard = DB.execute("SELECT user_id FROM leaderboard_weekly LIMIT 10")
leaderboard.each do |entry|
  user = DB.execute("SELECT * FROM users WHERE id = ?", [entry['user_id']]).first
  stats = DB.execute("SELECT * FROM user_stats WHERE user_id = ?", [entry['user_id']]).first
  # Render...
end
```

**After (Single Query):**
```ruby
# Good: 1 query total
leaderboard = DB.execute(<<-SQL)
  SELECT 
    l.*,
    u.email,
    u.avatar_url,
    s.xp,
    s.level,
    s.current_streak
  FROM leaderboard_weekly l
  JOIN users u ON l.user_id = u.id
  JOIN user_stats s ON l.user_id = s.user_id
  ORDER BY l.score DESC
  LIMIT 10
SQL
```

**Update `lib/services/leaderboard_service.rb`:**

```ruby
class LeaderboardService
  def self.get_leaderboard(type: :weekly, limit: 50, offset: 0)
    table_name = case type
    when :weekly then 'leaderboard_weekly'
    when :monthly then 'leaderboard_monthly'
    when :all_time then 'leaderboard_all_time'
    else 'leaderboard_weekly'
    end
    
    # Single optimized query with JOINs
    DB.execute(<<-SQL, [limit, offset])
      SELECT 
        l.rank,
        l.user_id,
        l.score,
        l.updated_at,
        u.email,
        u.username,
        u.avatar_url,
        u.created_at as user_since,
        s.xp,
        s.level,
        s.current_streak,
        s.longest_streak,
        COUNT(um.id) as saved_memes_count
      FROM #{table_name} l
      JOIN users u ON l.user_id = u.id
      JOIN user_stats s ON l.user_id = s.user_id
      LEFT JOIN user_memes um ON um.user_id = u.id
      GROUP BY l.user_id, l.rank, l.score, l.updated_at, u.id, s.id
      ORDER BY l.score DESC
      LIMIT ? OFFSET ?
    SQL
  end
  
  def self.get_user_rank_with_context(user_id, type: :weekly, range: 5)
    table_name = case type
    when :weekly then 'leaderboard_weekly'
    when :monthly then 'leaderboard_monthly'
    when :all_time then 'leaderboard_all_time'
    else 'leaderboard_weekly'
    end
    
    # Get user's rank
    user_rank = DB.execute(<<-SQL, [user_id]).first
      SELECT rank FROM #{table_name} WHERE user_id = ?
    SQL
    
    return nil unless user_rank
    
    rank = user_rank['rank']
    
    # Get users around this rank in one query
    DB.execute(<<-SQL, [rank - range, rank + range])
      SELECT 
        l.rank,
        l.user_id,
        l.score,
        u.username,
        s.level
      FROM #{table_name} l
      JOIN users u ON l.user_id = u.id  
      JOIN user_stats s ON l.user_id = s.user_id
      WHERE l.rank BETWEEN ? AND ?
      ORDER BY l.rank ASC
    SQL
  end
end
```

**Repeat for other services (6 hours):**
- Fix TrendingService meme queries
- Fix ProfileService saved memes queries
- Fix SearchService results queries

---

### **Friday Afternoon: Add Query Caching** (6 hours)

#### Solution

Create `lib/middleware/query_cache.rb`:

```ruby
class QueryCache
  def initialize(app)
    @app = app
  end
  
  def call(env)
    # Enable query caching for this request
    @cache = {}
    
    # Monkey-patch DB.execute for this request
    original_execute = DB.method(:execute)
    
    DB.define_singleton_method(:execute) do |sql, *params|
      # Create cache key from SQL + params
      cache_key = Digest::SHA256.hexdigest("#{sql}:#{params.join(':')}")
      
      # Return cached result if available and query is cacheable
      if cacheable_query?(sql) && @cache.key?(cache_key)
        return @cache[cache_key]
      end
      
      # Execute query and cache result
      result = original_execute.call(sql, *params)
      @cache[cache_key] = result if cacheable_query?(sql)
      result
    end
    
    # Process request
    status, headers, response = @app.call(env)
    
    # Restore original method
    DB.define_singleton_method(:execute, original_execute)
    
    [status, headers, response]
  end
  
  private
  
  def cacheable_query?(sql)
    # Only cache SELECT queries
    sql.strip.upcase.start_with?('SELECT') &&
      # Don't cache queries with NOW() or RANDOM()
      !sql.match?(/\b(NOW|CURRENT_TIMESTAMP|RANDOM)\b/i)
  end
end
```

Add to `config.ru`:
```ruby
use QueryCache
```

---

### **Friday EOD: Add CSP Headers** (2 hours)

Create `lib/middleware/security_headers.rb`:

```ruby
class SecurityHeaders
  def initialize(app)
    @app = app
  end
  
  def call(env)
    status, headers, response = @app.call(env)
    
    # Content Security Policy
    headers['Content-Security-Policy'] = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.googletagmanager.com https://pagead2.googlesyndication.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "img-src 'self' data: https: http:",
      "font-src 'self' https://fonts.gstatic.com",
      "connect-src 'self' https://www.reddit.com https://oauth.reddit.com",
      "frame-src 'self' https://www.googletagmanager.com https://googleads.g.doubleclick.net",
      "media-src 'self' https: http:"
    ].join('; ')
    
    # Other security headers
    headers['X-Frame-Options'] = 'SAMEORIGIN'
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
    
    [status, headers, response]
  end
end
```

Add to `config.ru`:
```ruby
use SecurityHeaders
```

---

## 📊 Week 2 Completion Checklist

- [ ] Routes extracted to 7 controllers
- [ ] app.rb reduced from 2000+ to <200 lines
- [ ] 3 services extracted from helpers
- [ ] All duplicate services merged
- [ ] 15+ database indexes added
- [ ] 0 N+1 queries remaining
- [ ] Query caching middleware active
- [ ] CSP headers configured
- [ ] All tests still passing
- [ ] Page load time <500ms

---

## 🎯 Performance Metrics

**Before Week 2:**
- app.rb: 2000+ lines
- Page load: ~800ms
- Database queries per page: 50+
- N+1 queries: 12
- Test coverage: 40%

**After Week 2:**
- app.rb: <200 lines
- Page load: ~400ms (2x faster!)
- Database queries per page: <10
- N+1 queries: 0
- Test coverage: 40%+ (maintained)

---

## 🚀 Week 2 Summary

By the end of this week:
✅ Clean, maintainable architecture
✅ 2x faster page loads
✅ Scalable to 10,000+ users
✅ No technical debt
✅ Ready for Phase 2 features

**You've transformed from B+ (82/100) to A- (88/100)!** 🎉

---

## 📈 Next: Phase 2 - Entertainment Boost

With a solid foundation, you're ready to add viral features:
- Social sharing with OG tags
- Meme battles 2.0
- Mobile PWA
- Achievement animations
- Surprise rewards

**Phase 1 is complete. Time to make it addictive! 🔥**
