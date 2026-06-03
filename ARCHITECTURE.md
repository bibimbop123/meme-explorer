# 🏗️ MEME EXPLORER - SYSTEM ARCHITECTURE

**Last Updated:** June 3, 2026  
**Version:** 2.0 (Post Phase 1 Stabilization)

---

## 📊 OVERVIEW

Meme Explorer is a Ruby/Sinatra application for discovering and sharing memes from Reddit. The architecture follows a service-oriented design with background job processing, caching layers, and PostgreSQL persistence.

### Tech Stack
- **Runtime:** Ruby 3.2.1
- **Framework:** Sinatra 4.0
- **Database:** PostgreSQL (production), SQLite (development)
- **Cache:** Redis
- **Jobs:** Sidekiq with sidekiq-scheduler
- **Server:** Puma
- **Monitoring:** Sentry, custom health checks

---

## 🎯 CORE ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────┐
│                      CLIENT LAYER                            │
│  Browser ────► Rack Middleware ────► Sinatra Routes         │
└────────────┬────────────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────────────┐
│                   APPLICATION LAYER                          │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Routes     │  │   Helpers    │  │  Controllers │     │
│  │  /random     │  │ Gamification │  │   (Future)   │     │
│  │  /trending   │  │  Validation  │  │              │     │
│  │  /search     │  │   CDN/SEO    │  │              │     │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘     │
│         │                  │                                │
│         └──────────┬───────┘                                │
│                    │                                        │
│         ┌──────────▼────────────┐                          │
│         │   SERVICE LAYER (55)   │                          │
│         │                        │                          │
│         │  MemeService           │                          │
│         │  TrendingService       │                          │
│         │  AuthService           │                          │
│         │  LeaderboardService    │                          │
│         │  RedisService          │                          │
│         │  ... (50 more)         │                          │
│         └──────────┬─────────────┘                          │
└────────────────────┼──────────────────────────────────────

│
┌────────────────────▼──────────────────────────────────────┐
│                  PERSISTENCE LAYER                         │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  PostgreSQL  │  │    Redis     │  │  Reddit API  │   │
│  │              │  │              │  │              │   │
│  │ Users        │  │ Cache        │  │ Memes        │   │
│  │ Memes Stats  │  │ Sessions     │  │ Subreddits   │   │
│  │ Leaderboard  │  │ Rate Limits  │  │              │   │
│  │ Saved Memes  │  │ Active Users │  │              │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└────────────────────────────────────────────────────────────┘
```

---

## 📁 DIRECTORY STRUCTURE

```
meme-explorer/
├── app.rb                    # Main Sinatra application (2,644 lines - TO REFACTOR)
├── config/                   # Configuration files
│   ├── application.rb        # App config
│   ├── app_constants.rb      # Constants
│   ├── sidekiq.yml          # Job scheduling
│   └── initializers/        # Load order
├── routes/                   # Modular routes
│   ├── auth.rb              # Authentication
│   ├── memes.rb             # Meme endpoints
│   ├── trending_routes.rb   # Trending
│   └── ... (15 more)
├── lib/
│   ├── services/            # Business logic (55 services)
│   │   ├── meme_service.rb
│   │   ├── auth_service.rb
│   │   ├── redis_service.rb
│   │   └── ...
│   ├── helpers/             # View helpers
│   ├── concerns/            # Mixins
│   ├── middleware/          # Custom middleware
│   └── models/              # Data models (minimal)
├── app/workers/             # Sidekiq background jobs
│   ├── database_cleanup_worker.rb
│   ├── cache_refresh_worker.rb
│   └── ... (8 workers)
├── db/
│   ├── setup.rb             # Database connection
│   └── migrations/          # Schema migrations
├── spec/                    # RSpec tests (32 files)
└── public/                  # Static assets
```

---

## 🔄 REQUEST LIFECYCLE

### 1. HTTP Request Arrives
```ruby
Client → Puma → Rack::Attack (rate limiting)
                → Rack::CSRF (security)
                → RequestIdMiddleware (tracing)
                → Sinatra Router
```

### 2. Route Processing
```ruby
Route Handler → Helper Methods → Service Layer → Database/Cache
```

### 3. Response Generation
```ruby
Service Response → ERB Template → HTML Response → Client
```

### 4. Async Processing (Background)
```ruby
Sidekiq Workers (every X minutes):
- CacheRefreshWorker (30 min)
- DatabaseCleanupWorker (hourly)
- LeaderboardCalculationWorker (hourly)
- ImageHealthWorker (30 min)
```

---

## 💾 DATA FLOW

### Meme Discovery Flow
```
1. User hits /random
2. Check session history (avoid repeats)
3. Query meme pool:
   - 70% from trending (high engagement)
   - 20% from fresh (< 48 hours)
   - 10% from exploration (random)
4. Apply user preferences (if logged in)
5. Track view in meme_stats
6. Return meme data + metadata
```

### Caching Strategy
```
Layer 1: Redis (5-30 min TTL)
  - Meme lists
  - Trending data
  - Like counts
  
Layer 2: Memory Cache (Thread-safe)
  - Session data
  - Recently accessed memes
  
Layer 3: Database
  - Source of truth
  - Batch operations
```

---

## 🔧 KEY SERVICES

### MemeService
Handles all meme-related operations:
- Fetching from Reddit API
- Filtering and validation
- Stat tracking

### TrendingService  
Calculates trending memes using:
- Engagement score = (likes × 2) + views
- Time decay factor
- Subreddit diversity

### LeaderboardService
Manages gamification:
- Weekly/monthly/all-time rankings
- XP calculation
- Streak tracking

### RedisService
Centralized cache management:
- Connection pooling
- Automatic fallback
- TTL management

---

## 🔒 SECURITY LAYERS

1. **Input Validation**
   - InputSanitizer module
   - Validators for all user input
   
2. **CSRF Protection**
   - Rack::CSRF middleware
   - Token validation on POST/PUT/DELETE

3. **Rate Limiting**
   - Rack::Attack (60 req/min per IP)
   - Redis-backed

4. **Session Security**
   - Secure cookies
   - Configurable expiration
   - Session secret rotation

5. **SQL Injection Prevention**
   - Parameterized queries
   - Input sanitization

---

## 📈 SCALING CONSIDERATIONS

### Current Capacity
- **Concurrent Users:** ~500
- **Requests/sec:** ~50
- **Database Connections:** 25 pool
- **Redis Connections:** 40 pool

### Bottlenecks
1. **app.rb size** (2,644 lines) - needs modularization
2. **N+1 queries** in some routes - needs batch loading
3. **Reddit API rate limits** - using adaptive rate limiter

### Future Improvements
- Extract controllers from app.rb
- Implement Sequel ORM
- Add read replicas for PostgreSQL
- CDN for static assets
- Horizontal scaling with load balancer

---

## 🐛 ERROR HANDLING

### Strategy
```ruby
ErrorHandler.capture(error, context)
  ↓
1. Log to AppLogger
2. Send to Sentry
3. Track metrics
4. Alert if critical
```

### Error Levels
- **CRITICAL:** Database down, Redis unavailable
- **ERROR:** Failed API calls, validation errors  
- **WARN:** Slow queries, cache misses
- **INFO:** Normal operations

---

## 📊 MONITORING

### Health Checks
- `/health` - Quick status
- `/health/detailed` - Full diagnostics (admin only)

### Metrics Tracked
- Request rate & latency
- Error rate by type
- Cache hit/miss ratio
- Database query performance
- Active user count
- Memory usage

### Alerts
- Memory leak detection
- High error rate (>1%)
- Database connection exhaustion
- Redis failures

---

## 🚀 DEPLOYMENT

### Environments
- **Development:** SQLite, local Redis
- **Production:** PostgreSQL, Redis Cloud, Render.com

### Deploy Process
```bash
1. Run tests: bundle exec rspec
2. Security audit: bundle audit
3. Push to main branch
4. Render auto-deploys
5. Health check verification
6. Monitor Sentry for errors
```

### Rollback
```bash
# Via Render dashboard or CLI
render rollback <service-name>
```

---

## 📚 REFERENCES

- **Main Audit:** `docs/archive/audits_2026/SENIOR_DEV_COMPREHENSIVE_AUDIT_JUNE_3_2026.md`
- **Roadmap:** `NEXT_90_DAYS_ROADMAP_JUNE_2026.md`
- **API Docs:** `API_DOCS.md`
- **Phase 1 Report:** `PHASE_1_CRITICAL_FIXES_COMPLETE.md`

---

**Maintained by:** Development Team  
**Questions?** See CONTRIBUTING.md for contact info
