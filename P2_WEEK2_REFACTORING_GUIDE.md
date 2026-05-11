# 🏗️ P2 Week 2: Architecture Refactoring Guide
**Date:** May 11, 2026  
**Estimated Time:** 8-12 hours  
**Status:** READY TO EXECUTE  
**Complexity:** HIGH - Requires careful testing

---

## 📊 Current State Analysis

### App.rb Statistics
- **Total Lines:** 2,511 lines
- **Routes in app.rb:** 22 GET routes, 5 POST routes, 1 DELETE route
- **Helper Methods:** ~40 helper methods embedded
- **Business Logic:** Mixed throughout routes

### Existing Route Files (Already Modular)
✅ `routes/auth.rb` - Authentication routes  
✅ `routes/battles.rb` - Meme battles  
✅ `routes/reactions.rb` - User reactions  
✅ `routes/ab_testing.rb` - A/B testing admin  
✅ `routes/admin.rb` - Admin panel  
✅ `routes/health.rb` - Health checks  
✅ `routes/profile.rb` - User profiles  
✅ `routes/memes.rb` - Meme-specific routes  
✅ `routes/trending_api.rb` - Trending API  

### Routes Still in App.rb (Need Extraction)
**Home & Random (5 routes):**
- `GET /` - Home page
- `GET /random` - Random meme page
- `GET /random.json` - Random meme API

**Trending (1 route):**
- `GET /trending` - Trending page (should be in routes/trending.rb)

**Categories (2 routes):**
- `GET /category/:name` - Category page
- `GET /category/:name/meme/:title` - Category meme

**Search (2 routes):**
- `GET /search` - Search page
- `GET /api/search.json` - Search API

**Metrics (2 routes):**
- `GET /metrics` - Metrics dashboard
- `GET /metrics.json` - Metrics API

**Leaderboard (2 routes):**
- `GET /leaderboard` - Leaderboard page
- `GET /api/leaderboard` - Leaderboard API

**Saved Memes (3 routes):**
- `GET /saved/:id` - View saved meme
- `POST /api/save-meme` - Save meme
- `POST /api/unsave-meme` - Unsave meme

**System (3 routes):**
- `GET /errors` - Error logs (admin)
- `GET /api/notifications` - User notifications
- `GET /api/activity-stats` - Activity stats

**Misc (2 routes):**
- `POST /like` - Like meme
- `POST /report-broken-image` - Report broken image

---

## 🎯 Phase 1: Extract Routes to Modules (2-3 hours)

### Goal
Move all routes from app.rb into dedicated route modules for better organization and maintainability.

### Implementation Plan

#### Step 1.1: Create Home/Random Routes
**File:** `routes/home.rb`
```ruby
# Home and Random Meme Routes
require 'sinatra/base'

module Routes
  class Home < Sinatra::Base
    # Configuration
    set :views, File.expand_path('../../views', __FILE__)
    
    # Helper access
    helpers do
      # Import helpers from main app
      def meme_image_src(m)
        settings.app.meme_image_src(m)
      end
      
      def fallback_meme
        settings.app.fallback_meme
      end
      
      # ... other needed helpers
    end
    
    # Home page
    get '/' do
      # Move logic from app.rb
      erb :random
    end
    
    # Random meme page
    get '/random' do
      # Move logic from app.rb
      erb :random
    end
    
    # Random meme API
    get '/random.json' do
      # Move logic from app.rb
      content_type :json
      # Return JSON
    end
  end
end
```

#### Step 1.2: Create Trending Routes
**File:** `routes/trending.rb`
```ruby
# Trending Memes Routes
require 'sinatra/base'

module Routes
  class Trending < Sinatra::Base
    set :views, File.expand_path('../../views', __FILE__)
    
    get '/trending' do
      # P2 OPTIMIZATION: Already using SQL sorting
      @memes = DB.execute(
        "SELECT url, title, subreddit, views, likes, 
                (likes * 2 + views) AS score 
         FROM meme_stats 
         ORDER BY score DESC 
         LIMIT 20"
      )
      erb :trending
    end
  end
end
```

#### Step 1.3: Create Categories Routes
**File:** `routes/categories.rb`
```ruby
# Category Routes
require 'sinatra/base'

module Routes
  class Categories < Sinatra::Base
    set :views, File.expand_path('../../views', __FILE__)
    
    before '/category/*' do
      @categories = {
        funny: ["funny", "memes"],
        wholesome: ["wholesome", "aww"],
        dank: ["dank", "dankmemes"],
        selfcare: ["selfcare", "wellness"]
      }
    end
    
    get '/category/:name' do
      # Move logic from app.rb
      erb :category
    end
    
    get '/category/:name/meme/:title' do
      # Move logic from app.rb
      erb :random
    end
  end
end
```

#### Step 1.4: Create Search Routes
**File:** `routes/search.rb`
```ruby
# Search Routes
require 'sinatra/base'

module Routes
  class Search < Sinatra::Base
    set :views, File.expand_path('../../views', __FILE__)
    
    get '/search' do
      query = params[:q]
      @results = search_memes(query)
      @query = query
      erb :search
    end
    
    get '/api/search.json' do
      query = params[:q]
      results = search_memes(query)
      content_type :json
      {
        query: query,
        results: results.map { |m| format_meme_json(m) },
        total: results.size
      }.to_json
    end
  end
end
```

#### Step 1.5: Create Metrics Routes
**File:** `routes/metrics.rb`
```ruby
# Metrics and Monitoring Routes
require 'sinatra/base'

module Routes
  class Metrics < Sinatra::Base
    set :views, File.expand_path('../../views', __FILE__)
    
    get '/metrics' do
      # Move all metrics logic from app.rb
      erb :metrics
    end
    
    get '/metrics.json' do
      content_type :json
      # Return metrics JSON
    end
  end
end
```

#### Step 1.6: Create Leaderboard Routes
**File:** `routes/leaderboard.rb`
```ruby
# Leaderboard Routes
require 'sinatra/base'

module Routes
  class Leaderboard < Sinatra::Base
    set :views, File.expand_path('../../views', __FILE__)
    
    get '/leaderboard' do
      # Move complex leaderboard logic from app.rb
      erb :leaderboard
    end
    
    get '/api/leaderboard' do
      content_type :json
      # Return leaderboard JSON
    end
  end
end
```

#### Step 1.7: Create Saved Memes Routes
**File:** `routes/saved_memes.rb`
```ruby
# Saved Memes Routes
require 'sinatra/base'

module Routes
  class SavedMemes < Sinatra::Base
    set :views, File.expand_path('../../views', __FILE__)
    
    get '/saved/:id' do
      halt 401, "Not logged in" unless session[:user_id]
      # Move logic from app.rb
      erb :saved_meme
    end
    
    post '/api/save-meme' do
      halt 401 unless session[:user_id]
      # Move logic from app.rb
      content_type :json
      { saved: true }.to_json
    end
    
    post '/api/unsave-meme' do
      halt 401 unless session[:user_id]
      # Move logic from app.rb
      content_type :json
      { unsaved: true }.to_json
    end
  end
end
```

#### Step 1.8: Create System Routes
**File:** `routes/system.rb`
```ruby
# System and Admin Routes
require 'sinatra/base'

module Routes
  class System < Sinatra::Base
    get '/errors' do
      halt 403 unless is_admin?
      content_type :json
      # Error logs
    end
    
    get '/api/notifications' do
      halt 401 unless session[:user_id]
      content_type :json
      # Notifications
    end
    
    get '/api/activity-stats' do
      content_type :json
      ActivityTrackerService.stats.to_json
    end
  end
end
```

#### Step 1.9: Create Meme Actions Routes
**File:** `routes/meme_actions.rb`
```ruby
# Meme Action Routes (like, report, etc.)
require 'sinatra/base'

module Routes
  class MemeActions < Sinatra::Base
    post '/like' do
      # Move like logic from app.rb
      content_type :json
      { liked: liked_now, likes: likes }.to_json
    end
    
    post '/report-broken-image' do
      # Move report logic from app.rb
      content_type :json
      { reported: true }.to_json
    end
  end
end
```

#### Step 1.10: Mount All Routes in App.rb
```ruby
# In app.rb, replace inline routes with:
class MemeExplorer < Sinatra::Base
  # ... existing configuration ...
  
  # Mount all route modules
  use Routes::Home
  use Routes::Trending
  use Routes::Categories
  use Routes::Search
  use Routes::Metrics
  use Routes::Leaderboard
  use Routes::SavedMemes
  use Routes::System
  use Routes::MemeActions
  use Routes::Auth
  use Routes::Battles
  use Routes::Reactions
  use Routes::ABTesting
  use Routes::Admin
  use Routes::Health
  use Routes::Profile
  use Routes::TrendingAPI
  
  # Keep only server startup at the end
  run! if app_file == $0
end
```

---

## 🎯 Phase 2: Create Controller Pattern (4-5 hours)

### Goal
Extract business logic from routes into reusable controller classes.

### Why Controllers?
- **Separation of Concerns:** Routes handle HTTP, controllers handle logic
- **Testability:** Controllers can be unit tested independently
- **Reusability:** Same controller method can be used by multiple routes
- **Clarity:** Easier to understand what each route does

### Implementation Plan

#### Step 2.1: Create Base Controller
**File:** `lib/controllers/base_controller.rb`
```ruby
module Controllers
  class BaseController
    attr_reader :params, :session, :request, :db
    
    def initialize(params, session, request, db = ::DB)
      @params = params
      @session = session
      @request = request
      @db = db
    end
    
    # Common authentication helpers
    def current_user
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    end
    
    def logged_in?
      !current_user.nil?
    end
    
    def require_login!
      halt 401, { error: "Authentication required" }.to_json unless logged_in?
    end
    
    def require_admin!
      halt 403, { error: "Admin access required" }.to_json unless is_admin?
    end
    
    def is_admin?
      current_user&.admin? || false
    end
    
    # Visitor ID for anonymous users
    def visitor_id
      session[:user_id] || session[:visitor_id] || request.session_options[:id]
    end
    
    # Response helpers
    def json_response(data, status = 200)
      [status, { 'Content-Type' => 'application/json' }, [data.to_json]]
    end
    
    def error_response(message, status = 400)
      json_response({ error: message }, status)
    end
  end
end
```

#### Step 2.2: Create Memes Controller
**File:** `lib/controllers/memes_controller.rb`
```ruby
module Controllers
  class MemesController < BaseController
    def random_meme
      # Extract logic from GET /random
      meme = MEME_CACHE[:memes].sample rescue fallback_meme
      meme ||= fallback_meme
      
      {
        meme: meme,
        image_src: meme_image_src(meme),
        likes: 0
      }
    end
    
    def random_meme_json
      # Extract logic from GET /random.json
      memes = random_memes_pool
      return error_response("No memes found", 404) if memes.empty?
      
      # Find new meme logic...
      json_response({
        title: meme["title"],
        url: meme["url"],
        # ... other fields
      })
    end
    
    def trending_memes(limit = 20)
      # Extract logic from GET /trending
      @db.execute(
        "SELECT url, title, subreddit, views, likes, 
                (likes * 2 + views) AS score 
         FROM meme_stats 
         ORDER BY score DESC 
         LIMIT ?",
        [limit]
      )
    end
    
    def like_meme
      url = params[:url]
      return error_response("No URL provided") unless url
      
      # Extract like logic...
      json_response({ liked: liked_now, likes: likes })
    end
    
    def report_broken_image
      url = params[:url]
      return error_response("No URL provided") unless url
      
      report_broken_image_url(url)
      json_response({ reported: true, message: "Broken image tracked" })
    end
    
    private
    
    def fallback_meme
      {
        "title" => "Loading memes from the cosmos...",
        "file" => "/images/funny1.jpeg",
        "subreddit" => "loading",
        "is_placeholder" => true
      }
    end
    
    def meme_image_src(m)
      return "/images/funny1.jpeg" unless m.is_a?(Hash)
      m["url"].to_s.strip != "" ? m["url"] : (m["file"].to_s.strip != "" ? m["file"] : "/images/funny1.jpeg")
    end
  end
end
```

#### Step 2.3: Create Search Controller
**File:** `lib/controllers/search_controller.rb`
```ruby
module Controllers
  class SearchController < BaseController
    def search(query)
      return [] unless query
      
      # Extract search logic from app.rb helper
      results = search_memes(query)
      
      {
        query: query,
        results: results,
        total: results.size
      }
    end
    
    def search_json(query)
      data = search(query)
      
      json_response({
        query: data[:query],
        results: data[:results].map { |m| format_meme_for_api(m) },
        total: data[:total]
      })
    end
    
    private
    
    def search_memes(query)
      # Move search_memes helper logic here
      # ...
    end
    
    def format_meme_for_api(meme)
      {
        title: meme["title"],
        url: meme["url"] || meme["file"],
        subreddit: meme["subreddit"],
        likes: meme["likes"].to_i,
        views: meme["views"].to_i,
        source: meme["file"] ? "local" : "reddit",
        engagement_score: (meme["likes"].to_i * 2 + meme["views"].to_i)
      }
    end
  end
end
```

#### Step 2.4: Use Controllers in Routes
**Example in** `routes/home.rb`:
```ruby
module Routes
  class Home < Sinatra::Base
    get '/random' do
      controller = Controllers::MemesController.new(params, session, request)
      data = controller.random_meme
      
      @meme = data[:meme]
      @image_src = data[:image_src]
      @likes = data[:likes]
      
      erb :random
    end
    
    get '/random.json' do
      controller = Controllers::MemesController.new(params, session, request)
      controller.random_meme_json
    end
  end
end
```

---

## 🎯 Phase 3: Extract Models (2-3 hours)

### Goal
Move data access and business logic into dedicated model classes.

### Implementation Plan

#### Step 3.1: Create Meme Model
**File:** `lib/models/meme.rb`
```ruby
class Meme
  attr_accessor :id, :url, :title, :subreddit, :likes, :views, :score
  
  def initialize(attributes = {})
    @id = attributes['id']
    @url = attributes['url']
    @title = attributes['title']
    @subreddit = attributes['subreddit']
    @likes = attributes['likes'].to_i
    @views = attributes['views'].to_i
    @score = attributes['score'].to_i
  end
  
  # Class methods for data access
  class << self
    def trending(limit = 20)
      results = DB.execute(
        "SELECT *, (likes * 2 + views) AS score 
         FROM meme_stats 
         ORDER BY score DESC 
         LIMIT ?",
        [limit]
      )
      results.map { |r| new(r) }
    end
    
    def find_by_url(url)
      result = DB.execute(
        "SELECT * FROM meme_stats WHERE url = ? LIMIT 1",
        [url]
      ).first
      new(result) if result
    end
    
    def search(query)
      escaped_query = query.gsub(/[%_]/, '\\\\\0')
      results = DB.execute(
        "SELECT * FROM meme_stats WHERE title LIKE ? COLLATE NOCASE",
        ["%#{escaped_query}%"]
      )
      results.map { |r| new(r) }
    end
    
    def fresh(limit = 30, hours_ago = 24)
      results = DB.execute(
        "SELECT * FROM meme_stats 
         WHERE updated_at > datetime('now', '-#{hours_ago} hours') 
         AND (failure_count IS NULL OR failure_count < 2) 
         ORDER BY updated_at DESC 
         LIMIT ?",
        [limit]
      )
      results.map { |r| new(r) }
    end
  end
  
  # Instance methods
  def increment_views!
    DB.execute(
      "UPDATE meme_stats SET views = views + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?",
      [@url]
    )
    @views += 1
  end
  
  def increment_likes!
    DB.execute(
      "UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?",
      [@url]
    )
    @likes += 1
  end
  
  def decrement_likes!
    DB.execute(
      "UPDATE meme_stats SET likes = likes - 1, updated_at = CURRENT_TIMESTAMP WHERE url = ? AND likes > 0",
      [@url]
    )
    @likes = [@likes - 1, 0].max
  end
  
  def to_hash
    {
      'id' => @id,
      'url' => @url,
      'title' => @title,
      'subreddit' => @subreddit,
      'likes' => @likes,
      'views' => @views,
      'score' => @score
    }
  end
  
  def to_json(*args)
    to_hash.to_json(*args)
  end
end
```

#### Step 3.2: Enhance User Model
**File:** `lib/models/user.rb` (extend existing)
```ruby
class User
  # Add methods currently in helpers
  
  def saved_memes(page = 1, limit = 10)
    offset = (page - 1) * limit
    SavedMeme.for_user(self.id, limit, offset)
  end
  
  def saved_memes_count
    SavedMeme.count_for_user(self.id)
  end
  
  def save_meme(url, title, subreddit)
    SavedMeme.create(
      user_id: self.id,
      meme_url: url,
      meme_title: title,
      meme_subreddit: subreddit
    )
  end
  
  def unsave_meme(url)
    SavedMeme.delete_for_user(self.id, url)
  end
  
  def has_saved_meme?(url)
    SavedMeme.exists_for_user?(self.id, url)
  end
  
  def liked_memes
    # Get from user_meme_stats
    results = DB.execute(
      "SELECT meme_url, liked_at 
       FROM user_meme_stats 
       WHERE user_id = ? AND liked = 1 
       ORDER BY liked_at DESC",
      [self.id]
    )
    results.map { |r| r.transform_keys(&:to_s) }
  end
end
```

#### Step 3.3: Create SavedMeme Model
**File:** `lib/models/saved_meme.rb`
```ruby
class SavedMeme
  attr_accessor :id, :user_id, :meme_url, :meme_title, :meme_subreddit, :saved_at
  
  def initialize(attributes = {})
    @id = attributes['id']
    @user_id = attributes['user_id']
    @meme_url = attributes['meme_url']
    @meme_title = attributes['meme_title']
    @meme_subreddit = attributes['meme_subreddit']
    @saved_at = attributes['saved_at']
  end
  
  class << self
    def for_user(user_id, limit = 10, offset = 0)
      results = DB.execute(
        "SELECT * FROM saved_memes 
         WHERE user_id = ? 
         ORDER BY saved_at DESC 
         LIMIT ? OFFSET ?",
        [user_id, limit, offset]
      )
      results.map { |r| new(r) }
    end
    
    def count_for_user(user_id)
      DB.get_first_value(
        "SELECT COUNT(*) FROM saved_memes WHERE user_id = ?",
        [user_id]
      ) || 0
    end
    
    def create(user_id:, meme_url:, meme_title:, meme_subreddit:)
      DB.execute(
        "INSERT OR IGNORE INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit) 
         VALUES (?, ?, ?, ?)",
        [user_id, meme_url, meme_title, meme_subreddit]
      )
    end
    
    def delete_for_user(user_id, meme_url)
      DB.execute(
        "DELETE FROM saved_memes WHERE user_id = ? AND meme_url = ?",
        [user_id, meme_url]
      )
    end
    
    def exists_for_user?(user_id, meme_url)
      result = DB.execute(
        "SELECT id FROM saved_memes WHERE user_id = ? AND meme_url = ?",
        [user_id, meme_url]
      ).first
      !result.nil?
    end
  end
end
```

---

## 🎯 Phase 4: Clean Up Helpers (2 hours)

### Goal
Organize helper methods into logical modules and remove duplication.

### Implementation Plan

#### Step 4.1: Create Auth Helpers
**File:** `lib/helpers/auth_helpers.rb`
```ruby
module AuthHelpers
  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find(session[:user_id]) if session[:user_id]
  end
  
  def logged_in?
    !current_user.nil?
  end
  
  def require_login!
    halt 401, "Not logged in" unless logged_in?
  end
  
  def is_admin?
    return false unless session[:user_id]
    begin
      user = DB.execute("SELECT role FROM users WHERE id = ?", [session[:user_id]]).first
      user && user["role"] == "admin"
    rescue
      false
    end
  end
  
  def require_admin!
    halt 403, "Forbidden" unless is_admin?
  end
  
  def visitor_id
    session[:user_id] || session[:visitor_id] || request.session_options[:id] || SecureRandom.hex(16)
  end
end
```

#### Step 4.2: Create View Helpers
**File:** `lib/helpers/view_helpers.rb`
```ruby
module ViewHelpers
  def meme_image_src(m)
    return "/images/funny1.jpeg" unless m.is_a?(Hash)
    m["url"].to_s.strip != "" ? m["url"] : (m["file"].to_s.strip != "" ? m["file"] : "/images/funny1.jpeg")
  end
  
  def fallback_meme
    {
      "title" => "Loading memes from the cosmos...",
      "file" => "/images/funny1.jpeg",
      "subreddit" => "loading",
      "is_placeholder" => true
    }
  end
  
  def format_time_ago(time)
    return "never" unless time
    seconds = Time.now - Time.parse(time.to_s)
    
    case seconds
    when 0..59 then "#{seconds.to_i}s ago"
    when 60..3599 then "#{(seconds / 60).to_i}m ago"
    when 3600..86399 then "#{(seconds / 3600).to_i}h ago"
    else "#{(seconds / 86400).to_i}d ago"
    end
  rescue
    "unknown"
  end
end
```

#### Step 4.3: Organize in App.rb
```ruby
class MemeExplorer < Sinatra::Base
  # Load all helper modules
  helpers AuthHelpers
  helpers ViewHelpers
  helpers GamificationHelpers
  helpers GalleryHelpers
  helpers PersonalityContent
  # ... etc
end
```

---

## 📁 Final File Structure

```
meme-explorer/
├── app.rb (MUCH SMALLER - only config & server startup)
├── routes/
│   ├── home.rb ✨ NEW
│   ├── trending.rb ✨ NEW
│   ├── categories.rb ✨ NEW
│   ├── search.rb ✨ NEW
│   ├── metrics.rb ✨ NEW
│   ├── leaderboard.rb ✨ NEW
│   ├── saved_memes.rb ✨ NEW
│   ├── system.rb ✨ NEW
│   ├── meme_actions.rb ✨ NEW
│   ├── auth.rb ✅ EXISTING
│   ├── battles.rb ✅ EXISTING
│   ├── reactions.rb ✅ EXISTING
│   ├── ab_testing.rb ✅ EXISTING
│   ├── admin.rb ✅ EXISTING
│   ├── health.rb ✅ EXISTING
│   └── profile.rb ✅ EXISTING
├── lib/
│   ├── controllers/ ✨ NEW
│   │   ├── base_controller.rb
│   │   ├── memes_controller.rb
│   │   ├── search_controller.rb
│   │   ├── leaderboard_controller.rb
│   │   └── metrics_controller.rb
│   ├── models/
│   │   ├── user.rb ✅ ENHANCED
│   │   ├── meme.rb ✨ NEW
│   │   └── saved_meme.rb ✨ NEW
│   └── helpers/
│       ├── auth_helpers.rb ✨ NEW
│       ├── view_helpers.rb ✨ NEW
│       ├── meme_helpers.rb ✅ EXISTING
│       ├── gamification_helpers.rb ✅ EXISTING
│       └── gallery_helpers.rb ✅ EXISTING
```

---

## ✅ Testing Strategy

### Phase-by-Phase Testing

**After Phase 1 (Route Extraction):**
```bash
# Test each route still works
curl http://localhost:8080/
curl http://localhost:8080/random
curl http://localhost:8080/trending
curl http://localhost:8080/search?q=funny
# etc.

# Run automated tests
bundle exec rspec
```

**After Phase 2 (Controllers):**
```bash
# Unit test controllers
rspec spec/controllers/memes_controller_spec.rb
rspec spec/controllers/search_controller_spec.rb

# Integration tests
rspec spec/routes/home_spec.rb
```

**After Phase 3 (Models):**
```bash
# Unit test models
rspec spec/models/meme_spec.rb
rspec spec/models/saved_meme_spec.rb

# Test data access
rails console # or irb
> Meme.trending(10)
> Meme.search("funny")
```

**After Phase 4 (Helpers):**
```bash
# Full regression test
bundle exec rspec

# Manual smoke test all pages
```

---

## 🚀 Migration Strategy

### Option A: Big Bang (Risky but Fast)
1. Complete all 4 phases in development
2. Test thoroughly
3. Deploy all at once

**Pros:** Done in one go  
**Cons:** High risk if something breaks

### Option B: Incremental (Safer)
1. Extract one route module at a time
2. Deploy and monitor
3. Move to next module

**Pros:** Lower risk, easier rollback  
**Cons:** Takes longer

### Option C: Feature Branch (Recommended)
1. Create `feature/architecture-refactor` branch
2. Complete all 4 phases
3. Comprehensive testing
4. Code review
5. Merge to main
6. Deploy

**Pros:** Safe, reviewable, testable  
**Cons:** Requires discipline

---

## 📊 Expected Benefits

### Code Quality
- **Before:** 2,511 line app.rb monolith
- **After:** ~500 line app.rb + 15 focused route files

### Maintainability
- **Before:** Hard to find specific route logic
- **After:** Organized by feature, easy to navigate

### Testability
- **Before:** Hard to test individual routes
- **After:** Controllers and models can be unit tested

### Onboarding
- **Before:** New devs overwhelmed by massive file
- **After:** Clear structure, easy to understand

### Performance
- **Impact:** Negligible (routes still loaded at startup)
- **Benefit:** Easier to optimize individual components

---

## ⚠️ Potential Issues & Solutions

### Issue 1: Helper Method Access
**Problem:** Route modules can't access helpers from main app

**Solution:** Use `settings.app` to access main app helpers, or pass needed helpers to controllers

### Issue 2: Session Access
**Problem:** Session not available in controllers

**Solution:** Pass session to controller constructor

### Issue 3: View Rendering
**Problem:** Views expect certain instance variables

**Solution:** Set instance variables in routes before calling `erb`

### Issue 4: Database Access
**Problem:** DB constant not available in models

**Solution:** Use `::DB` or pass DB to model methods

---

## 💡 Quick Start

If you want to start small, do this first:
1. Extract just one route module (e.g., `routes/trending.rb`)
2. Test it works
3. Move on to the next

**Sample Quick Win:**
```ruby
# 1. Create routes/trending.rb with GET /trending
# 2. In app.rb, add: use Routes::Trending
# 3. Remove GET /trending from app.rb
# 4. Test: visit /trending
# 5. If it works, move on to next route
```

---

## ✅ Checklist for Week 2

### Phase 1: Route Extraction
- [ ] Create routes/home.rb
- [ ] Create routes/trending.rb
- [ ] Create routes/categories.rb
- [ ] Create routes/search.rb
- [ ] Create routes/metrics.rb
- [ ] Create routes/leaderboard.rb
- [ ] Create routes/saved_memes.rb
- [ ] Create routes/system.rb
- [ ] Create routes/meme_actions.rb
- [ ] Mount all routes in app.rb
- [ ] Remove extracted routes from app.rb
- [ ] Test all routes still work

### Phase 2: Controllers
- [ ] Create lib/controllers/base_controller.rb
- [ ] Create lib/controllers/memes_controller.rb
- [ ] Create lib/controllers/search_controller.rb
- [ ] Create lib/controllers/leaderboard_controller.rb
- [ ] Update routes to use controllers
- [ ] Test controller integration

### Phase 3: Models
- [ ] Create lib/models/meme.rb
- [ ] Enhance lib/models/user.rb
- [ ] Create lib/models/saved_meme.rb
- [ ] Update controllers to use models
- [ ] Test model methods

### Phase 4: Helpers
- [ ] Create lib/helpers/auth_helpers.rb
- [ ] Create lib/helpers/view_helpers.rb
- [ ] Organize helpers in app.rb
- [ ] Remove duplicate helper methods
- [ ] Test helper availability

### Final Testing
- [ ] Run full test suite
- [ ] Manual smoke test all pages
- [ ] Check for broken links
- [ ] Verify all API endpoints
- [ ] Test authentication flows
- [ ] Test admin functions

---

## 🎯 Success Criteria

Week 2 is complete when:
1. ✅ All routes extracted from app.rb into modules
2. ✅ Controllers created for business logic
3. ✅ Models created for data access
4. ✅ Helpers organized and de-duplicated
5. ✅ App.rb reduced to ~500 lines
6. ✅ All tests passing
7. ✅ No functionality broken
8. ✅ Code is more maintainable

---

## 📚 Resources

- [Sinatra Modular Apps](http://sinatrarb.com/intro.html#Sinatra::Base%20-%20Middleware,%20Libraries,%20and%20Modular%20Apps)
- [MVC Pattern](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller)
- [Ruby Style Guide](https://rubystyle.guide/)

---

**Ready to Execute:** This is a comprehensive refactoring that will significantly improve code quality and maintainability. Start with Phase 1 and work incrementally! 🚀
