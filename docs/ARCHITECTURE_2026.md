# 🏗️ Meme Explorer Architecture Documentation
## Updated: June 26, 2026

**Version**: 2.0.0  
**Status**: Production  
**Last Audit**: June 26, 2026

---

## 📊 Executive Summary

Meme Explorer is a mature, production-grade Sinatra application that provides intelligent meme discovery through sophisticated algorithms, gamification, and analytics. The architecture emphasizes **scalability**, **observability**, and **maintainability**.

### Key Metrics
- **Codebase**: 151 Ruby files (23,000+ LOC)
- **Services**: 62 service classes
- **Workers**: 14 Sidekiq background jobs
- **Routes**: 23 modular route files
- **Test Coverage**: ~50% (Target: 70%)
- **Uptime**: 99.9%+
- **Response Time P95**: <500ms

---

## 🎯 Core Architecture Principles

### 1. **Service-Oriented Design**
```
app.rb (Controller Layer)
   ↓
Routes (HTTP Handling)
   ↓
Services (Business Logic)
   ↓
Models/Data Layer
```

### 2. **Separation of Concerns**
- **Routes**: HTTP request/response handling
- **Services**: Reusable business logic
- **Helpers**: View/presentation logic
- **Workers**: Asynchronous background processing
- **Middleware**: Cross-cutting concerns

### 3. **Thread-Safe Concurrency**
- Puma multi-threaded server (32 threads)
- Connection pooling (PostgreSQL: 35 connections)
- Atomic operations (`Concurrent::AtomicFixnum`)
- Redis circuit breaker patterns

---

## 📁 Directory Structure

```
meme-explorer/
├── app.rb                      # Main Sinatra application
├── config.ru                   # Rack configuration
│
├── routes/                     # Modular route definitions (23 files)
│   ├── auth.rb                # Authentication
│   ├── memes.rb               # Meme endpoints
│   ├── admin_routes.rb        # Admin panel
│   ├── trending_routes.rb     # Trending memes
│   ├── search_routes.rb       # Search functionality
│   └── ...
│
├── lib/
│   ├── services/              # Business logic (62 services)
│   │   ├── meme_service.rb
│   │   ├── auth_service.rb
│   │   ├── reddit_fetcher_service.rb
│   │   ├── api_cache_service.rb
│   │   ├── leaderboard_service.rb
│   │   └── ...
│   │
│   ├── helpers/               # View helpers
│   │   ├── app_helpers.rb
│   │   ├── meme_helpers.rb
│   │   ├── gamification_helpers.rb
│   │   └── ...
│   │
│   ├── concerns/              # Shared modules
│   │   ├── transaction_wrapper.rb
│   │   ├── distributed_lock.rb
│   │   ├── error_handler.rb
│   │   ├── cache_strategy.rb
│   │   └── ...
│   │
│   ├── middleware/            # Rack middleware
│   │   ├── request_id_middleware.rb
│   │   ├── security_headers.rb
│   │   ├── performance_monitor.rb
│   │   └── ...
│   │
│   ├── cache_keys.rb          # Centralized cache key management
│   ├── cache_manager.rb       # Cache abstraction layer
│   ├── validators.rb          # Input validation
│   ├── app_logger.rb          # Structured logging
│   └── db_helpers.rb          # Database utilities
│
├── app/
│   ├── workers/               # Sidekiq background jobs (14 workers)
│   │   ├── cache_refresh_worker.rb
│   │   ├── leaderboard_calculation_worker.rb
│   │   ├── image_health_worker.rb
│   │   └── ...
│   │
│   └── components/            # Reusable components
│       └── progressive_image_component.rb
│
├── spec/                      # RSpec tests (32 spec files)
│   ├── services/
│   ├── routes/
│   ├── helpers/
│   └── workers/
│
├── config/                    # Configuration files
│   ├── application.rb
│   ├── constants.rb
│   ├── app_constants.rb
│   ├── algorithm_config.yml
│   ├── initializers/
│   └── ...
│
├── db/                        # Database
│   ├── migrations/
│   ├── postgres_schema.sql
│   └── setup.rb
│
├── public/                    # Static assets
│   ├── css/
│   ├── js/
│   ├── images/
│   └── manifest.json
│
├── views/                     # ERB templates
│   ├── layout.erb
│   ├── random.erb
│   ├── trending.erb
│   └── ...
│
└── docs/                      # Documentation
    ├── openapi.yml           # API specification
    ├── ARCHITECTURE_2026.md  # This file
    └── ...
```

---

## 🔧 Technology Stack

### Core Technologies
- **Language**: Ruby 3.2+
- **Framework**: Sinatra 3.x
- **Server**: Puma (multi-threaded)
- **Database**: PostgreSQL 14+
- **Cache**: Redis 7+
- **Background Jobs**: Sidekiq 7+

### Key Gems
```ruby
# Core
gem 'sinatra'
gem 'puma'
gem 'pg'              # PostgreSQL
gem 'redis'
gem 'sidekiq'

# External APIs
gem 'httparty'        # HTTP client
gem 'redd'            # Reddit API client

# Utilities
gem 'connection_pool'  # Connection pooling
gem 'concurrent-ruby'  # Thread-safe structures
gem 'bcrypt'          # Password hashing

# Monitoring
gem 'sentry-ruby'     # Error tracking

# Testing
gem 'rspec'
gem 'rack-test'
gem 'simplecov'       # Coverage reports
```

---

## 🌊 Data Flow

### Request Flow
```
1. User Request
      ↓
2. Rack Middleware Stack
   - RequestIdMiddleware (tracing)
   - SecurityHeaders (CORS, CSP)
   - PerformanceMonitor (timing)
      ↓
3. Sinatra Router
   - Route matching
   - Before filters (auth, logging)
      ↓
4. Controller Logic (routes/*.rb)
   - Parameter validation
   - Business logic delegation
      ↓
5. Service Layer (lib/services/*.rb)
   - Business logic execution
   - Database queries
   - External API calls
   - Cache operations
      ↓
6. Data Layer
   - PostgreSQL (persistent data)
   - Redis (cache, sessions)
      ↓
7. Response Rendering
   - JSON serialization
   - ERB template rendering
      ↓
8. Response Middleware
   - Headers injection
   - Compression
   - Metrics collection
      ↓
9. Client Response
```

### Background Job Flow
```
1. Job Enqueued
   Sidekiq.perform_async(args)
      ↓
2. Redis Queue
   Job stored in Redis list
      ↓
3. Sidekiq Worker Process
   Worker picks up job
      ↓
4. Job Execution
   - Service layer methods
   - Database operations
   - External API calls
      ↓
5. Success/Failure Handling
   - Retry logic (exponential backoff)
   - Error tracking (Sentry)
   - Metrics collection
```

---

## 🗄️ Database Schema

### Core Tables

**users**
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) DEFAULT 'user',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role) WHERE role = 'admin';
```

**meme_stats**
```sql
CREATE TABLE meme_stats (
  id SERIAL PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,
  title TEXT,
  subreddit VARCHAR(100),
  category VARCHAR(50),
  reddit_url TEXT,
  views INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0,
  quality_score DECIMAL(5,2) DEFAULT 0.0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_meme_stats_url ON meme_stats(url);
CREATE INDEX idx_meme_stats_quality ON meme_stats(quality_score DESC);
CREATE INDEX idx_meme_stats_trending ON meme_stats((likes * 2 + views) DESC);
CREATE INDEX idx_meme_stats_created_at ON meme_stats(created_at DESC);
```

**user_meme_stats**
```sql
CREATE TABLE user_meme_stats (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  meme_url TEXT,
  liked BOOLEAN DEFAULT FALSE,
  saved BOOLEAN DEFAULT FALSE,
  viewed BOOLEAN DEFAULT FALSE,
  view_count INTEGER DEFAULT 0,
  last_viewed TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_user_meme_stats_compound ON user_meme_stats(user_id, meme_url);
CREATE INDEX idx_user_meme_stats_liked ON user_meme_stats(user_id, liked) WHERE liked = true;
```

**leaderboard**
```sql
CREATE TABLE leaderboard (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  score INTEGER DEFAULT 0,
  level INTEGER DEFAULT 1,
  streak INTEGER DEFAULT 0,
  badges JSONB DEFAULT '[]',
  rank INTEGER,
  period VARCHAR(20) DEFAULT 'all_time',
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_leaderboard_user_period ON leaderboard(user_id, period);
CREATE INDEX idx_leaderboard_rank ON leaderboard(period, rank);
```

### Performance Indexes
See `db/migrations/add_performance_indexes.sql` for complete list.

---

## 📦 Service Architecture

### Service Categories

#### 1. **Core Services**
- `MemeService` - Meme CRUD operations
- `AuthService` - Authentication & authorization
- `UserService` - User management

#### 2. **External Integration Services**
- `RedditFetcherService` - Reddit API integration
- `TurbochargedRedditFetcher` - Optimized Reddit fetching
- `ApiCacheService` - External API caching (748 lines)

#### 3. **Caching Services**
- `CacheKeys` - Centralized key management
- `CacheManager` - Cache abstraction
- `SimilarMemeCache` - Content similarity caching

#### 4. **Gamification Services**
- `LeaderboardService` - User rankings
- `MilestoneService` - Achievement tracking
- `EngagementService` - User engagement metrics

#### 5. **Algorithm Services**
- `RandomSelectorService` - Intelligent meme selection
- `CollaborativeFilteringService` - Personalization
- `QualityPipelineService` - Content quality scoring

#### 6. **Analytics Services**
- `AnalyticsService` - Usage analytics
- `MetricsTrackerService` - Performance metrics
- `ABTestingService` - A/B experimentation

#### 7. **Infrastructure Services**
- `RedisService` - Redis abstraction
- `HealthCheckService` - System health monitoring
- `ImageHealthService` - Image availability checking

---

## 🔄 Caching Strategy

### Cache Layers

#### 1. **Redis Cache** (Primary)
```ruby
# L1: Hot Data (TTL: 5 minutes)
CacheKeys::TTL_SHORT = 300

# L2: Warm Data (TTL: 30 minutes)
CacheKeys::TTL_MEDIUM = 1800

# L3: Cold Data (TTL: 1 hour)
CacheKeys::TTL_LONG = 3600

# L4: Stable Data (TTL: 24 hours)
CacheKeys::TTL_VERY_LONG = 86400
```

#### 2. **Meme Pool** (In-Memory)
- Pre-fetched memes for instant delivery
- Target size: 50-100 memes
- Refreshed every 30 minutes
- Quality-filtered and diversity-balanced

#### 3. **HTTP Cache Headers**
```ruby
Cache-Control: public, max-age=300
ETag: "meme-version-hash"
Last-Modified: Thu, 26 Jun 2026 00:00:00 GMT
```

### Cache Invalidation

**Pattern**: Write-through with TTL
```ruby
# On write
CacheKeys.invalidate_meme(meme_id)
CacheKeys.invalidate_user(user_id)

# On update
CacheKeys.invalidate_leaderboard('weekly')
```

---

## 🔐 Security Architecture

### Authentication
- **Session-based**: HTTP-only cookies
- **Password Hashing**: BCrypt (cost: 12)
- **Session Storage**: Redis-backed
- **Session TTL**: 24 hours

### Authorization
```ruby
# Role-based access control
ROLES = ['user', 'admin', 'super_admin']

# Route protection
before '/admin/*' do
  halt 403 unless is_admin?
end
```

### Security Headers
```ruby
# Applied via SecurityHeaders middleware
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000
Content-Security-Policy: default-src 'self'
```

### CSRF Protection
```ruby
# Token-based CSRF protection
use Rack::Protection, except: :session_hijacking
```

---

## 📈 Monitoring & Observability

### Health Checks

**Basic** (`/health`):
- Database connectivity
- Redis connectivity
- Sidekiq status

**Detailed** (`/health/detailed`):
- Connection pool utilization
- Memory usage
- Thread count
- Queue depths
- Cache statistics

### Logging

**Structured Logging**:
```ruby
AppLogger.info('event_name', {
  user_id: 123,
  action: 'meme_viewed',
  meme_id: 456,
  timestamp: Time.now.iso8601,
  request_id: 'uuid'
})
```

### Metrics

**Performance Metrics**:
- Request rate (requests/min)
- Response time (P50, P95, P99)
- Error rate
- Cache hit rate

**Business Metrics**:
- Meme views
- User engagement rate
- Leaderboard participation
- Daily active users

---

## 🚀 Scaling Strategy

### Horizontal Scaling
```
                 Load Balancer
                      |
      ┌───────────────┼───────────────┐
      |               |               |
  Puma Instance   Puma Instance   Puma Instance
  (32 threads)    (32 threads)    (32 threads)
      |               |               |
      └───────────────┼───────────────┘
                      |
            ┌─────────┴─────────┐
            |                   |
      PostgreSQL            Redis
     (Primary +           (Cluster)
      Replicas)
```

### Vertical Scaling
- **CPU**: Multi-threaded Puma (32 threads)
- **Memory**: Connection pooling (35 connections)
- **I/O**: Non-blocking HTTP clients

### Database Scaling
- **Read Replicas**: Offload read traffic
- **Indexes**: Optimized for common queries
- **Connection Pooling**: Prevent exhaustion
- **Query Timeouts**: Prevent slow query blocking

---

## 🧪 Testing Strategy

### Test Coverage (Current: ~50%)

**Unit Tests**:
- Services (core business logic)
- Helpers (pure functions)
- Validators (input validation)

**Integration Tests**:
- Routes (HTTP endpoints)
- Workers (background jobs)
- External API mocking

**Performance Tests**:
- Load testing (`scripts/performance_test.rb`)
- Chaos testing (`scripts/chaos_tests.rb`)

### Testing Tools
```ruby
# RSpec + Rack::Test
describe 'GET /random.json' do
  it 'returns a random meme' do
    get '/random.json'
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    expect(json).to have_key('url')
  end
end
```

---

## 🔄 Deployment Pipeline

### CI/CD Flow
```
1. Git Push
      ↓
2. GitHub Actions
   - Syntax check
   - RuboCop linting
   - RSpec tests
   - Coverage report
      ↓
3. Build Success
      ↓
4. Deploy to Staging
   - Database migrations
   - Cache warm-up
   - Smoke tests
      ↓
5. Manual Approval
      ↓
6. Deploy to Production
   - Rolling deployment
   - Health checks
   - Rollback on failure
```

### Zero-Downtime Deployment
1. Deploy new code to standby instances
2. Run database migrations (non-breaking)
3. Health check new instances
4. Switch load balancer traffic
5. Monitor metrics for 5 minutes
6. Terminate old instances

---

## 📊 Performance Benchmarks

### Response Times (P95)
- `/random.json`: <200ms
- `/trending.json`: <300ms
- `/search.json`: <400ms
- `/leaderboard.json`: <250ms

### Throughput
- **Requests/sec**: 500+
- **Concurrent Users**: 1000+
- **Database Queries/sec**: 2000+

### Resource Utilization
- **Memory**: ~500MB per instance
- **CPU**: <40% average
- **Database Connections**: 12/35 average
- **Cache Hit Rate**: 84%

---

## 🎯 Future Improvements

### Q3 2026
- [ ] Split ApiCacheService (currently 748 lines)
- [ ] Increase test coverage to 70%
- [ ] Add GraphQL API layer
- [ ] Implement read replicas

### Q4 2026
- [ ] WebSocket real-time updates
- [ ] ML-powered recommendations
- [ ] CDN integration
- [ ] Multi-region deployment

---

## 📚 Documentation Index

- **API Documentation**: `docs/openapi.yml`
- **Deployment Guide**: `DEPLOYMENT_INSTRUCTIONS.md`
- **Contributing**: `CONTRIBUTING.md`
- **Troubleshooting**: `TROUBLESHOOTING.md`
- **Audit Reports**: `COMPREHENSIVE_AUDIT_JUNE_26_2026.md`

---

## 👥 Architecture Team

- **Lead Architect**: Senior Ruby/Sinatra Developer
- **Database**: PostgreSQL optimization specialist
- **Frontend**: JavaScript/ERB integration
- **DevOps**: Deployment & monitoring

---

**Last Updated**: June 26, 2026  
**Next Review**: August 1, 2026  
**Version**: 2.0.0
