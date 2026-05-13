# Week 1 Execution Guide - Fix All Failing Tests

## ✅ Phase 1 Complete (Just Completed)

### What We Fixed
1. ✅ **Metrics timezone bug** - routes/metrics_routes.rb
2. ✅ **Test infrastructure** - spec/spec_helper.rb
   - Fixed app reference (MemeExplorer → MemeExplorer::App)
   - Added session helpers
   - Added create_test_user helper
3. ✅ **Comprehensive metrics tests** - spec/routes/metrics_routes_spec.rb (25 tests)
4. ✅ **Full audit documentation** - 4 comprehensive docs created

---

## 🎯 Week 1 Goal: 100% Tests Passing

**Current Status:** 61/168 passing (36%)  
**Target:** 168/168 passing (100%)  
**Failures to Fix:** 107

---

## 📋 Day-by-Day Breakdown

### Day 1: Fix Skipped Tests & Update Test Data (2-3 hours)

#### Task 1.1: Remove Skip from Metrics Test
The `get_user_saved_memes_count` helper ALREADY EXISTS in app.rb!

**File:** `spec/routes/metrics_routes_spec.rb`

**Action:** Remove the skip statement:
```ruby
# BEFORE (line ~230):
skip "Requires get_user_saved_memes_count helper implementation"

# AFTER: Delete that line completely
```

#### Task 1.2: Run Tests to Get Current Failure Count
```bash
bundle exec rspec --format documentation > test_output.txt 2>&1
```

Review the output to categorize remaining failures.

---

### Day 2: Fix Session/Authentication Failures (3-4 hours)

Many tests fail because they're trying to set sessions incorrectly.

#### Common Pattern to Fix:
```ruby
# ❌ WRONG - This doesn't work in tests
session[:user_id] = user_id

# ✅ CORRECT - Use the helper we added
set_session(user_id: user_id)
```

#### Files to Check:
- `spec/routes/admin_routes_spec.rb` - Multiple session issues
- `spec/routes/profile_routes_spec.rb` - Session management
- `spec/routes/auth_spec.rb` - Authentication flows

#### Fix Template:
```ruby
# In before blocks or test setup:
it "does something as logged in user" do
  user_id = create_test_user('user@test.com', 'pass123', false)
  set_session(user_id: user_id)
  
  get '/some-route'
  expect(last_response.status).to eq(200)
end
```

---

### Day 3: Mock External API Calls (2-3 hours)

Tests are failing because they're trying to make real HTTP requests to Reddit.

#### Task 3.1: Add WebMock Gem
**File:** `Gemfile`

```ruby
group :test do
  gem 'rspec'
  gem 'rack-test'
  gem 'webmock'  # Add this
  gem 'simplecov', require: false
end
```

Then run: `bundle install`

#### Task 3.2: Configure WebMock
**File:** `spec/spec_helper.rb`

Add after other requires:
```ruby
require 'webmock/rspec'

# Configure WebMock
WebMock.disable_net_connect!(allow_localhost: true)
```

#### Task 3.3: Mock Reddit API Calls
**File:** `spec/spec_helper.rb`

Add to RSpec.configure block:
```ruby
config.before(:each) do
  # Mock Reddit OAuth
  stub_request(:post, "https://www.reddit.com/api/v1/access_token")
    .to_return(status: 200, body: {access_token: "test_token", token_type: "bearer", expires_in: 3600}.to_json)
  
  # Mock Reddit API calls
  stub_request(:get, /oauth\.reddit\.com/)
    .to_return(status: 200, body: {data: {children: []}}.to_json)
end
```

---

### Day 4: Fix Database-Related Failures (2-3 hours)

Some tests fail because tables don't exist in the test environment.

#### Task 4.1: Create Test Database Setup Script
**File:** `spec/support/database_helper.rb` (create this file)

```ruby
module DatabaseHelper
  def setup_test_tables
    # Push subscriptions table
    DB.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS push_subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        endpoint TEXT NOT NULL,
        p256dh TEXT NOT NULL,
        auth TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    SQL
    
    # Add other tables as needed
  end
  
  def teardown_test_tables
    DB.execute("DROP TABLE IF EXISTS push_subscriptions")
    # Drop other test tables
  end
end
```

#### Task 4.2: Use Database Helper
**File:** `spec/spec_helper.rb`

```ruby
require_relative 'support/database_helper'

RSpec.configure do |config|
  include DatabaseHelper
  
  config.before(:suite) do
    setup_test_tables
  end
  
  config.after(:suite) do
    teardown_test_tables
  end
end
```

---

### Day 5: Fix Time-Dependent Tests (1-2 hours)

Some tests fail because they depend on specific times or dates.

#### Task 5.1: Use Timecop for Time Testing
**Gemfile:**
```ruby
group :test do
  gem 'timecop'  # Add this
end
```

#### Task 5.2: Fix Time-Dependent Assertions
**Example:**
```ruby
# ❌ BAD - Flaky test
expect(result[:timestamp]).to eq(Time.now.iso8601)

# ✅ GOOD - Stable test
Timecop.freeze(Time.utc(2026, 5, 13, 12, 0, 0)) do
  result = some_method()
  expect(result[:timestamp]).to eq("2026-05-13T12:00:00Z")
end
```

---

## 🔧 Quick Wins - Easy Fixes

### Fix 1: Update Metrics Test
```bash
# Open the file
code spec/routes/metrics_routes_spec.rb

# Find line ~230 and delete:
skip "Requires get_user_saved_memes_count helper implementation"
```

### Fix 2: Add Missing Requires to spec_helper.rb
```ruby
require 'json'
require 'bcrypt'
```

### Fix 3: Ensure Database Cleanup
Verify spec_helper.rb has proper cleanup (already done in Phase 1).

---

## 📊 Progress Tracking

### Run Tests and Check Progress
```bash
# Run all tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/routes/metrics_routes_spec.rb

# Run with detailed output
bundle exec rspec --format documentation

# Save output to file
bundle exec rspec --format documentation > test_results.txt 2>&1
```

### Check Test Count
```bash
# Count passing vs failing
bundle exec rspec | grep "examples"
```

### Track Daily Progress
| Day | Passing | Failing | % Pass |
|-----|---------|---------|--------|
| Start | 61 | 107 | 36% |
| Day 1 | ___ | ___ | ___% |
| Day 2 | ___ | ___ | ___% |
| Day 3 | ___ | ___ | ___% |
| Day 4 | ___ | ___ | ___% |
| Day 5 | 168 | 0 | 100% ✅ |

---

## 🚨 Common Test Failure Patterns

### Pattern 1: NoMethodError - undefined method 'call'
**Cause:** App not defined correctly  
**Fix:** Already fixed in spec_helper.rb ✅

### Pattern 2: NameError - undefined local variable 'session'
**Cause:** Session not available in test  
**Fix:** Use `set_session(hash)` helper ✅

### Pattern 3: SQLite3::SQLException - no such table
**Cause:** Table doesn't exist in test DB  
**Fix:** Add to database setup in spec_helper.rb

### Pattern 4: WebMock::NetConnectNotAllowedError
**Cause:** Real HTTP request during test  
**Fix:** Add stub_request for that endpoint

### Pattern 5: Test::Unit::AssertionFailedError - times don't match
**Cause:** Time-dependent assertion  
**Fix:** Use Timecop.freeze

---

## 📝 Debugging Checklist

When a test fails, ask:

1. **Is it a setup issue?**
   - [ ] Database tables created?
   - [ ] Test data properly inserted?
   - [ ] Session/auth properly mocked?

2. **Is it an external dependency?**
   - [ ] HTTP calls stubbed?
   - [ ] Redis mocked if needed?
   - [ ] File system mocked if needed?

3. **Is it a timing issue?**
   - [ ] Time-dependent code using Timecop?
   - [ ] Sleep statements removed?
   - [ ] Async operations handled?

4. **Is it an assertion issue?**
   - [ ] Expected value correct?
   - [ ] Matcher appropriate (eq vs match, etc.)?
   - [ ] Data types match?

---

## 🎯 Success Criteria

### Week 1 Complete When:
- [ ] All 168 tests passing
- [ ] No skipped tests
- [ ] No pending tests
- [ ] Test suite runs in < 30 seconds
- [ ] All mocks/stubs properly configured
- [ ] Database cleanup working

### Deliverables:
1. Updated spec files with fixes
2. webmock configuration
3. Database test helpers
4. Test results showing 168/168 passing
5. Summary document of fixes made

---

## 💡 Tips for Success

### Tip 1: Fix in Batches
Don't try to fix all 107 at once. Fix by category:
1. Skipped tests (1-2)
2. Session issues (~30)
3. API mocking (~40)
4. Database issues (~20)
5. Time issues (~10)
6. Misc (~5)

### Tip 2: Run Specific Files
```bash
# Much faster than running all tests
bundle exec rspec spec/routes/admin_routes_spec.rb
```

### Tip 3: Use --fail-fast
```bash
# Stop on first failure to debug easier
bundle exec rspec --fail-fast
```

### Tip 4: Check Existing Tests
Look at passing tests for patterns:
```bash
# See what's working
bundle exec rspec spec/services/random_selector_service_spec.rb
```

### Tip 5: Git Commit Often
```bash
git commit -m "Fix session mocking in admin routes tests"
git commit -m "Add webmock for Reddit API calls"
```

---

## 📚 Reference Files

### Created in Phase 1:
- `COMPREHENSIVE_CODE_AUDIT_REPORT_MAY_2026.md` - Full audit
- `TEST_COVERAGE_ROADMAP_2026.md` - 4-week plan
- `AUDIT_PHASE1_COMPLETE.md` - Phase 1 summary
- `spec/routes/metrics_routes_spec.rb` - Metrics tests
- `WEEK1_EXECUTION_GUIDE.md` - This file

### Key Files to Modify:
- `spec/spec_helper.rb` - Test configuration
- `Gemfile` - Add test dependencies
- Individual spec files - Fix specific tests

---

## 🎉 Next Steps After Week 1

Once all tests pass, proceed to Week 2:
- **Week 2:** Core Service Tests (MemeService, TrendingService, etc.)
- **Week 3:** Route Coverage (trending, SEO, etc.)
- **Week 4:** Edge Cases & 99% Coverage

---

**Week 1 Start:** May 13, 2026  
**Week 1 Target End:** May 20, 2026  
**Goal:** 168/168 tests passing (100%)

Good luck! 🚀
