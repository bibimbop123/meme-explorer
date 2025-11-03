# Meme Explorer - Complete Documentation

> **Last Updated:** November 3, 2025 | **Status:** Production Ready | **Version:** 1.0.0

---

## Quick Navigation

- **New to the project?** → [Project Overview](#project-overview)
- **Want to run it?** → [Getting Started](#getting-started)
- **Building features?** → [Development Guide](#development-guide)
- **Deploying?** → [Deployment Guide](#deployment-guide)
- **API integration?** → [API Reference](#api-reference)
- **Security concerns?** → [Security & Audit](#security--audit)

---

## Project Overview

**Meme Explorer** is a Sinatra-based web application that aggregates and serves memes from Reddit, with user authentication, personalized collections, and community engagement features.

### Core Features
- 🔐 OAuth2 authentication (Reddit login)
- 🎯 Advanced meme search with multi-tier ranking
- 👤 User profiles with saved memes
- ⭐ Like/engagement tracking
- 🏆 Admin dashboard for moderation
- 📊 Metrics and analytics

### Technology Stack
- **Backend:** Ruby 3.2.1 + Sinatra 4.2.1
- **Database:** SQLite3 (with PostgreSQL migration path)
- **Caching:** Redis (optional, with fallback)
- **Frontend:** ERB templates + CSS
- **Authentication:** OAuth2 (Reddit API)
- **Testing:** RSpec
- **Deployment:** Puma + Rack

### Project Structure
```
meme_explorer/
├── app.rb                 # Main application
├── routes/                # Route handlers
│   ├── auth.rb           # Authentication flows
│   ├── memes.rb          # Meme operations
│   ├── search.rb         # Search functionality
│   ├── profile.rb        # User profiles
│   └── admin.rb          # Admin operations
├── lib/
│   ├── services/         # Business logic
│   │   ├── search_service.rb          # Meme search (canonical)
│   │   ├── auth_service.rb            # Authentication
│   │   ├── user_service.rb            # User management
│   │   └── meme_service.rb            # Meme operations
│   ├── validators.rb               # Input validation
│   ├── error_handler.rb            # Error management
│   └── cache_manager.rb            # Caching logic
├── public/
│   ├── css/              # Stylesheets (consolidated)
│   └── images/           # Meme assets
├── views/                # ERB templates
├── spec/                 # Tests (RSpec)
├── config/               # Configuration
└── db/                   # Database setup
```

---

## Getting Started

### Prerequisites
- Ruby 3.2.1
- SQLite3
- Redis (optional)
- Reddit OAuth app credentials

### Installation

```bash
# Clone repository
git clone git@github.com:bibimbop123/meme-explorer.git
cd meme_explorer

# Install dependencies
bundle install

# Create environment file
cp .env.example .env

# Add your credentials to .env:
# REDDIT_CLIENT_ID=your_client_id
# REDDIT_CLIENT_SECRET=your_client_secret
```

### Running Locally

```bash
# Development server (port 4567)
ruby app.rb

# Or with Puma explicitly
bundle exec puma -p 4567

# Visit http://localhost:4567
```

### First Run
1. You'll see the homepage with trending memes
2. Click "Login with Reddit" to authenticate
3. Grant OAuth permissions
4. Redirect back to app with your profile created
5. Start searching and saving memes

---

## Development Guide

### Architecture Decisions

**Multi-tier Search Strategy**
- Tier 1: In-memory cache (fastest)
- Tier 2: Reddit API (fresh content)
- Tier 3: Local database + YAML fallback (reliability)

**Input Validation Layer**
- Centralized validators module (`lib/validators.rb`)
- Applied at route entry points
- Prevents SQL injection, XSS, parameter tampering
- Returns structured error responses

**Caching Strategy**
- Cache size: 500MB hard limit with LRU eviction
- TTL: 30 minutes default
- Redis for distributed caching
- Memory fallback when Redis unavailable

### Key Services

#### SearchService (`lib/services/search_service.rb`)
```ruby
SearchService.search(query, meme_cache, popular_subreddits)
# Returns: { success: true, results: [...], total: N }
```
**Features:**
- Input validation
- Multi-tier ranking algorithm
- Deduplication
- Error handling

#### AuthService (`lib/services/auth_service.rb`)
```ruby
AuthService.authenticate(oauth_code, redirect_uri)
# Returns: OAuth token or raises error
```
**Features:**
- OAuth2 flow handling
- Token management
- Session creation

#### UserService (`lib/services/user_service.rb`)
- User CRUD operations
- Profile management
- Preference storage

#### MemeService (`lib/services/meme_service.rb`)
- Reddit API integration
- Meme fetching and caching
- Statistics tracking

### Adding Features

**1. Adding a new route:**
```ruby
# In routes/new_feature.rb
get '/new-feature' do
  # Validate inputs
  params = Validators.validate_params(params, {
    search: { required: true, type: String }
  })
  
  # Execute business logic
  result = SomeService.do_something(params)
  
  # Return response
  erb :template, locals: { result: result }
end

# Register in app.rb
require_relative './routes/new_feature'
```

**2. Adding tests:**
```ruby
# In spec/routes/new_feature_spec.rb
describe 'NewFeature' do
  it 'returns results for valid input' do
    get '/new-feature?search=test'
    expect(last_response).to be_ok
  end
end
```

---

## API Reference

### Authentication Routes

**POST /auth/login**
- Initiates OAuth flow
- Redirects to Reddit authorization

**GET /auth/reddit/callback**
- OAuth callback endpoint
- Creates session on success

**POST /auth/logout**
- Terminates session
- Clears cookies

### Meme Routes

**GET /memes**
- List trending memes (paginated)
- Query params: `page`, `category`

**GET /memes/:id**
- View single meme details
- Includes comments/engagement

**POST /memes/:id/like**
- Like a meme (authenticated)
- Returns updated like count

**GET /search?q=term**
- Search memes by title/category
- Returns ranked results

### User Routes

**GET /profile**
- View authenticated user profile
- Shows saved memes, stats

**POST /profile/update**
- Update user preferences
- Requires authentication

**GET /profile/:username**
- View public user profile
- Shows public memes only

### Admin Routes

**GET /admin**
- Admin dashboard
- Requires admin role

**POST /admin/memes/:id/remove**
- Remove inappropriate meme
- Admin only

---

## Security & Audit

### Security Measures Implemented

✅ **Input Validation**
- All user input validated via `Validators` module
- SQL injection prevention via parameterized queries
- XSS protection via ERB escaping

✅ **Authentication**
- OAuth2 with Reddit
- Session management with secure cookies
- CSRF tokens on state-changing requests

✅ **Rate Limiting**
- Rack::Attack middleware
- 60 requests per IP per minute
- Whitelist: localhost

✅ **Database Security**
- Parameterized queries (no string interpolation)
- SQLite with file permissions (development)
- Prepared statements throughout

### Known Issues & Mitigations

| Issue | Status | Mitigation |
|-------|--------|-----------|
| Static image assets | Open | Consider CDN/dynamic image handling |
| OAuth edge cases | Partial | See test expansion plan |
| Admin permission validation | Partial | Enhanced in phase 2 |

### Security Audit Report

See `SECURITY_AUDIT_REPORT.md` for complete findings.

---

## Deployment Guide

### Environment Setup

```bash
# Production environment variables
export RACK_ENV=production
export SESSION_SECRET=$(openssl rand -hex 32)
export REDDIT_CLIENT_ID=your_production_id
export REDDIT_CLIENT_SECRET=your_production_secret
export REDIS_URL=redis://prod-redis-server:6379
export DATABASE_URL=postgres://user:pass@db-server/meme_explorer_prod
```

### Pre-Deployment Checklist

- [ ] All tests passing (`bundle exec rspec`)
- [ ] Security audit completed
- [ ] Database migrations applied
- [ ] Environment variables configured
- [ ] Redis instance available
- [ ] SSL certificates valid

### Deployment Steps

```bash
# 1. Build and test
bundle install --production
bundle exec rspec

# 2. Database setup
bundle exec rake db:migrate

# 3. Start server
bundle exec puma -p 4567 -w 4 -t 32:32

# 4. Monitor logs
tail -f log/production.log
```

### Monitoring

- Health check: `GET /health`
- Metrics: `GET /metrics`
- Error tracking: Sentry (if configured)

---

## Testing Guide

### Running Tests

```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/services/search_service_spec.rb

# With coverage
bundle exec rspec --format documentation
```

### Test Coverage

**Current Coverage:** ~40%

**Critical Areas (Phase 1):**
- ✅ Authentication flows
- ✅ Input validation
- ✅ Database operations

**Phase 2 Expansion:**
- OAuth edge cases (8 new tests)
- Search filtering (10 new tests)
- Admin permissions (5 new tests)
- Profile operations (6 new tests)

### Writing Tests

```ruby
describe SearchService do
  it 'returns ranked results for valid query' do
    cache = [
      { "title" => "Funny Meme", "likes" => 100 },
      { "title" => "Another Meme", "likes" => 50 }
    ]
    
    results = SearchService.search("Funny", cache, [])
    expect(results[:success]).to be true
    expect(results[:results].first["title"]).to include("Funny")
  end
end
```

---

## Troubleshooting

### Common Issues

**"Address already in use" error**
```bash
# Port 4567 in use, find and kill process
lsof -i :4567
kill -9 <PID>
```

**Redis connection failed**
```bash
# Check Redis running
redis-cli ping
# Should return: PONG

# If not running, start Redis
redis-server
```

**Database locked error**
```bash
# SQLite file locked, restart application
rm meme_explorer.db.lock
ruby app.rb
```

**OAuth redirect URI mismatch**
```bash
# Verify in .env matches Reddit app settings:
REDDIT_REDIRECT_URI=http://localhost:4567/auth/reddit/callback
```

### Performance Tuning

| Metric | Target | Current | Action |
|--------|--------|---------|--------|
| Avg response time | < 200ms | ~250ms | Add indexing  |
| Cache hit rate | > 85% | ~70% | Increase TTL |
| DB query time | < 50ms | ~80ms | Add indexes  |

---

## Contributing

### Development Workflow

1. Create feature branch: `git checkout -b feature/name`
2. Write tests first (TDD)
3. Implement feature
4. Ensure all tests pass
5. Create pull request

### Code Standards

- Follow Ruby style guide (2-space indentation)
- Document complex logic
- Validate all inputs
- Handle errors explicitly

### Commit Messages

```
[TYPE] Brief description

Detailed explanation if needed.
Fixes #123
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

---

## Roadmap

### Phase 1 (Week 1) - Currently In Progress
- ✅ Security hardening
- ✅ Input validation
- ⏳ Documentation consolidation

### Phase 2 (Week 2)
- Expand test coverage to 70%
- Consolidate CSS files
- Performance optimization

### Phase 3 (Week 3)
- Frontend refactor (add React)
- Advanced search filters
- User recommendations

### Phase 4 (Week 4)
- Mobile app (React Native)
- Advanced analytics
- Community features

---

## Support & Resources

- **GitHub Issues:** Report bugs here
- **Email:** support@meme-explorer.local
- **Slack:** #meme-explorer channel

## References

- [Sinatra Documentation](http://sinatrarb.com/)
- [Reddit API Documentation](https://www.reddit.com/dev/api)
- [OAuth 2.0 Guide](https://oauth.net/2/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**Last Updated:** November 3, 2025  
**Maintained by:** Development Team  
**Version:** 1.0.0 - Production Ready
