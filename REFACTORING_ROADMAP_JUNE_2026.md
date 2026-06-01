# 🗺️ Refactoring Roadmap - Meme Explorer
**Target:** Improve code quality from 72/100 → 88/100  
**Timeline:** 4-6 weeks  
**Last Updated:** June 1, 2026

---

## 🎯 Goals

1. **Reduce app.rb** from 2,719 lines → <200 lines
2. **Consolidate services** from 40+ → ~20
3. **Remove manual threads**, use Sidekiq exclusively
4. **Add ORM layer** (Sequel)
5. **Implement repository pattern**
6. **Standardize error handling**
7. **Optimize performance** (remove DB queries from before filter)
8. **Clean up documentation** (100+ files → 5 key files)

---

## 📅 Week-by-Week Plan

### Week 1: Critical Architecture Fixes (June 1-7)

#### Day 1-2: Extract Routes from app.rb ⏰ **START HERE**
- [ ] Create `routes/random_routes.rb` - Extract /random, /random.json
- [ ] Create `routes/user_routes.rb` - Extract /login, /signup, /logout
- [ ] Create `routes/gamification_routes.rb` - Extract /leaderboard routes
- [ ] Update `config.ru` to mount new route modules
- [ ] **Success Criteria:** app.rb reduced by ~500 lines

#### Day 3-4: Consolidate Random Selector Services
- [ ] Audit all random selection services:
  - `RandomSelectorService`
  - `RandomSelectorServiceV2`
  - `EnhancedRandomSelector`
  - `DiversityEngineService`
  - `SmartPoolsService`
- [ ] Create unified `MemeSelectionService` with strategy pattern
- [ ] Update all callers to use new service
- [ ] Delete old service files
- [ ] **Success Criteria:** 5 services → 1 service

#### Day 5: Replace Manual Threads with Sidekiq
- [ ] Create `CachePreloadWorker` (move from Thread in app.rb lines 187-265)
- [ ] Update `DatabaseCleanupWorker` to run on schedule
- [ ] Remove `@startup_thread` and `@db_cleanup_thread` from app.rb
- [ ] Add workers to `config/sidekiq.yml` schedule
- [ ] Test workers run correctly
- [ ] **Success Criteria:** Zero manual threads in app.rb

---

### Week 2: Repository Pattern & ORM (June 8-14)

#### Day 6-7: Add Sequel ORM
- [ ] Add to Gemfile: `gem 'sequel'`, `gem 'sequel-postgres'`
- [ ] Run `bundle install`
- [ ] Create `config/database.rb` with Sequel setup
- [ ] Configure for both PostgreSQL (production) and SQLite (dev)
- [ ] Test database connection

#### Day 8-10: Create Repository Layer
- [ ] Create `lib/repositories/base_repository.rb`
- [ ] Create `lib/repositories/meme_repository.rb`
  - Methods: `find_by_url`, `increment_views`, `top_memes`, `trending`
- [ ] Create `lib/repositories/user_repository.rb`
  - Methods: `find_by_id`, `find_by_email`, `create`, `update`
- [ ] Create `lib/repositories/leaderboard_repository.rb`
  - Methods: `weekly_leaders`, `user_rank`, `update_score`
- [ ] **Success Criteria:** All DB.execute calls in repositories

#### Day 11-12: Create Sequel Models
- [ ] Create `lib/models/meme.rb` (Sequel::Model)
- [ ] Create `lib/models/user.rb` (Sequel::Model)
- [ ] Create `lib/models/meme_stat.rb` (Sequel::Model)
- [ ] Update repositories to use models
- [ ] **Success Criteria:** Clean ORM layer with models

---

### Week 3: Extract Remaining Logic from app.rb (June 15-21)

#### Day 13-14: Extract Helper Methods
- [ ] Create `lib/helpers/meme_pool_helper.rb`
  - Move: `random_memes_pool`, `get_intelligent_pool`, `get_time_based_pools`
- [ ] Create `lib/helpers/meme_validation_helper.rb`
  - Move: `is_valid_meme?`, `has_valid_media?`, `is_image_accessible?`
- [ ] Create `lib/helpers/meme_navigation_helper.rb`
  - Move: `navigate_meme_unified`, `apply_user_preferences`
- [ ] Update app.rb to use helpers
- [ ] **Success Criteria:** app.rb < 1500 lines

#### Day 15-16: Extract Configuration
- [ ] Create `config/constants.rb` - Move all CONSTANTS
- [ ] Create `config/reddit.rb` - OAuth config
- [ ] Create `config/cache.rb` - Cache config
- [ ] Create `config/gamification.rb` - Gamification rules
- [ ] Update app.rb to require config files
- [ ] **Success Criteria:** app.rb < 1000 lines

#### Day 17-18: Extract Remaining Routes
- [ ] Create `routes/api_routes.rb` - /api/* endpoints
- [ ] Create `routes/admin_dashboard_routes.rb` - Consolidate admin routes
- [ ] Move before/after filters to `lib/middleware/request_lifecycle.rb`
- [ ] **Success Criteria:** app.rb < 500 lines

#### Day 19: Final app.rb Cleanup
- [ ] Move static methods to appropriate services
- [ ] Remove dead code
- [ ] Add clear section comments
- [ ] **Success Criteria:** app.rb < 200 lines ✅

---

### Week 4: Performance & Error Handling (June 22-28)

#### Day 20-21: Optimize Before Filter
- [ ] Remove DB queries from before filter
- [ ] Implement lazy loading for `current_user`
- [ ] Cache user data in Redis (5-minute TTL)
- [ ] Skip expensive operations for static assets
- [ ] **Success Criteria:** Before filter < 20 lines, no DB queries

#### Day 22-23: Standardize Error Handling
- [ ] Update `lib/concerns/error_handler.rb` with comprehensive handling
- [ ] Define custom error classes:
  - `ValidationError`
  - `NotFoundError`
  - `AuthenticationError`
  - `RateLimitError`
- [ ] Apply error handler to all routes
- [ ] Add structured logging
- [ ] **Success Criteria:** Consistent error responses across app

#### Day 24-25: Performance Optimizations
- [ ] Add Redis caching to expensive queries
- [ ] Implement database query result caching
- [ ] Add database connection pooling
- [ ] Optimize N+1 queries (use Sequel eager loading)
- [ ] **Success Criteria:** Average response time < 150ms

#### Day 26: Documentation Cleanup
- [ ] Create `docs/archive/` directory
- [ ] Move all old fix/audit docs to archive
- [ ] Keep only:
  - `README.md`
  - `API_DOCS.md`
  - `DEPLOYMENT.md`
  - `REFACTORING_ROADMAP_JUNE_2026.md` (this file)
  - `COMPREHENSIVE_CODE_AUDIT_JUNE_2026.md`
- [ ] Update README with current architecture
- [ ] **Success Criteria:** < 10 markdown files in root

---

### Week 5: Testing & Quality (June 29 - July 5)

#### Day 27-28: Improve Test Coverage
- [ ] Add repository specs
- [ ] Add model specs
- [ ] Add integration tests for critical flows
- [ ] Add E2E tests with Rack::Test
- [ ] **Success Criteria:** Test coverage > 85%

#### Day 29-30: Code Quality
- [ ] Run RuboCop and fix violations
- [ ] Run Brakeman (security scanner)
- [ ] Update dependencies (run `bundle update`)
- [ ] Fix deprecation warnings
- [ ] **Success Criteria:** Zero RuboCop offenses, all tests green

#### Day 31: Deploy & Verify
- [ ] Deploy to staging environment
- [ ] Run smoke tests
- [ ] Monitor error rates
- [ ] Check performance metrics
- [ ] **Success Criteria:** Staging stable, metrics improved

---

### Week 6: Final Polish & Production (July 6-12)

#### Day 32-33: Final Optimizations
- [ ] Profile slow endpoints
- [ ] Add database indexes for missing queries
- [ ] Optimize frontend assets (minify, compress)
- [ ] Implement CDN for static assets
- [ ] **Success Criteria:** All endpoints < 200ms

#### Day 34: Production Deployment
- [ ] Create deployment checklist
- [ ] Run database migrations
- [ ] Deploy to production
- [ ] Monitor closely for 24 hours
- [ ] **Success Criteria:** Zero downtime deployment

#### Day 35-36: Post-Deployment
- [ ] Monitor error rates
- [ ] Check performance dashboards
- [ ] Verify all features working
- [ ] Collect user feedback
- [ ] **Success Criteria:** Stable production, no regressions

---

## 📊 Success Metrics

### Code Quality Metrics

| Metric | Before | Target | After |
|--------|--------|--------|-------|
| Overall Score | 72/100 | 88/100 | TBD |
| app.rb Lines | 2,719 | <200 | TBD |
| Service Count | 40+ | ~20 | TBD |
| Manual Threads | 2 | 0 | TBD |
| Documentation Files | 100+ | <10 | TBD |
| Test Coverage | ~75% | 90%+ | TBD |
| ORM | None | Sequel | TBD |
| Repository Pattern | No | Yes | TBD |

### Performance Metrics

| Metric | Before | Target | After |
|--------|--------|--------|-------|
| Avg Response Time | ~250ms | <150ms | TBD |
| P95 Response Time | ~500ms | <300ms | TBD |
| DB Queries/Request | 5-8 | <3 | TBD |
| Before Filter Time | ~50ms | <10ms | TBD |
| Cache Hit Rate | ~60% | >85% | TBD |

---

## 🚨 Risk Mitigation

### High-Risk Changes
1. **Extracting routes** - Risk: Break existing functionality
   - Mitigation: Keep comprehensive test suite, test each extraction
   
2. **Adding ORM** - Risk: Performance regression
   - Mitigation: Benchmark before/after, gradual rollout

3. **Removing threads** - Risk: Cache not warming up
   - Mitigation: Monitor Sidekiq workers, add alerts

### Rollback Plan
- Keep feature flags for major changes
- Maintain old code in git history
- Document rollback procedures
- Monitor error rates closely

---

## 🔄 Daily Checklist

Each day during refactoring:

- [ ] Run full test suite before changes
- [ ] Make incremental changes (small commits)
- [ ] Run tests after each change
- [ ] Update this roadmap with progress
- [ ] Document any issues/blockers
- [ ] Commit and push changes
- [ ] Review code changes before EOD

---

## 📝 Notes & Blockers

### Week 1 Notes
- 

### Week 2 Notes
-

### Week 3 Notes
-

### Week 4 Notes
-

### Week 5 Notes
-

### Week 6 Notes
-

---

## 🎯 Quick Wins (Do First!)

These can be done immediately for quick improvement:

### Quick Win #1: Remove Unused Services (30 minutes)
```bash
# Identify unused services
grep -r "RandomSelectorServiceV2" .
# If no results (except the file itself), it's unused - delete it!
```

### Quick Win #2: Extract One Route File (2 hours)
```bash
# Create routes/health_routes.rb
# Move health check routes from app.rb
# Test thoroughly
# This teaches the pattern for extracting remaining routes
```

### Quick Win #3: Add Constants File (1 hour)
```bash
# Create config/constants.rb
# Move POPULAR_SUBREDDITS, TIER_CONFIG, etc.
# Require in app.rb
# Instant ~50 line reduction
```

### Quick Win #4: Archive Old Docs (15 minutes)
```bash
mkdir -p docs/archive
mv *_MAY_2026*.md docs/archive/
mv *_FIX*.md docs/archive/
# Keep only current docs in root
```

---

## 📚 Resources

### Learning Resources
- [Sequel ORM Documentation](https://sequel.jeremyevans.net/)
- [Repository Pattern in Ruby](https://medium.com/@blazejkosmowski/repository-pattern-in-ruby-on-rails-a5c60c7f0a7b)
- [Sidekiq Best Practices](https://github.com/mperham/sidekiq/wiki/Best-Practices)
- [Sinatra Modular App Structure](http://sinatrarb.com/intro.html#Modular%20vs.%20Classic%20Style)

### Tools
- **RuboCop** - Code linter
- **Brakeman** - Security scanner
- **SimpleCov** - Test coverage
- **Bullet** - N+1 query detector (for Sequel)
- **Rack Mini Profiler** - Performance profiling

---

## ✅ Completion Criteria

This refactoring is COMPLETE when:

1. ✅ app.rb is < 200 lines
2. ✅ All duplicate services removed
3. ✅ Repository pattern implemented
4. ✅ Sequel ORM integrated
5. ✅ No manual threads (Sidekiq only)
6. ✅ Error handling standardized
7. ✅ Test coverage > 90%
8. ✅ Documentation cleaned up (< 10 files)
9. ✅ Performance improved (avg < 150ms)
10. ✅ Zero production errors for 48 hours

**Final Score Target: 88/100 (B+)**

---

## 🎬 Getting Started

**Start NOW with Quick Win #4** (15 minutes):

```bash
cd /Users/brian/DiscoveryPartnersInstitute/meme-explorer

# Archive old documentation
mkdir -p docs/archive
mv COMPREHENSIVE_CODE_AUDIT_MAY_2026*.md docs/archive/
mv *_FIX_*.md docs/archive/
mv *_DEBUG*.md docs/archive/
mv *_CRITIQUE*.md docs/archive/
mv PHASE*_COMPLETE*.md docs/archive/

# You'll immediately feel better with a cleaner root directory!
```

Then continue with Quick Win #3 (constants extraction) tomorrow.

**Remember:** Small, incremental changes. Test after each change. Commit often.

---

*This roadmap is a living document. Update daily with progress and learnings.*
