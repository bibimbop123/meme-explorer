# 🎉 Meme Explorer

A modern meme discovery platform built with Ruby/Sinatra.

## 🌟 Features

These reflect what's actually registered in `app.rb` today — if a route isn't
wired up there, it doesn't exist yet, no matter what an old status report
might claim.

### Core Functionality
- **Random Meme Discovery** - `/random` and `/random.json`, backed by
  `MemePoolManager`'s Redis-cached, tier-distributed pool with anti-repetition
  selection
- **Trending Memes** - `/trending` and `/trending.json`, engagement-scored
  with time decay
- **Search** - `/search` and `/api/search.json`
- **User Profiles** - `/profile`, saved memes, engagement tracking
- **Leaderboard** - `/leaderboard` and `/api/leaderboard`
- **Gallery View** - Multi-image Reddit gallery rendering
- **Personalization** - `/taste-evolution` and saved-meme collections
- **Blog** - `/blog` (original content pages)

### Background Jobs (Sidekiq)
- **Workers:** cache refresh, cache preload, meme pool maintenance, database
  cleanup
- **Schedule:** cron-like scheduling via `sidekiq-scheduler`

## 📝 A note on scope

Earlier phases of this project experimented with a wider surface area
(A/B testing, gamification, battle mode, reactions, particle/sound effects).
Those were removed from the boot path because they added maintenance cost
without earning their keep. If you find references to them in old docs
under `docs/archive/`, treat those docs as historical, not current.

## 🚀 Quick Start

### Prerequisites
- Ruby 3.0+
- PostgreSQL 13+
- Redis 6+ (for Sidekiq)

### Installation

```bash
# Clone the repository
git clone git@github.com:bibimbop123/meme-explorer.git
cd meme-explorer

# Install dependencies
bundle install

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Set up database
ruby db/setup.rb

# Start Redis (for Sidekiq)
redis-server

# Start Sidekiq workers (in separate terminal)
bundle exec sidekiq -r ./config/initializers/sidekiq.rb

# Start the application
bundle exec rackup -p 8080
```

Visit `http://localhost:8080` to explore memes!

## 📖 Documentation

- **[Roadmap](ROADMAP.md)** - Strategic prioritization: why reliability and
  personalization of the core `/random` loop outrank new features right now
- **[Architecture Overview](ARCHITECTURE.md)** - System design and patterns
- **[Security Guide](SECURITY.md)** - Security best practices
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and fixes
- **[Contributing](CONTRIBUTING.md)** - How to contribute
- **[Historical docs](docs/archive/)** - Past audits and phase reports (not
  guaranteed to reflect current behavior)

## 🛠️ Technology Stack

### Backend
- **Framework:** Sinatra (Ruby)
- **Database:** PostgreSQL
- **Caching:** Redis
- **Background Jobs:** Sidekiq
- **Error Tracking:** Sentry

### Frontend
- **Templating:** ERB
- **Build:** Vite (bundles `public/js/main.js` into `public/dist/bundle.js`)
- **CSS:** Custom responsive design
- **JavaScript:** Vanilla JS with modern features

**Important:** `render.yaml`'s `buildCommand` is just `bundle install` - there
is no CI/deploy step that runs `npm run build`. `public/dist/` is committed
to git and IS the deploy artifact, not disposable build output. If you
change anything under `public/js/`, you must run `npm run build` locally
and commit the resulting `public/dist/bundle.js` before deploying, or
production will keep serving the old bundle.

### DevOps
- **Hosting:** Render.com / Heroku
- **CI/CD:** GitHub Actions
- **Monitoring:** Sentry
- **Performance:** Request timing middleware

## 📊 API Endpoints

### Public Routes
```
GET  /                   - Home page
GET  /random             - Random meme discovery
GET  /random.json        - Random meme API
GET  /trending           - Trending memes
GET  /trending.json      - Trending memes API
GET  /api/trending       - Trending memes API (paginated, {memes, count, period, pagination} shape)
GET  /search             - Search memes
GET  /api/search.json    - Search API
GET  /leaderboard        - User rankings
GET  /api/leaderboard    - Leaderboard API
GET  /blog               - Blog index
```

### Authenticated Routes
```
POST /signup              - Create account
POST /login                - Sign in
GET  /profile             - Current user profile
POST /api/save-meme       - Save meme to collection
POST /api/unsave-meme     - Remove meme from collection
GET  /taste-evolution     - Personalization insights
```

### Admin Routes
```
GET  /admin               - Admin dashboard
GET  /metrics             - Performance metrics
```

## 🧪 Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test suite
bundle exec rspec spec/services/
bundle exec rspec spec/routes/

# Run with coverage
COVERAGE=true bundle exec rspec

# Performance testing
ruby scripts/performance_test.rb
```

## 🔒 Security

- **Input Validation:** Comprehensive sanitization via `lib/validators.rb`
- **SQL Injection Prevention:** Parameterized queries throughout
- **CSRF Protection:** Token-based protection on forms
- **Authentication:** BCrypt password hashing
- **Rate Limiting:** Rack::Attack middleware
- **Error Handling:** Secure error messages, no stack traces in production

## 📈 Performance

### The one number that matters: selection latency

This product's core loop is picking the right meme for a person, right now.
`SelectionBenchmark` (`lib/services/selection_benchmark.rb`) measures that
loop end-to-end on every real `/random` and `/random.json` request, broken
into stages:

- `:total` - the whole decision, start to finish
- `:pool_lookup` - finding a pool of candidate memes
  - `:pool_manager_lookup` - specifically `MemePoolManager`'s Redis round-trip
  - `:reddit_fetch` - specifically the on-demand Reddit API call, when the
    pool is cold and falls back to fetching fresh content
- `:selection` - the anti-repetition selection algorithm itself

Live p50/p95/p99 for every stage, from real traffic, is visible at
`/metrics` (admin-only) - not asserted here as a static claim. Numbers
like "average response time" or "P95 <500ms" are only trustworthy if
they come from a live instrument reading real requests; a number typed
into a README with no source behind it is worse than no number at all,
so we removed the previous placeholder figures rather than leave them
looking authoritative. Go look at `/metrics` for the real answer.

### Optimizations
- Strategic database indexes
- Redis caching layer
- Background job processing
- CDN-ready static assets
- Image lazy loading

## 🎯 Roadmap

### Completed ✅
- [x] Performance Monitoring (request timing middleware, `/metrics`)
- [x] Selection latency benchmarking, staged by pool-lookup vs. selection
  vs. real network I/O (`SelectionBenchmark`, live at `/metrics`)
- [x] Background Jobs (Sidekiq)
- [x] Modular route architecture (`routes/*.rb`, `self.registered(app)` pattern)
- [x] Leaderboard

### In Progress 🚧
- [ ] Mobile app development
- [ ] Collapsing the multi-layer pool fallback chain (`MemePoolManager` →
  `MEME_CACHE` → on-demand Reddit fetch) once real `/metrics` traffic data
  shows which layer is the actual cost driver
- [ ] Advanced caching strategies

### Planned 📋
- [ ] CDN integration
- [ ] Image optimization pipeline
- [ ] WebSocket support for real-time features
- [ ] GraphQL API layer
- [ ] Progressive Web App (PWA)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is proprietary software developed by Discovery Partners Institute.

## 👥 Team

- **Engineering Lead:** Brian
- **Organization:** Discovery Partners Institute
- **Started:** 2025

## 📞 Support

- **Issues:** GitHub Issues
- **Documentation:** See `docs/` directory

---

**Built with ❤️ by Brian Kim**
