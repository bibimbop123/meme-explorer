# Path to 99% Test Coverage - Strategic Roadmap
## Meme Explorer TDD Implementation Plan

**Current Status**: 23/125 tests passing (18.4%)  
**Target**: 99% line coverage, 95% branch coverage  
**Strategy**: Test-Driven Development (TDD)  
**Timeline**: Iterative implementation in priority order

---

## 📊 Current State (May 13, 2026)

### Completed ✅
- **ApiCacheService**: 23/23 tests passing (100%)
  - 7 production-ready methods implemented
  - Comprehensive error handling
  - Redis + memory fallback architecture

### Specifications Ready (102 tests)
- **ImageHealthService**: 35 tests
- **Trending Routes**: 20 tests  
- **Behavioral Tracking Routes**: 25 tests
- **CacheRefreshWorker**: 5 tests
- **ImageHealthWorker**: 5 tests
- **GamificationHelpers**: 10 tests
- **Remaining Files**: 30+ additional services/routes/workers

---

## 🎯 Priority-Based Implementation Strategy

### Phase 1: Critical Services (Priority: HIGH)
**Target**: 58 additional passing tests

#### 1.1 ImageHealthService (35 tests)
**Impact**: Critical - Prevents broken images from showing to users  
**Complexity**: Medium  
**Estimated Time**: 2 hours

**Methods to Implement**:
- `validate_image(url)` - URL validation
- `mark_as_broken(url)` - Add to blacklist
- `is_broken?(url)` - Check blacklist status
- `get_broken_count` - Statistics
- `get_broken_images(limit)` - List broken URLs
- `remove_from_blacklist(url)` - Cleanup
- `cleanup_old_entries(days)` - Maintenance
- `get_statistics` - Comprehensive stats

**Database Schema**:
```sql
CREATE TABLE broken_images (
  id INTEGER PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,
  failure_count INTEGER DEFAULT 1,
  last_checked_at TIMESTAMP,
  created_at TIMESTAMP
);
```

#### 1.2 GamificationHelpers (10 tests)
**Impact**: High - User engagement features  
**Complexity**: Low  
**Estimated Time**: 30 minutes

**Methods to Implement**:
- `calculate_points(action:)` - Point calculation
- `get_level(points:)` - Level determination  
- `get_badge(points:)` - Badge assignment
- `format_points(number)` - Display formatting

#### 1.3 CacheRefreshWorker (5 tests)
**Impact**: Medium - Background job reliability  
**Complexity**: Low  
**Estimated Time**: 30 minutes

**Fix Required**:
- Remove `MEME_CACHE` constant reference
- Use `ApiCacheService.set_cached_memes` instead

### Phase 2: User-Facing Features (Priority: HIGH)
**Target**: 45 additional passing tests

#### 2.1 Trending Routes (20 tests)
**Impact**: High - Main user feature  
**Complexity**: Medium  
**Estimated Time**: 1.5 hours

**Routes to Verify/Fix**:
- GET `/trending` - HTML page
- GET `/trending.json` - JSON API
- GET `/api/trending` - API endpoint

**Implementation**:
- Verify TrendingService integration
- Add proper error handling
- Implement caching strategy
- Add time period filtering

#### 2.2 Behavioral Tracking Routes (25 tests)
**Impact**: High - Analytics foundation  
**Complexity**: High  
**Estimated Time**: 2 hours

**Routes to Create**:
- POST `/api/track/view`
- POST `/api/track/like`
- POST `/api/track/share`
- POST `/api/track/skip`
- POST `/api/track/time_spent`
- GET `/api/track/stats`

**Database Integration**:
```sql
-- meme_activity_log table required
INSERT INTO meme_activity_log (
  user_id, session_id, meme_url, action, timestamp
) VALUES (?, ?, ?, ?, ?);
```

### Phase 3: Workers & Background Jobs (Priority: MEDIUM)
**Target**: 5 additional passing tests

#### 3.1 ImageHealthWorker (5 tests)
**Impact**: Medium - Automated maintenance  
**Complexity**: Low  
**Estimated Time**: 30 minutes

**Implementation**:
- Check image health periodically
- Cleanup old broken_images entries (>30 days)
- Log statistics

---

## 📈 Coverage Projections

### Milestone 1: Core Services Complete
**Tests**: 68/125 (54.4%)  
**Coverage**: ~40%  
**Timeline**: 5 hours
- ApiCacheService ✅
- ImageHealthService
- GamificationHelpers
- CacheRefreshWorker

### Milestone 2: Routes Complete
**Tests**: 113/125 (90.4%)  
**Coverage**: ~65%  
**Timeline**: +3.5 hours
- Trending Routes
- Behavioral Tracking Routes

### Milestone 3: Workers Complete
**Tests**: 118/125 (94.4%)  
**Coverage**: ~70%  
**Timeline**: +0.5 hours
- ImageHealthWorker

### Milestone 4: Additional Files
**Tests**: 600+ tests  
**Coverage**: 99%+  
**Timeline**: +20 hours
- 30+ additional services/routes/workers

---

## 🔧 Implementation Process (TDD Cycle)

### For Each Service/Route/Worker:

1. **RED**: Run existing test specs (they should fail)
   ```bash
   bundle exec rspec spec/services/[service]_spec.rb
   ```

2. **GREEN**: Implement minimum code to pass tests
   - Add methods one at a time
   - Focus on making tests pass
   - Don't over-engineer

3. **REFACTOR**: Improve code quality
   - Extract common patterns
   - Add proper error handling
   - Optimize performance

4. **VERIFY**: Run full test suite
   ```bash
   bundle exec rspec
   ```

5. **COMMIT**: Save progress
   ```bash
   git add .
   git commit -m "feat: Implement [ServiceName] with 100% test coverage"
   ```

---

## 🎯 Success Criteria

### Per Service/Route/Worker
- ✅ 100% of specification tests passing
- ✅ Comprehensive error handling
- ✅ Production-ready code quality
- ✅ Fast test execution (<1s per test)
- ✅ Documentation updated

### Overall Project
- ✅ 99% line coverage
- ✅ 95% branch coverage
- ✅ All tests passing
- ✅ No flaky tests
- ✅ Fast CI/CD pipeline (<5 minutes)

---

## 📋 Execution Checklist

### Phase 1: Critical Services
- [ ] ImageHealthService implementation
  - [ ] validate_image method
  - [ ] mark_as_broken method
  - [ ] is_broken? method
  - [ ] get_broken_count method
  - [ ] get_broken_images method
  - [ ] remove_from_blacklist method
  - [ ] cleanup_old_entries method
  - [ ] get_statistics method
  - [ ] All 35 tests passing
  
- [ ] GamificationHelpers implementation
  - [ ] calculate_points method
  - [ ] get_level method
  - [ ] get_badge method
  - [ ] format_points method
  - [ ] All 10 tests passing

- [ ] CacheRefreshWorker fix
  - [ ] Remove MEME_CACHE reference
  - [ ] Use ApiCacheService methods
  - [ ] All 5 tests passing

### Phase 2: Routes
- [ ] Trending Routes verification/fix
  - [ ] GET /trending route
  - [ ] GET /trending.json route
  - [ ] GET /api/trending route
  - [ ] All 20 tests passing

- [ ] Behavioral Tracking Routes creation
  - [ ] POST /api/track/view
  - [ ] POST /api/track/like
  - [ ] POST /api/track/share
  - [ ] POST /api/track/skip
  - [ ] POST /api/track/time_spent
  - [ ] GET /api/track/stats
  - [ ] All 25 tests passing

### Phase 3: Workers
- [ ] ImageHealthWorker implementation
  - [ ] Health check logic
  - [ ] Cleanup logic
  - [ ] Error handling
  - [ ] All 5 tests passing

---

## 🚀 Quick Start Commands

### Run specific test file
```bash
bundle exec rspec spec/services/image_health_service_spec.rb
```

### Run all passing tests
```bash
bundle exec rspec --tag ~pending
```

### Generate coverage report
```bash
COVERAGE=true bundle exec rspec
open coverage/index.html
```

### Watch mode (for development)
```bash
bundle exec guard
```

---

## 📊 Estimated Timeline

| Phase | Tests | Time | Cumulative |
|-------|-------|------|------------|
| **Completed** | 23 | ✅ | 23/125 |
| Phase 1.1 - ImageHealthService | 35 | 2h | 58/125 |
| Phase 1.2 - GamificationHelpers | 10 | 0.5h | 68/125 |
| Phase 1.3 - CacheRefreshWorker | 5 | 0.5h | 73/125 |
| Phase 2.1 - Trending Routes | 20 | 1.5h | 93/125 |
| Phase 2.2 - Behavioral Tracking | 25 | 2h | 118/125 |
| Phase 3.1 - ImageHealthWorker | 5 | 0.5h | 123/125 |
| **Subtotal** | 123 | **7h** | **~70% coverage** |
| Additional Files | 477+ | 20h | **99% coverage** |
| **TOTAL** | 600+ | **27h** | **🎯 TARGET** |

---

## 🎓 Best Practices Reminder

1. **Write Tests First** - Always create spec before implementation
2. **Small Steps** - One method at a time
3. **Fast Feedback** - Run tests frequently
4. **Refactor Often** - Keep code clean and DRY
5. **Document Changes** - Update docs with each change
6. **Commit Frequently** - Save progress incrementally
7. **Review Coverage** - Check SimpleCov reports regularly

---

## 📝 Next Action

**Start with**: ImageHealthService (highest impact, 35 tests)  
**Command**: `bundle exec rspec spec/services/image_health_service_spec.rb`  
**Expected**: 35 failures (RED phase)  
**Goal**: Implement methods to make all tests pass (GREEN phase)

---

**Document Status**: Living Roadmap  
**Last Updated**: May 13, 2026, 6:09 PM  
**Progress**: 23/125 tests passing (18.4%)  
**Next Milestone**: 68/125 tests (Phase 1 Complete)
