# Test Coverage Roadmap to 99% - May 2026

## 🎯 Goal: Achieve 99% Test Coverage + 100% Passing Tests

### Current Status (May 13, 2026)
```
✅ Tests Passing: 61/168 (36%)
❌ Tests Failing: 107/168 (64%)
📊 Coverage: ~15%
🎯 Target: 99% coverage, 100% passing
```

---

## ✅ COMPLETED TODAY

### 1. Critical Bug Fixed
- **Timezone Mismatch in Metrics** (5-hour offset)
- **File:** `routes/metrics_routes.rb`
- **Impact:** All time-period filters now show correct data
- **Status:** FIXED ✅

### 2. Metrics Test Suite Created
- **File:** `spec/routes/metrics_routes_spec.rb`
- **Tests:** 25 comprehensive test cases
- **Coverage:** All metrics endpoints tested
- **Features Tested:**
  - ✅ All time period filters (24h, 7d, 30d, all)
  - ✅ CSV export functionality
  - ✅ Top memes/subreddits filtering
  - ✅ Timezone-aware queries
  - ✅ Error handling
  - ✅ Zero-data scenarios

### 3. Comprehensive Audit Report
- **File:** `COMPREHENSIVE_CODE_AUDIT_REPORT_MAY_2026.md`
- **Contents:**
  - Full test failure analysis
  - Service coverage gaps (90.7% untested)
  - Route coverage gaps (65% untested)
  - Code consistency issues
  - Security scan results
  - 4-week roadmap to 99%

---

## 📋 IMMEDIATE ACTIONS NEEDED

### Week 1: Fix Failing Tests (Priority 1)

#### Root Causes Identified:
1. **Missing DB Tables** (35% of failures)
   - meme_activity_log
   - push_subscriptions
   - gamification_points
   - ab_experiments

2. **Session Mocking Issues** (25% of failures)
3. **Missing Helpers** (20% of failures)
4. **Hardcoded Assumptions** (10% of failures)
5. **External API Calls** (10% of failures)

#### Action Plan:
```ruby
# 1. Update spec_helper.rb to create all tables
# 2. Fix session mocking pattern
# 3. Define missing helper methods
# 4. Mock external APIs
# 5. Fix time-dependent tests
```

**Expected Result:** 168/168 tests passing ✅

---

## 📊 SERVICE TEST PRIORITIES

### HIGH PRIORITY (Week 2)
Create tests for these critical services:

1. **MemeService** (`spec/services/meme_service_spec.rb`)
   - Test random_memes_pool
   - Test calculate_humor_score
   - Test toggle_like
   - Test get_likes
   - Test search_memes
   - ~50 test cases needed

2. **TrendingService** (`spec/services/trending_service_spec.rb`)
   - Test trending algorithm
   - Test time-based trending
   - Test engagement scoring
   - ~30 test cases needed

3. **LeaderboardService** (`spec/services/leaderboard_service_spec.rb`)
   - Test score calculation
   - Test ranking logic
   - Test user stats
   - ~40 test cases needed

4. **ImageHealthService** (`spec/services/image_health_service_spec.rb`)
   - Test blacklist filtering
   - Test broken image tracking
   - Test validation logic
   - ~35 test cases needed

5. **ApiCacheService** (`spec/services/api_cache_service_spec.rb`)
   - Test cache logic
   - Test invalidation
   - Test TTL handling
   - ~25 test cases needed

**Total:** ~180 new tests → 348 total tests

---

## 🛣️ ROUTE TEST PRIORITIES

### HIGH PRIORITY (Week 3)
Create tests for these critical routes:

1. **trending_routes.rb** (`spec/routes/trending_routes_spec.rb`)
   - GET /trending
   - GET /trending.json
   - Test sorting algorithms
   - ~20 test cases

2. **seo_routes.rb** (`spec/routes/seo_routes_spec.rb`)
   - GET /sitemap.xml
   - GET /robots.txt
   - Test meta tags
   - ~15 test cases

3. **ab_testing.rb** (`spec/routes/ab_testing_routes_spec.rb`)
   - All admin endpoints
   - Test experiment logic
   - ~25 test cases

4. **algorithm_metrics.rb** (`spec/routes/algorithm_metrics_spec.rb`)
   - GET /api/algorithm/metrics
   - DELETE /api/algorithm/metrics
   - ~10 test cases

5. **behavioral_tracking.rb** (`spec/routes/behavioral_tracking_spec.rb`)
   - POST tracking endpoints
   - Test data collection
   - ~15 test cases

**Total:** ~85 new tests → 433 total tests

---

## 🎯 COVERAGE MILESTONES

### Week 1 Target: 40% Coverage
- ✅ All existing tests passing (168/168)
- ✅ Metrics tests complete
- 🎯 Fix all broken tests

### Week 2 Target: 60% Coverage  
- ✅ 5 core services tested
- ✅ ~180 new tests added
- 🎯 Total: 348 passing tests

### Week 3 Target: 80% Coverage
- ✅ 5 critical routes tested
- ✅ ~85 new tests added
- 🎯 Total: 433 passing tests

### Week 4 Target: 99% Coverage
- ✅ All remaining services tested
- ✅ All remaining routes tested
- ✅ Edge cases covered
- ✅ Integration tests added
- 🎯 Target: 600+ passing tests, 99% coverage

---

## 🔧 TOOLS & CONFIGURATION

### Update SimpleCov
```ruby
# .simplecov
SimpleCov.start do
  # Week 1
  minimum_coverage 40
  
  # Week 2  
  # minimum_coverage 60
  
  # Week 3
  # minimum_coverage 80
  
  # Week 4
  # minimum_coverage 99
  
  minimum_coverage_by_file 95
  enable_coverage :branch
  branch_coverage_minimum 95
end
```

### CI/CD Integration
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: bundle exec rspec
      - name: Check coverage
        run: |
          if [ $(cat coverage/.last_run.json | jq '.result.line') -lt 99 ]; then
            echo "Coverage below 99%"
            exit 1
          fi
```

---

## 📝 TEST TEMPLATES

### Service Test Template
```ruby
# spec/services/example_service_spec.rb
require_relative '../spec_helper'

RSpec.describe ExampleService do
  let(:service) { described_class.new }
  
  describe '#method_name' do
    context 'with valid input' do
      it 'returns expected result' do
        expect(service.method_name(valid_input)).to eq(expected_output)
      end
    end
    
    context 'with invalid input' do
      it 'raises ArgumentError' do
        expect { service.method_name(nil) }.to raise_error(ArgumentError)
      end
    end
    
    context 'edge cases' do
      it 'handles empty arrays' do
        expect(service.method_name([])).to eq([])
      end
      
      it 'handles nil values' do
        expect(service.method_name(nil: true)).to be_nil
      end
    end
  end
end
```

### Route Test Template
```ruby
# spec/routes/example_routes_spec.rb
require_relative '../spec_helper'

RSpec.describe 'Example Routes' do
  describe 'GET /endpoint' do
    context 'without authentication' do
      it 'returns 401' do
        get '/endpoint'
        expect(last_response.status).to eq(401)
      end
    end
    
    context 'with authentication' do
      before do
        @user_id = create_test_user
        login_as(@user_id)
      end
      
      it 'returns 200' do
        get '/endpoint'
        expect(last_response.status).to eq(200)
      end
      
      it 'returns valid JSON' do
        get '/endpoint'
        data = JSON.parse(last_response.body)
        expect(data).to have_key('result')
      end
    end
  end
end
```

---

## 🚀 QUICK START COMMANDS

### Run All Tests
```bash
bundle exec rspec
```

### Run Specific Test File
```bash
bundle exec rspec spec/routes/metrics_routes_spec.rb
```

### Run With Coverage
```bash
COVERAGE=true bundle exec rspec
open coverage/index.html
```

### Run Only Failing Tests
```bash
bundle exec rspec --only-failures
```

### Run Tests in Parallel (faster)
```bash
bundle exec parallel_rspec spec/
```

---

## 📈 SUCCESS METRICS

### Definition of Done
- [ ] 600+ passing tests
- [ ] 0 failing tests
- [ ] 99% line coverage
- [ ] 95% branch coverage
- [ ] 100% method coverage
- [ ] All critical paths tested
- [ ] All edge cases tested
- [ ] All security vulnerabilities tested
- [ ] Performance benchmarks established
- [ ] CI/CD enforcing coverage minimums

### Weekly Check-ins
- **Week 1 Review:** Are all existing tests passing?
- **Week 2 Review:** Are core services at 100% coverage?
- **Week 3 Review:** Are critical routes at 100% coverage?
- **Week 4 Review:** Is overall coverage at 99%+?

---

## 🎓 TESTING BEST PRACTICES

### Do's ✅
- Test one thing per test case
- Use descriptive test names
- Arrange, Act, Assert pattern
- Mock external dependencies
- Test edge cases and error conditions
- Keep tests fast (<0.1s per test)
- Use factories for test data
- Clean database between tests

### Don'ts ❌
- Don't test framework code
- Don't test third-party libraries
- Don't make tests dependent on each other
- Don't use hardcoded IDs or dates
- Don't skip error case testing
- Don't leave pending tests indefinitely
- Don't test private methods directly

---

## 📚 RESOURCES

### Documentation
- RSpec Documentation: https://rspec.info/
- SimpleCov Guide: https://github.com/simplecov-ruby/simplecov
- FactoryBot: https://github.com/thoughtbot/factory_bot

### Internal Docs
- `COMPREHENSIVE_CODE_AUDIT_REPORT_MAY_2026.md` - Full audit findings
- `spec/spec_helper.rb` - Test configuration
- `spec/factories/` - Test data factories

---

**Created:** May 13, 2026  
**Target Completion:** June 10, 2026 (4 weeks)  
**Status:** In Progress 🚀

