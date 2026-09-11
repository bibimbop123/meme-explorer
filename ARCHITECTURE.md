# 🏗️ MEME EXPLORER - SYSTEM ARCHITECTURE

**Last verified against the actual codebase:** this session. Every number
below was checked against real files (`wc -l`, `ls`, `grep`), not carried
forward from an earlier draft - a previous version of this document
claimed `app.rb` was 2,644 lines and this app had 55 services and ~500
concurrent user capacity, none of which were true by the time anyone
checked. Please keep it that way: if you change something this document
describes, update this file in the same commit, or delete the claim
instead of leaving it stale.

---

## 📊 OVERVIEW

Meme Explorer is a Ruby/Sinatra application for discovering memes from
Reddit. It runs as a **single Puma worker process by design** (see
`config/puma.rb`) - the meme pool lives in shared in-process memory
(`MEME_CACHE`), which only works with one worker. This is not a
temporary limitation; it's the current architecture, and any change
proposing multi-worker/multi-region deployment needs to solve that
constraint first, not assume it away.

### Tech Stack
- **Runtime:** Ruby 3.2.1
- **Framework:** Sinatra 4.0
- **Database:** PostgreSQL (production), SQLite (development migration tooling only)
- **Cache:** Redis
- **Jobs:** Sidekiq with sidekiq-scheduler
- **Server:** Puma (single worker, `WEB_CONCURRENCY=0`)
- **Frontend build:** Vite (bundles `public/js/main.js` → `public/dist/bundle.js`)
- **Monitoring:** Sentry, `/health`, `/metrics`

### Real numbers (verified, not estimated)
- `app.rb`: 423 lines
- `lib/services/`: 27 files
- `routes/`: 24 files
- `spec/`: 57 spec files
- Background workers actually required by `app.rb`: `cache_refresh_worker`,
  `cache_preload_worker`, `meme_pool_maintenance_worker`,
  `database_cleanup_worker` - four, not more. If a doc or comment
  mentions a worker not in that list (e.g. an old reference to a
  "LeaderboardCalculationWorker" or "ImageHealthWorker"), it doesn't
  exist - it was removed at some point and the doc wasn't updated.

---

## 🎯 CORE ARCHITECTURE

```
Browser → Rack Middleware → Sinatra Routes → Helpers → Service Layer (27) → PostgreSQL / Redis / Reddit API
```

Routes live in `routes/*.rb` (24 files), registered via the
`self.registered(app)` pattern from `app.rb`. Helpers live in
`lib/helpers/`. Services live in `lib/services/` (27 files) - things like
`MemeService`, `MemePoolManager`, `SelectionBenchmark`, `TrendingService`,
`AuthService`, `RedisService`. Persistence is PostgreSQL for durable data
(users, meme_stats, saved memes), Redis for the pool cache, sessions, rate
limiting, and the selection benchmark's rolling windows, and the Reddit
API as the upstream content source.

---

## 📁 DIRECTORY STRUCTURE

```
meme-explorer/
├── app.rb                    # Main Sinatra application (423 lines)
├── config/                   # Configuration files
│   ├── application.rb        # App config
│   ├── app_constants.rb      # Constants
│   ├── tuning_parameters.rb  # Extracted magic numbers
│   ├── sidekiq.yml           # Job scheduling
│   └── initializers/         # Load order
├── routes/                   # Modular routes (24 files)
│   ├── auth.rb
│   ├── random_meme.rb        # The core product loop - see below
│   ├── metrics_routes.rb     # /metrics, /metrics.json
│   ├── trending_routes.rb
│   └── ...
├── lib/
│   ├── services/              # Business logic (27 files)
│   │   ├── meme_service.rb
│   │   ├── meme_pool_manager.rb
│   │   ├── selection_benchmark.rb  # See "Selection Latency" below
│   │   ├── auth_service.rb
│   │   ├── redis_service.rb
│   │   └── ...
│   ├── helpers/               # View/route helpers
│   ├── concerns/               # Mixins
│   ├── middleware/             # Custom middleware
│   └── models/                 # Data models (minimal)
├── app/workers/                # Sidekiq background jobs (4 required by app.rb)
├── db/
│   ├── setup.rb                 # Database connection (hand-rolled DBWrapper, not an ORM)
│   └── migrations/
├── spec/                        # RSpec tests (57 files)
├── docs/archive/                # Historical/point-in-time reports - not guaranteed current
└── public/                      # Static assets (public/dist/bundle.js is a committed
                                  #   deploy artifact - see "Deployment" below)
```

---

## 🔄 REQUEST LIFECYCLE

```
Client → Puma → Rack::Attack (rate limiting)
                → Rack::CSRF (security)
                → RequestIdMiddleware (tracing)
                → RequestTimer (generic timing, /metrics)
                → Sinatra Router → Route Handler → Helpers → Service Layer
                → ERB Template → HTML/JSON Response → Client
```

Background jobs actually required by `app.rb`: `CacheRefreshWorker`,
`CachePreloadWorker`, `MemePoolMaintenanceWorker`, `DatabaseCleanupWorker`.
Check `config/sidekiq.yml` for the real current schedule rather than
trusting a fixed list here.

---

## 💾 THE CORE PRODUCT LOOP: `/random`

This is the one piece of this app worth understanding deeply - everything
else (leaderboard, blog, admin) is secondary to it.

```
1. User hits /random or /random.json
2. session_id resolved from session, falling back to request.ip if the
   session doesn't respond to .id (see routes/random_meme.rb - this used
   to crash with NoMethodError before a fix this session)
3. random_memes_pool (lib/helpers/meme_pool_helpers.rb) tries, in order:
   a. MemePoolManager.get_pool - Redis-backed, tier-distributed pool
   b. MEME_CACHE (legacy in-process fallback)
   c. On-demand Reddit fetch via InlineRedditFetcher, rate-limit-aware
      with a cooldown (this branch has a documented history of ~300ms
      latency even on failure - see the file's own "BUG FIX (rounds 3-5)"
      comments)
   d. Local YAML memes as the last resort
4. SimpleMemeSelector.select applies anti-repetition (avoids recently
   seen memes for this session, tracked via ViewingHistoryService)
5. View tracked in meme_stats
6. Response returned
```

Every step of 3 and 4 is timed by `SelectionBenchmark`
(`lib/services/selection_benchmark.rb`), broken into stages: `:total`,
`:pool_lookup`, `:pool_manager_lookup` (step 3a specifically),
`:reddit_fetch` (step 3c specifically), and `:selection` (step 4). Live
p50/p95/p99 per stage is visible at `/metrics` (admin-only) and
`/metrics.json`. **This is the actual, current source of truth for how
fast this app is** - not a number written into a doc.

---

## 🔧 KEY SERVICES

- **MemeService** - meme pool building, humor scoring, search
- **MemePoolManager** - Redis-backed, tier-distributed pool with an
  in-process fallback lock/bootstrap for when Redis is down. See its own
  extensive "BUG FIX (round N)" comments for the real history here.
- **SelectionBenchmark** - measures the core selection loop's latency,
  staged (see above). Deliberately narrow, not a generic APM tool.
- **TrendingService** - engagement score = (likes × 2) + views, with time
  decay and subreddit diversity
- **RedisService** - centralized cache access with a circuit breaker
  (`redis_available?`) and consistent fallback behavior

For the full, current list, read `lib/services/` directly - this section
deliberately doesn't enumerate all 27, because that list changes and a
partial list here would just be the next stale claim.

---

## 🔒 SECURITY LAYERS

1. **Input Validation** - `lib/validators.rb`
2. **CSRF Protection** - Rack::CSRF, token validation on POST/PUT/DELETE
3. **Rate Limiting** - Rack::Attack, Redis-backed (see
   `config/rack_attack.rb` for actual current limits)
4. **Session Security** - Secure cookies, Redis-backed session store
5. **SQL Injection Prevention** - Parameterized queries throughout

---

## 📈 SCALING: WHAT THIS APP ACTUALLY IS

This app runs as **one Puma worker**. That is a deliberate design choice
tied to the in-process `MEME_CACHE`, not a limitation waiting to be lifted.
Config files describing multi-region active-active replication, load
balancers, autoscaling, or PostgreSQL read replicas were removed from this
repo because they contradicted this reality and had zero code paths
actually using them. If real traffic ever demands horizontal scaling, that
work starts with solving the in-process cache assumption first - it is not
a config file away.

Concrete, current bottleneck candidates (informed by `SelectionBenchmark`,
not guessed): the on-demand Reddit fetch branch in `random_memes_pool`
(historically ~300ms per the code's own bug-fix comments) and the
multi-layer pool fallback chain generally. Read `/metrics` for the current
real numbers before proposing a fix to either.

---

## 🐛 ERROR HANDLING

```ruby
rescue => e
  AppLogger.error(...)      # always
  Sentry.capture_exception  # if configured
  # return a safe fallback - never a bare rescue that hides the failure
```

Prefer targeted rescues over bare `rescue => e` / `rescue nil` /
`rescue []` wherever the surrounding code can reasonably distinguish
"expected, recoverable" from "a real bug." Several bare rescues were
found and fixed this session (`lib/helpers/meme_pool_helpers.rb`,
`lib/services/meme_service.rb`) using a `safe_pool_query`/`safe_fetch`
pattern that preserves the same fallback behavior while actually logging
what went wrong.

---

## 📊 MONITORING

- `/health` - quick status
- `/metrics` - engagement stats + **selection latency breakdown**
  (admin-only, see the core product loop section above)
- `/metrics.json` - same data, JSON

Don't add a new ad-hoc metrics page for a new concern - extend `/metrics`
or add a stage to `SelectionBenchmark` if it's about the core loop.

---

## 🚀 DEPLOYMENT

**Environments:** SQLite (migration tooling only) or local PostgreSQL +
local Redis in development; PostgreSQL + Redis + Render.com in production.

**Deploy process (verified against `render.yaml` and `.github/workflows/`,
not assumed):**

There is exactly one CI workflow: `.github/workflows/ci.yml`. It runs
`bundle exec rspec` (test job) and `bundle audit check --update`
(security job) on every push/PR to `main`/`develop`. Its `lint` job is
currently disabled (commented out) because the `rubocop` gem isn't in
the Gemfile - see the comment in that file for what's needed to
re-enable it.

**Critically: CI passing does not gate deployment.** `render.yaml`'s
`buildCommand` is **just `bundle install`** - Render deploys directly
from a push to `main` regardless of whether CI has finished or passed.
That means:
- A red CI run does not stop a bad commit from reaching production.
  Don't push to `main` without running `bundle exec rspec` yourself
  first and confirming it's green.
- `npm run build` is never run automatically anywhere - not in CI, not
  by Render. `public/dist/bundle.js` is a **committed deploy artifact**,
  not disposable build output. If you change anything under
  `public/js/`, run `npm run build` locally and commit the resulting
  bundle, or production keeps serving the old one.

**Rollback:** via the Render dashboard (redeploy a previous commit). There
is no scripted rollback command in this repo.

---

## 📚 REFERENCES

- **Historical docs (not guaranteed current):** `docs/archive/`
- **Change history:** `CHANGELOG.md`
- **Security:** `SECURITY.md`
- **Contributing:** `CONTRIBUTING.md`

If a reference in this file points at a file that no longer exists,
that's a bug in this file - delete the reference rather than leave a
dead link.

---

**Keep this file honest:** every claim above was checked against the
actual repository, not carried forward from memory. If you're editing
code this file describes, update this file in the same PR.
