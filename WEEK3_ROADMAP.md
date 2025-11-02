# Week 3-4 Implementation Roadmap: Scaling Foundation

## Goal
Transform Meme Explorer from 100 → 1,000 concurrent users with enhanced reliability and performance.

---

## 1. Expand Test Coverage to 70% ✅ (Priority: HIGH)

### Current State
- 38 tests covering core endpoints
- ~55% coverage of critical user paths
- All health, auth, meme, and like paths tested

### Target: 70% Coverage (45-50 tests)
```ruby
# Need to add tests for:
spec/lib/error_handler_spec.rb        # 6 tests - Error logging system
spec/lib/helpers_spec.rb              # 8 tests - navigate_meme, toggle_like helpers
spec/models/user_spec.rb              # 5 tests - User creation, validation
spec/models/meme_stats_spec.rb        # 4 tests - Engagement tracking
spec/routes/metrics_spec.rb           # 4 tests - Analytics endpoints
spec/routes/trending_spec.rb          # 4 tests - Trending calculation
```

**Time Estimate**: 6-8 hours
**Effort**: Medium - Requires understanding helper methods and data models
**Blocker**: None

---

## 2. Integrate Sentry for Cloud Error Tracking ✅ (Priority: CRITICAL)

### Current State
- Local error logging in `ErrorHandler::Logger`
- `/errors` endpoint for admin viewing
- No cloud-based alerting

### Implementation Steps
```ruby
# 1. Add to Gemfile
gem "sentry-ruby"
gem "sentry-sinatra"

# 2. Create config/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = ENV['RACK_ENV']
  config.enabled_environments = %w[production staging]
  config.release = "meme-explorer@#{VERSION}"
end

# 3. Integrate with ErrorHandler
ErrorHandler::Logger.log(error) # logs locally
Sentry.capture_exception(error) # sends to cloud

# 4. Set up alerts in Sentry dashboard
- Alert on: 5+ errors in 5 minutes
- Alert on: New error type
- Alert on: 500% increase in error rate
```

**Time Estimate**: 2-3 hours
**Effort**: Low - Mostly configuration
**Blocker**: Need Sentry account (free tier available)

**Value**: Real-time error notifications, trend analysis, production visibility

---

## 3. PostgreSQL Migration (Priority: CRITICAL) ✅

### Current State
- SQLite for persistence
- Single-writer limitation
- ~100 concurrent user ceiling

### Target: PostgreSQL
- 10x concurrency improvement
- Multi-writer support
- Connection pooling with PgBouncer

### Migration Plan
```bash
# Phase 1: Development (Week 3)
1. Install PostgreSQL locally
2. Create migration from SQLite → PostgreSQL
3. Run tests against PostgreSQL
4. Verify data integrity

# Phase 2: Staging (Week 4)  
1. Provision PostgreSQL on Render
2. Migrate production data
3. Run parallel testing (SQLite → PG fallback)
4. Performance baseline

# Phase 3: Production (Week 4.5)
1. DNS cutover
2. Monitor connection pool
3. Rollback plan ready
```

**Time Estimate**: 12-16 hours
**Effort**: High - Requires deployment coordination
**Blocker**: Needs production maintenance window

---

## 4. Multi-Worker Deployment ✅ (Priority: HIGH)

### Current State
- Single Puma worker
- ~100 req/s capacity
- Full utilization = queue buildup

### Target: 3 Puma Workers + Load Balancer
```yaml
# config/puma.rb
workers Integer(ENV.fetch("WEB_CONCURRENCY", 3))
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))
threads threads_count, threads_count

# Nginx config (reverse proxy)
upstream puma {
  server 127.0.0.1:3000;
  server 127.0.0.1:3001;
  server 127.0.0.1:3002;
}

server {
  listen 80;
  location / {
    proxy_pass http://puma;
  }
}
```

**Time Estimate**: 4-6 hours
**Effort**: Medium - Requires load balancer setup
**Blocker**: None

**Result**: 3x throughput improvement, better resource utilization

---

## 5. Image CDN Deployment ✅ (Priority: MEDIUM)

### Current State
- Direct image serving from `/public/images`
- No caching headers
- Hotlinking Reddit/Imgur images

### Target: Cloudflare CDN + Cache Config
```ruby
# app.rb
# Set cache headers for meme images
get "/random.json" do
  headers "Cache-Control" => "public, max-age=3600"
  # ... meme endpoint
end

# For static images
set :static_cache_control, [:public, {:max_age => 86400}]

# In production:
# 1. Add Cloudflare to DNS
# 2. Set Page Rule: Cache Level = Cache Everything
# 3. Enable Always Online for fallback
```

**Time Estimate**: 3-4 hours
**Effort**: Low - Mostly configuration
**Blocker**: None

**Result**: 5x faster image delivery, 90% cache hit rate

---

## Implementation Order (Recommended)

### Week 3 (Days 1-2)
1. ✅ **Sentry Integration** (2-3 hrs) - QUICK WIN
2. ✅ **Expand Test Coverage** (4-6 hrs) - BUILD CONFIDENCE
3. ⏳ **Start PostgreSQL Migration** (4 hrs planning) - BLOCKING ITEM

### Week 3 (Days 3-5)  
1. ✅ **PostgreSQL to Staging** (8 hrs) - MAJOR DEPLOYMENT
2. ✅ **Multi-Worker Config** (4 hrs) - QUICK SCALING
3. ✅ **Cloudflare Setup** (2 hrs) - EASY WIN

### Week 4 (Days 1-3)
1. ✅ **PostgreSQL to Production** (4 hrs with rollback ready)
2. ✅ **Load Testing** (2 hrs verify 3x throughput)
3. ✅ **CDN Cache Tuning** (1 hr)

### Week 4 (Days 4-5)
1. ✅ **Performance Monitoring** (2 hrs - verify improvements)
2. ✅ **Documentation** (1 hr)
3. ✅ **Planning Week 5-6** (Mobile-First)

---

## Success Metrics

| Metric | Current | Target | Week |
|--------|---------|--------|------|
| **Concurrent Users** | 100 | 1,000 | 4 |
| **Error Visibility** | Local only | Real-time alerts | 3 |
| **Test Coverage** | 55% | 70% | 3 |
| **Request Latency p95** | ~500ms | <200ms | 4 |
| **Image Load Time** | 2-3s | <500ms | 4 |
| **Uptime Monitoring** | Manual | Automated | 3 |

---

## Risks & Mitigation

| Risk | Mitigation | Impact |
|------|-----------|--------|
| PostgreSQL migration fails | Dual-write testing, rollback plan | CRITICAL |
| Load balancer misconfiguration | Test with traffic generator | HIGH |
| Cache invalidation issues | Manual cache purge procedure | MEDIUM |
| Sentry quota exceeded | Set sampling for high-volume errors | LOW |

---

## Dependencies

- ✅ RSpec test framework (ready)
- ✅ GitHub Actions CI/CD (ready)
- ✅ Error tracking foundation (ready)
- ⏳ PostgreSQL instance (Week 3)
- ⏳ Sentry account (Week 3, free tier)
- ⏳ Cloudflare account (Week 4, free tier)

---

## Deliverables by End of Week 4

1. **Production PostgreSQL** with 10x concurrency
2. **Sentry Integration** with alerting configured
3. **70% Test Coverage** with helper method tests
4. **Multi-Worker Deployment** with load balancing
5. **CDN-Cached Images** with 5x faster delivery
6. **1,000 concurrent user** capacity verified

---

**Next Action**: Start with Sentry integration (highest ROI, lowest effort)
