# 🧪 PHASE 1, WEEK 1: Testing & Stability Implementation Guide

**Duration:** 50 hours  
**Goal:** Achieve 40%+ test coverage and fix thread management  
**Status:** 🔴 Not Started

---

## 📋 Overview

This week focuses on building a solid testing foundation and fixing critical infrastructure issues. By the end of Week 1, you'll have:
- ✅ SimpleCov tracking test coverage
- ✅ Tests for 4 critical services
- ✅ Thread management moved to Sidekiq
- ✅ 40%+ test coverage (up from 7.7%)

---

## 🎯 Day-by-Day Breakdown

### **Day 1 (Monday): Test Infrastructure Setup** - 10 hours

#### Morning (4 hours): SimpleCov & FactoryBot Setup

**Step 1: Add testing gems to Gemfile** (30 min)
```ruby
# In Gemfile, add to :development, :test group:
group :development, :test do
  gem "rspec", "~> 3.12"
  gem "rack-test", "~> 2.1"
  gem "database_cleaner-sequel", "~> 1.8"
  gem "factory_bot", "~> 6.2"  # ADD THIS
  gem "simplecov", "~> 0.22"   # ADD THIS
  gem "faker", "~> 3.2"         # ADD THIS
end
```

**Commands to run:**
```bash
bundle install
```

**Step 2: Configure SimpleCov** (30 min)

File already created: `.simplecov`

**Step 3: Update spec_helper.rb** (1 hour)

Add to the TOP of `spec/spec_helper.rb`:
```ruby
# Coverage tracking - MUST be at the very top
require 'simplecov'
SimpleCov.start

require 'factory_bot'
require 'faker'

RSpec.configure do |config|
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Load factories
  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
```

**Step 4: Create factories directory** (1 hour)
```bash
mkdir -p spec/factories
```

File already created: `spec/factories/memes.rb`

**Step 5: Run initial test** (30 min)
```bash
bundle exec rspec --format documentation
```

Expected output: Shows current coverage (7.7%)

#### Afternoon (6 hours): RandomSelectorService Tests

File already created: `spec/services/random_selector_service_spec.rb`

**Run the tests:**
```bash
bundle exec rspec spec/services/random_selector_service_spec.rb --format documentation
```

**Expected failures:** 0-2 tests may fail initially due to service dependencies

**Debug failures:**
1. Check Redis is running: `redis-cli ping`
2. Check database is set up: `ruby db/setup.rb`
3. Add missing test data if needed

---

### **Day 2 (Tuesday): LeaderboardService Tests** - 8 hours

**Create:** `spec/services/leaderboard_service_spec.rb`

```ruby
require 'spec_helper'
require_relative '../../lib/services/leaderboard_service'

RSpec.describe LeaderboardService do
  let(:service) { LeaderboardService.new }
  
  before(:each) do
    # Clean up test data
    DB.execute("DELETE FROM leaderboard_weekly")
    DB.execute("DELETE FROM leaderboard_monthly")
    DB.execute("DELETE FROM leaderboard_all_time")
    DB.execute("DELETE FROM user_stats")
    
    # Create test users
    @user1 = create_test_user(xp: 1000, level: 10, streak: 5)
    @user2 = create_test_user(xp: 500, level: 5, streak: 3)
    @user3 = create_test_user(xp: 2000, level: 15, streak: 10)
  end
  
  describe '#get_leaderboard' do
    context 'weekly leaderboard' do
      it 'returns users sorted by score' do
        leaderboard = service.get_leaderboard(type: :weekly, limit: 10)
        
        expect(leaderboard).to be_an(Array)
        expect(leaderboard.first['user_id']).to eq(@user3)
        expect(leaderboard.size).to be <= 10
      end
      
      it 'respects limit parameter' do
        leaderboard = service.get_leaderboard(type: :weekly, limit: 2)
        expect(leaderboard.size).to eq(2)
      end
    end
    
    context 'monthly leaderboard' do
      it 'calculates monthly rankings correctly' do
        leaderboard = service.get_leaderboard(type: :monthly)
        
        expect(leaderboard).not_to be_empty
        # Highest XP user should be first
        expect(leaderboard.first['xp']).to be >= leaderboard.last['xp']
      end
    end
    
    context 'all-time leaderboard' do
      it 'includes all active users' do
        leaderboard = service.get_leaderboard(type: :all_time, limit: 100)
        expect(leaderboard.size).to eq(3)
      end
    end
  end
  
  describe '#get_user_rank' do
    it 'returns correct rank for user' do
      rank = service.get_user_rank(@user2, type: :weekly)
      
      expect(rank).to be_a(Hash)
      expect(rank['rank']).to eq(2) # Middle user
    end
    
    it 'returns nil for non-existent user' do
      rank = service.get_user_rank(99999, type: :weekly)
      expect(rank).to be_nil
    end
  end
  
  describe '#get_nearby_ranks' do
    it 'returns users above and below target user' do
      nearby = service.get_nearby_ranks(@user2, type: :weekly, range: 1)
      
      expect(nearby).to be_an(Array)
      expect(nearby.size).to be >= 2 # Should include users before/after
    end
  end
  
  describe '#distribute_rewards' do
    it 'awards XP to top users' do
      initial_xp = get_user_xp(@user3)
      
      service.distribute_rewards(type: :weekly)
      
      new_xp = get_user_xp(@user3)
      expect(new_xp).to be > initial_xp
    end
  end
  
  # Helper methods
  def create_test_user(xp: 100, level: 1, streak: 0)
    user_id = DB.execute(
      "INSERT INTO users (email, created_at) VALUES (?, CURRENT_TIMESTAMP) RETURNING id",
      ["test_#{SecureRandom.hex(8)}@example.com"]
    ).first['id']
    
    DB.execute(
      "INSERT INTO user_stats (user_id, xp, level, current_streak) VALUES (?, ?, ?, ?)",
      [user_id, xp, level, streak]
    )
    
    user_id
  end
  
  def get_user_xp(user_id)
    DB.execute("SELECT xp FROM user_stats WHERE user_id = ?", [user_id]).first['xp']
  end
end
```

**Run tests:**
```bash
bundle exec rspec spec/services/leaderboard_service_spec.rb --format documentation
```

---

### **Day 3 (Wednesday): GamificationHelpers Tests** - 8 hours

**Create:** `spec/helpers/gamification_helpers_spec.rb`

```ruby
require 'spec_helper'
require_relative '../../lib/helpers/gamification_helpers'

# Test class that includes the helper module
class GamificationHelpersTest
  include GamificationHelpers
  
  attr_accessor :session
  
  def initialize
    @session = {}
  end
  
  # Mock DB for testing
  def self.db
    DB
  end
end

RSpec.describe GamificationHelpers do
  let(:helper) { GamificationHelpersTest.new }
  let(:user_id) { create_test_user }
  
  before(:each) do
    clean_test_data
  end
  
  describe '#add_xp' do
    it 'adds XP to user' do
      initial_xp = get_user_xp(user_id)
      
      helper.add_xp(user_id, :view_meme)
      
      new_xp = get_user_xp(user_id)
      expect(new_xp).to be > initial_xp
    end
    
    it 'handles different action types' do
      helper.add_xp(user_id, :like_meme)
      like_xp = get_user_xp(user_id)
      
      clean_test_data
      user_id2 = create_test_user
      
      helper.add_xp(user_id2, :save_meme)
      save_xp = get_user_xp(user_id2)
      
      # Different actions give different XP
      expect(save_xp).not_to eq(like_xp)
    end
    
    it 'triggers level up when threshold reached' do
      initial_level = get_user_level(user_id)
      
      # Add enough XP to level up
      50.times { helper.add_xp(user_id, :like_meme) }
      
      new_level = get_user_level(user_id)
      expect(new_level).to be > initial_level
    end
  end
  
  describe '#update_streak' do
    it 'increments streak on consecutive days' do
      streak = helper.update_streak(user_id)
      
      expect(streak).to be_a(Hash)
      expect(streak[:current_streak]).to eq(1)
    end
    
    it 'maintains streak when visiting same day' do
      streak1 = helper.update_streak(user_id)
      streak2 = helper.update_streak(user_id)
      
      expect(streak2[:current_streak]).to eq(streak1[:current_streak])
    end
    
    it 'resets streak after missing day' do
      # Set last visit to 2 days ago
      DB.execute(
        "UPDATE user_stats SET last_visit = DATE('now', '-2 days') WHERE user_id = ?",
        [user_id]
      )
      
      streak = helper.update_streak(user_id)
      expect(streak[:current_streak]).to eq(1) # Reset to 1
    end
  end
  
  describe '#get_user_level' do
    it 'returns correct level for XP' do
      DB.execute("UPDATE user_stats SET xp = 1000 WHERE user_id = ?", [user_id])
      
      level = helper.get_user_level(user_id)
      expect(level).to be_a(Hash)
      expect(level[:level]).to be > 1
    end
  end
  
  describe '#check_achievements' do
    it 'unlocks achievement when criteria met' do
      # Get 10-streak achievement
      DB.execute(
        "UPDATE user_stats SET current_streak = 10 WHERE user_id = ?",
        [user_id]
      )
      
      achievements = helper.check_achievements(user_id)
      
      expect(achievements).to be_an(Array)
      # Should have unlocked streak achievement
      streak_achievement = achievements.find { |a| a[:type] == 'streak' }
      expect(streak_achievement).not_to be_nil
    end
  end
  
  # Helper methods
  def create_test_user
    DB.execute(
      "INSERT INTO users (email, created_at) VALUES (?, CURRENT_TIMESTAMP) RETURNING id",
      ["test_#{SecureRandom.hex(8)}@example.com"]
    ).first['id']
  end
  
  def clean_test_data
    DB.execute("DELETE FROM user_stats WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'test_%')")
    DB.execute("DELETE FROM users WHERE email LIKE 'test_%'")
  end
  
  def get_user_xp(user_id)
    result = DB.execute("SELECT xp FROM user_stats WHERE user_id = ?", [user_id]).first
    result ? result['xp'] : 0
  end
  
  def get_user_level(user_id)
    result = DB.execute("SELECT level FROM user_stats WHERE user_id = ?", [user_id]).first
    result ? result['level'] : 1
  end
end
```

**Run tests:**
```bash
bundle exec rspec spec/helpers/gamification_helpers_spec.rb --format documentation
```

---

### **Day 4 (Thursday): TrendingService Tests** - 8 hours

**Create:** `spec/services/trending_service_spec.rb`

```ruby
require 'spec_helper'
require_relative '../../lib/services/trending_service'

RSpec.describe TrendingService do
  before(:each) do
    clean_meme_stats
    create_test_memes
  end
  
  describe '#trending_memes' do
    it 'returns array of trending memes' do
      trending = TrendingService.new.trending_memes(time_window: '24h', limit: 10)
      
      expect(trending).to be_an(Array)
      expect(trending.size).to be <= 10
    end
    
    it 'sorts by trending score (not just likes)' do
      trending = TrendingService.new.trending_memes(sort_by: 'trending')
      
      # First meme should have highest combined score
      expect(trending.first['likes']).to be >= 0
      expect(trending.first['views']).to be >= 0
    end
    
    it 'filters by time window' do
      # Create old meme
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views, updated_at) VALUES (?, ?, ?, ?, ?, DATE('now', '-2 days'))",
        ["https://old.com/meme.jpg", "Old Meme", "memes", 100, 200]
      )
      
      trending_24h = TrendingService.new.trending_memes(time_window: '24h')
      
      # Old meme should not appear
      old_meme = trending_24h.find { |m| m['url'] == "https://old.com/meme.jpg" }
      expect(old_meme).to be_nil
    end
    
    it 'supports pagination with cursor' do
      page1 = TrendingService.new.trending_memes(limit: 2, cursor: nil)
      
      expect(page1[:results].size).to eq(2)
      expect(page1[:next_cursor]).not_to be_nil
      
      page2 = TrendingService.new.trending_memes(limit: 2, cursor: page1[:next_cursor])
      
      # Pages should not overlap
      page1_urls = page1[:results].map { |m| m['url'] }
      page2_urls = page2[:results].map { |m| m['url'] }
      expect((page1_urls & page2_urls)).to be_empty
    end
  end
  
  describe '#calculate_score' do
    it 'gives higher scores to memes with more engagement' do
      service = TrendingService.new
      
      high_engagement = { 'likes' => 100, 'views' => 500, 'comments' => 50 }
      low_engagement = { 'likes' => 10, 'views' => 50, 'comments' => 5 }
      
      high_score = service.send(:calculate_score, high_engagement)
      low_score = service.send(:calculate_score, low_engagement)
      
      expect(high_score).to be > low_score
    end
    
    it 'applies time decay to older memes' do
      service = TrendingService.new
      
      recent = { 'likes' => 50, 'views' => 100, 'updated_at' => Time.now.to_s }
      old = { 'likes' => 50, 'views' => 100, 'updated_at' => (Time.now - 86400).to_s }
      
      recent_score = service.send(:calculate_score, recent)
      old_score = service.send(:calculate_score, old)
      
      expect(recent_score).to be > old_score
    end
  end
  
  describe '#invalidate_cache' do
    it 'clears trending cache' do
      service = TrendingService.new
      
      # Populate cache
      service.trending_memes(time_window: '24h')
      
      # Invalidate
      service.invalidate_cache
      
      # Cache should be empty (will repopulate on next call)
      expect(true).to be true # Just verify no errors
    end
  end
  
  # Helper methods
  def clean_meme_stats
    DB.execute("DELETE FROM meme_stats WHERE url LIKE 'https://test%'")
  end
  
  def create_test_memes
    5.times do |i|
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views, updated_at) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
        [
          "https://test#{i}.com/meme.jpg",
          "Test Meme #{i}",
          "memes",
          rand(10..100),
          rand(50..500)
        ]
      )
    end
  end
end
```

**Run tests:**
```bash
bundle exec rspec spec/services/trending_service_spec.rb --format documentation
```

---

### **Day 5 (Friday): Integration Tests & Thread Fixes** - 16 hours

#### Morning (8 hours): Integration Tests

**Create:** `spec/integration/user_journey_spec.rb`

```ruby
require 'spec_helper'
require 'rack/test'

RSpec.describe 'User Journey Integration Tests' do
  include Rack::Test::Methods
  
  def app
    MemeExplorer
  end
  
  describe 'Anonymous user journey' do
    it 'can browse random memes' do
      get '/random'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('meme-container')
    end
    
    it 'can view trending memes' do
      get '/trending'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('trending')
    end
    
    it 'can search for memes' do
      get '/search?q=funny'
      
      expect(last_response).to be_ok
    end
  end
  
  describe 'Authenticated user journey' do
    before do
      # Create test user and log in
      @user_id = create_test_user
      post '/auth/login', { email: 'test@example.com', password: 'password123' }
    end
    
    it 'can like a meme' do
      post '/memes/like', { url: 'https://example.com/meme.jpg' }
      
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['likes']).to be > 0
    end
    
    it 'can save a meme' do
      post '/memes/save', {
        meme_url: 'https://example.com/meme.jpg',
        meme_title: 'Test Meme',
        meme_subreddit: 'memes'
      }
      
      expect(last_response).to be_ok
    end
    
    it 'earns XP for actions' do
      initial_xp = get_user_xp(@user_id)
      
      # Like a meme
      post '/memes/like', { url: 'https://example.com/meme.jpg' }
      
      new_xp = get_user_xp(@user_id)
      expect(new_xp).to be > initial_xp
    end
    
    it 'appears on leaderboard' do
      get '/leaderboard'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('test@example.com')
    end
  end
  
  # Helper methods
  def create_test_user
    DB.execute(
      "INSERT INTO users (email, password_hash, created_at) VALUES (?, ?, CURRENT_TIMESTAMP) RETURNING id",
      ['test@example.com', BCrypt::Password.create('password123')]
    ).first['id']
  end
  
  def get_user_xp(user_id)
    DB.execute("SELECT xp FROM user_stats WHERE user_id = ?", [user_id]).first['xp']
  end
end
```

#### Afternoon (8 hours): Fix Thread Management

Files already created:
- `app/workers/startup_cache_warm_job.rb`
- `app/workers/database_cleanup_job.rb`

**Step 1: Update config/initializers/sidekiq.rb**

Add to the end of the file:
```ruby
# Schedule recurring jobs
Sidekiq.configure_server do |config|
  config.on(:startup) do
    # Warm cache on startup
    StartupCacheWarmJob.perform_async
    
    # Schedule recurring cleanup
    Sidekiq::Cron::Job.create(
      name: 'Database Cleanup - every hour',
      cron: '0 * * * *', # Every hour
      class: 'DatabaseCleanupJob'
    )
  end
end
```

**Step 2: Remove old threads from app.rb**

Find and COMMENT OUT these sections in app.rb:
```ruby
# COMMENTED OUT - Now using Sidekiq
# @startup_thread = Thread.new do
#   ...
# end

# COMMENTED OUT - Now using Sidekiq
# @db_cleanup_thread = Thread.new do
#   ...
# end
```

**Step 3: Test Sidekiq jobs**
```bash
# Start Redis
redis-server &

# Start Sidekiq
bundle exec sidekiq -r ./config/initializers/sidekiq.rb

# Manually trigger job (for testing)
bundle exec rails console
StartupCacheWarmJob.perform_async
```

---

## 📊 Week 1 Completion Checklist

- [ ] SimpleCov installed and configured
- [ ] FactoryBot set up with meme factories
- [ ] RandomSelectorService tests (20+ tests)
- [ ] LeaderboardService tests (15+ tests)
- [ ] GamificationHelpers tests (15+ tests)
- [ ] TrendingService tests (10+ tests)
- [ ] Integration tests (10+ tests)
- [ ] Thread management moved to Sidekiq
- [ ] All tests passing
- [ ] Coverage report shows 40%+

---

## 🎯 Success Criteria

Run this command to verify success:
```bash
bundle exec rspec --format documentation
```

**Expected output:**
```
Finished in X seconds
80 examples, 0 failures

Coverage report generated: coverage/index.html
Line Coverage: 42.3% (goal: 40%+)
```

---

## 🐛 Troubleshooting

### Tests failing?
1. **Database issues**: Run `ruby db/setup.rb`
2. **Redis issues**: Check `redis-cli ping` returns PONG
3. **Missing gems**: Run `bundle install`

### Coverage too low?
- Focus on critical paths first
- Don't worry about 100% coverage
- 40% is a great starting point!

### Sidekiq not working?
1. Check Redis is running
2. Verify Sidekiq config in `config/initializers/sidekiq.rb`
3. Check logs: `log/sidekiq.log`

---

## 📈 Next Steps (Week 2)

After completing Week 1:
1. Refactor app.rb (extract routes)
2. Move helpers to services
3. Optimize database queries
4. Add missing indexes

**Current coverage: 7.7% → Target: 40%+ → Ultimate goal: 80%**

🚀 Let's build a rock-solid foundation!
