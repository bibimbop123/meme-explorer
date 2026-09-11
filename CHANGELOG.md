# Changelog

All notable changes to Meme Explorer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `SelectionBenchmark` (`lib/services/selection_benchmark.rb`): measures the
  core "pick this person their next meme" loop end-to-end on every real
  `/random` and `/random.json` request, broken into stages (`:total`,
  `:pool_lookup`, `:pool_manager_lookup`, `:reddit_fetch`, `:selection`).
  Live p50/p95/p99 per stage now visible on `/metrics` and `/metrics.json`.
- Full test coverage for the above: unit tests for percentile math and
  stage isolation, an integration test proving the wiring actually fires
  on real requests, a report spec comparing an empty-pool vs. warm-pool
  scenario, a forced-slow-path test proving a simulated 50ms network
  delay is attributed to the correct stage and not others, and the
  first-ever spec coverage of the `/metrics` and `/metrics.json` routes.
- Dark mode with system preference detection and manual toggle (Cmd+K)
- PWA install capability with offline support
- Comprehensive video playback (MP4, WebM, MOV, Reddit videos)
- Full video error handling with fallback UI
- Mobile-optimized video playback (max-height 60vh)
- .editorconfig for consistent code formatting
- SECURITY.md for vulnerability disclosure
- Enhanced .env.example documentation

### Fixed
- `.github/workflows/ci.yml`'s `test` job's "Set up database" step called
  `bundle exec ruby scripts/setup_database.rb`, a script that doesn't
  exist - meaning this step had been failing on every push/PR. Fixed to
  `ruby db/setup.rb`, verified working locally.
- `.github/workflows/ci.yml`'s `lint` job called `bundle exec rubocop`,
  but the `rubocop` gem isn't in the Gemfile - failing on every push/PR.
  Disabled with a comment explaining what's needed to re-enable it,
  rather than leaving it permanently red.
- Removed `.github/workflows/tests.yml`, a redundant second CI workflow
  whose "Set up test database" step tried to use SQLite against
  `db/setup.rb`, which only ever connects via `PG.connect` (PostgreSQL) -
  this workflow could never have actually worked. `ci.yml`'s `test` job
  already covers this with a real Postgres service container.
- `.overcommit.yml` enabled `RuboCop` (pre-commit) and `Brakeman`
  (pre-push) hooks for gems that aren't in the Gemfile - anyone who
  actually followed this file's own install instructions
  (`gem install overcommit && overcommit --install`) would have every
  commit and push fail immediately. Disabled both with a comment
  explaining what's needed to re-enable them.
- Removed 13 dead files from `lib/middleware/` (`admin_ip_whitelist.rb`,
  `advanced_rate_limiter.rb`, `health_check_middleware.rb`, `http_cache.rb`,
  `load_distributor.rb` - more of the multi-worker/horizontal-scaling
  fantasy this session already removed elsewhere, `performance_monitor.rb`,
  `performance_monitoring_middleware.rb`, `prometheus_exporter.rb` -
  requires the `prometheus-client` gem, absent from the Gemfile,
  `rate_limiter.rb`, `redis_health_check.rb`, `static_assets_cache.rb`)
  and 10 dead files from `lib/services/` (`adaptive_rate_limiter.rb`,
  `authorization_service.rb`, `circuit_breaker.rb`, `http_connection_pool.rb`,
  `image_fallback_service.rb`, `media_handling_service.rb`, `meme_pool.rb`
  - distinct from and not to be confused with the real, active
  `meme_pool_manager.rb`, `quality_filter_service.rb`, `reactions_service.rb`,
  `token_bucket_limiter.rb`) - none required by `app.rb`, `config.ru`, or
  any route/lib file. Also cleaned up two more untracked, never-committed
  stray files found alongside them (`lib/middleware/error_handler_v2.rb`,
  `lib/middleware/security_headers_v2.rb`), matching the same pattern as
  the untracked `cdn_helpers_v2.rb` found earlier.
  **Caught and fixed a real mistake during this pass:** initially also
  deleted `lib/services/search_service.rb`, which - unlike everything
  else in this batch - genuinely IS required, directly by
  `spec/spec_helper.rb` (loaded by every single spec run). My grep check
  for this batch only covered `app.rb`/`config.ru`/`routes/`/`lib/`/`app/`
  and missed `spec/spec_helper.rb` as a real require path. Restored the
  file immediately via `git checkout HEAD --`, verified `spec_helper.rb`
  loads correctly again, and re-checked every other file in this batch
  specifically against `spec_helper.rb` and all spec files before
  finalizing - none of the others were actually required anywhere.
- Removed 4 completely dead, unscheduled Sidekiq workers:
  `app/workers/daily_challenge_worker.rb`, `meme_stats_writer.rb`,
  `ml_model_training_worker.rb`, `predictive_cache_worker.rb` - none
  required by `app.rb`, none scheduled in `config/sidekiq.yml`, none
  referenced anywhere else (the one apparent reference,
  `MemeStatsWriter.perform_async` in `lib/controllers/random_meme_controller.rb`,
  is itself inside a `defined?` guard in a controller that isn't wired
  into the live app - see next entry).
- Documented (not deleted) `lib/controllers/random_meme_controller.rb`:
  discovered it is fully implemented and well-tested
  (`spec/controllers/random_meme_controller_spec.rb`,
  `spec/integration/random_algorithm_integration_spec.rb`, both passing)
  but genuinely never required by `app.rb` - the live `/random` and
  `/random.json` routes (`routes/random_meme.rb`) implement selection
  logic inline instead of calling `RandomMemeController.handle`. Added a
  clear `STATUS` comment to the class instead of removing it, since it's
  a real, working candidate for a future refactor, not dead weight.
  Moved `docs/README_ALGORITHM_SECTION.md` and `docs/RANDOM_ALGORITHM.md`
  to `docs/archive/` - both described this controller as the current,
  active architecture, which it isn't.
- Removed 10 dead files from `lib/concerns/` (`cache_strategy.rb`,
  `csrf_protection.rb`, `enhanced_session_security.rb`, `error_handler.rb`
  - a dead duplicate of the real, required `lib/error_handler.rb`,
  `query_optimizer.rb`, `query_timeout.rb`, `standardized_error_handling.rb`,
  `stateless_sessions.rb`, `thread_safe_metrics.rb`, `transaction_wrapper.rb`)
  and its now-orphaned spec (`spec/concerns/transaction_wrapper_spec.rb`,
  which was already failing pre-existing on `main`). Verified the two
  real files in this directory that `app.rb` genuinely requires
  (`http_caching.rb`, `performance_profiler.rb`) plus `distributed_lock.rb`
  (required transitively via `cache_refresh_worker.rb`) were left untouched.
- Removed 19 dead files from `lib/helpers/` (`analytics_tracking.rb`,
  `api_response_helpers.rb`, `cdn_integration_helper.rb`,
  `inline_script_extractor.rb`, `input_validation.rb`, `og_tags_helper.rb`,
  `performance_helpers.rb`, `query_timeout_helpers.rb`,
  `redis_monitoring_helper.rb`, `redis_resilience.rb`,
  `responsive_image_helper.rb`, `schema_helpers.rb`,
  `search_optimization_helpers.rb`, `service_merger.rb`,
  `session_optimizer.rb`, `stories_share_helper.rb`,
  `trending_cache_helper.rb`, `type_safety.rb`, `transaction_wrapper.rb`)
  plus one untracked file found alongside them (`cdn_helpers_v2.rb`,
  never committed to git, also unreferenced) - none required by `app.rb`
  or by anything `app.rb` requires. Verified with a full-suite run before
  and after (via `git stash`): baseline `main` was already at 659
  examples / 254 failures before any of this session's changes; after
  every deletion across this whole session, 657 examples / 237 failures
  - fewer failures, not more, confirming zero regressions (the removed
  `transaction_wrapper_spec.rb` was itself one of the pre-existing
  failures). Full app boot verified clean throughout.
- Removed a dangerous, never-loaded duplicate:
  `config/initializers/bounded_thread_pools.rb` redefined `REDIS_POOL` as
  a `Concurrent::FixedThreadPool` - completely incompatible with the
  real, active `REDIS_POOL` (a `ConnectionPool` of actual Redis
  connections, defined in `config/initializers/redis_cluster.rb`, which
  *is* required by `app.rb`). If anyone had ever required this file,
  every `RedisService` call in the app would have broken immediately.
  Verified post-removal that `REDIS_POOL` is still the correct
  `ConnectionPool` class at boot. Also removed the redundant
  `ANALYTICS_POOL`/`MEME_FETCH_POOL` definitions in the same file - the
  real ones live in `config/initializers/thread_pool.rb`, which *is*
  required.
- Removed `config/initializers/opentelemetry.rb` - requires the
  `opentelemetry-sdk` gem family, none of which is in the Gemfile; would
  raise `LoadError` immediately if ever required. Never actually
  required anywhere.
- Removed the entire dead read-replica subsystem:
  `config/initializers/database_replicas.rb`,
  `lib/concerns/database_router.rb`, and `scripts/monitor_replica_lag.rb`
  - these three files only ever referenced each other (`DatabaseRouter`,
  `DB_REPLICA`), none is required by `app.rb`, and this is the same
  "app doesn't run this way" infrastructure already removed once this
  session (`config/database_replica.yml`, `lib/concerns/database_failover.rb`).
- Removed `config/app_config.rb` (an `AppConfig` constants module,
  duplicating `config/app_constants.rb` which *is* actually required)
  along with the three helper files that were its only referrers -
  `lib/helpers/standard_error_handling.rb`,
  `lib/helpers/admin_rate_limiter.rb`, `lib/helpers/timezone_helper.rb` -
  none of which is required by `app.rb` or anything `app.rb` requires.
  An entire small cluster of mutually-referencing but completely
  unloaded code.
- Removed `config/algorithm_config.yml` - a detailed scoring config
  (streak bonuses, freshness multipliers, viral thresholds, time-of-day
  boosts, preference decay, cold-start strategy) for the old, complex
  meme-selection algorithm that `SimpleMemeSelector` deliberately
  replaced ("2,500+ lines... reduced to 50 clean lines" per that file's
  own header). Zero references anywhere - the algorithm it configured no
  longer exists.
- Removed `config/ad_placements.yml` - an ad-placement/experiment config
  with zero references anywhere; the real, active ad system is
  `AdHelpers`/`public/js/ad-manager.js`, neither of which reads this file.
- Removed `config/curator_notes.yml` - zero references anywhere.
- Removed `config/curated_collections.yml` - initially looked real (a
  broad grep for `collection_name_for_subreddit` matched files that also
  happened to define that method), but a closer read of
  `lib/helpers/app_helpers.rb` showed `collection_name_for_subreddit`
  and `generate_curation_signal` are hardcoded stub replacements for a
  `CuratedCollectionsHelper` class already removed in a prior cleanup -
  neither stub reads this YAML file at all. Verified both stubs still
  work correctly after removal (`collection_name_for_subreddit('funny')`
  → `"Funny"`, `generate_curation_signal({})` → the expected default
  signal hash).
- Removed `config/storage.yml` (AWS S3 config) and
  `config/social_integrations.yml` (a one-line "to be implemented" stub)
  - zero references anywhere, no `aws-sdk` gem in the Gemfile; this app
    serves images directly from Reddit URLs and `public/images/`, never
    uploads to S3.
- Trimmed `config/features.yml` from ~20 feature flags down to the one
  (`gamification.features.leaderboards`) actually read anywhere -
  verified by grepping every `FeatureFlags.enabled?(...)`/`.get(...)`
  call site (`lib/feature_flags.rb` is genuinely used, required by
  `app.rb`, and `views/partials/_simplified_nav.erb` really does check
  that one key to gate the leaderboard nav link). The other ~19 flags
  (streaks, xp_system, achievements, sound_effects, meme_battles,
  near_miss_mechanics, etc.) described a much larger gamification system
  whose routes/services/CSS were already removed in a prior cleanup,
  leaving only the flags themselves stale. Also removed
  `lib/helpers/progressive_disclosure_helper.rb`, which read several of
  those dead flags but was required in `app.rb` without ever being
  registered as a Sinatra `helpers` module - its `show_feature?`/
  `show_gamification_tier` methods would have raised `NoMethodError`
  if any view had actually tried to call them, and none did. Verified
  `FeatureFlags.enabled?('gamification.features.leaderboards')` still
  returns `true` and the home page still renders correctly after the trim.
- Removed `config/database.yml`, `config/session.rb`, and
  `config/initializers/session_store.rb` - three dead config files never
  required anywhere. The real session config lives inline in
  `config.ru` (`Rack::Session::Redis` with cookie name
  `meme_explorer.session`, `same_site: :lax`, 30-day expiry) - verified
  by hitting a real request through the actual `config.ru` boot path and
  confirming that exact cookie is set. Both dead files described
  *different, contradictory* session settings (different cookie names,
  one used `same_site: :strict` instead of `:lax`) that were never
  active, and `config/database.yml` described an ActiveRecord-style
  multi-variable connection scheme (`DATABASE_HOST`/`DATABASE_USER`/etc.)
  that doesn't match `db/setup.rb`'s actual single `DATABASE_URL` via
  `PG.connect`.
- `Procfile` gave no indication that it's effectively unused on this
  app's actual deploy target - `render.yaml` defines its own
  `startCommand` for both services, which takes priority over `Procfile`
  on Render. Added a comment clarifying that deploy command changes
  belong in `render.yaml`, not here.
- `.env.example` described the database as "SQLite - current" with
  PostgreSQL "uncomment after migration" - backwards from reality;
  `db/setup.rb` connects exclusively via `PG.connect(DATABASE_URL)` with
  no SQLite runtime path at all. Also had `WEB_CONCURRENCY=1` (would
  enable Puma cluster mode, breaking the in-process `MEME_CACHE` this
  app's single-worker design depends on - see `config/puma.rb`) and
  `RAILS_MAX_THREADS=5` (real default is 32). Fixed all three, and
  clarified that the Stripe env vars and feature-flag vars listed here
  don't correspond to any actual integration code yet (`stripe` gem is
  in the Gemfile, but there are no payment routes or webhook handlers).
- Removed `.simplecov` - a second, dead `SimpleCov.start` config block
  (40%/20% coverage thresholds) that directly contradicted the one
  actually in effect (`spec/spec_helper.rb`, 70%/30%, confirmed live by
  every coverage-gate failure message throughout this project's test
  runs). SimpleCov only honors the first `.start` call it sees;
  `spec_helper.rb`'s `require "simplecov"; SimpleCov.start` runs first
  via `.rspec`'s `--require spec_helper`, so `.simplecov` was silently
  never read - kept around only as a confusing, wrong second source of
  truth for anyone who went looking for the coverage config.
- `session_id = session[:session_id] || session.id || ...` crashed with
  `NoMethodError` whenever `session` didn't respond to `.id` (e.g. no Rack
  session cookie established yet) - hit on every `/random` and
  `/random.json` request without one. Guarded with `respond_to?(:id)`.
  This was the root cause of 5 previously-failing specs in
  `spec/routes/random_spec.rb`, now passing.
- Removed 9 JS files (`dark-mode.js`, `error-handler.js`, `web-vitals.js`,
  `ad-manager.js`, `ad-lazy-load.js`, `trending.js`,
  `progressive-disclosure.js`, `enhanced-lazy-load.js`,
  `keyboard-navigation.js`, `mobile-swipe.js`) that were loaded BOTH via
  a standalone `<script>` tag AND bundled into `public/dist/bundle.js`,
  causing every page load to run each of them twice - double error
  reporting to Sentry, double keydown listeners on j/k/l/s/?/Esc, double
  swipe handlers, etc. Same bug class as a prior fix for `ad-manager.js`
  on the trending page specifically.
- Removed 21 stray `.backup*`/`.new` files that had been committed to git
  instead of relying on git history.
- Removed 88 dead hand-minified `.min.js`/`.min.js.gz` files (and the
  unused `AssetOptimizer` module that generated them) left over from a
  competing minification pipeline that was superseded by Vite but never
  cleaned up.
- Removed config files describing infrastructure this app doesn't run
  (multi-region active-active replication, load balancer, autoscaling,
  a Sequel-style DB read-replica setup this app's hand-rolled `DBWrapper`
  doesn't use) - contradicted `config/puma.rb`'s own single-worker design
  and had zero callers anywhere in the codebase.
- Consolidated duplicated ~40-line response-building logic across
  `/random.json` and `/similar.json` into shared helpers in
  `routes/random_meme.rb`.
- Replaced silent `rescue []` / `rescue nil` modifiers in
  `lib/helpers/meme_pool_helpers.rb` and `lib/services/meme_service.rb`
  with a `safe_pool_query`/`safe_fetch` pattern that preserves the same
  fallback behavior but actually logs the failure (and reports to Sentry)
  instead of hiding it.
- Redis thread leak prevention (critical memory issue)
- Hardcoded admin email removed (security vulnerability)
- N+1 query optimizations across services
- Mobile touch targets enlarged to 48px+ (accessibility)
- Duplicate OG meta tags removed (SEO)
- 22 broad rescue clauses replaced with specific error handling
- ARIA labels added for screen readers (WCAG 2.1 Level AA)

### Changed
- Extracted push notification registration/UI (~140 lines of inline
  `<script>`) out of `views/layout.erb` into `public/js/push-notifications.js`,
  following the existing "inline config + external script" pattern already
  used for `ad-manager.js`.
- Removed dead gamification CSS (`.streak-badge`, `.level-up-modal`, etc.)
  from `layout.erb` and the orphaned `_progressive_gamification.erb`
  partial it styled - neither was rendered anywhere.
- Restored two fully-implemented but accidentally-disabled routes
  (`Routes::PersonalizationRoutes`, `Routes::Blog`) that were commented
  out of `app.rb`'s registration block with an incorrect "file not found"
  annotation.
- `README.md` rewritten to describe only what's actually registered in
  `app.rb`, with fabricated performance numbers ("Average Response Time
  <200ms", "P95 <500ms") replaced by a pointer to the real, live
  `SelectionBenchmark` data at `/metrics`.
- 22 stale, point-in-time status/audit markdown files moved from the repo
  root into `docs/archive/`.
- Database queries now 30-50% faster with critical indexes
- Centralized logging with AppLogger
- Connection pooling for Redis and PostgreSQL
- All `puts` replaced with proper logging
- Improved error boundaries with detailed logging

### Security
- RBAC properly implemented for admin access
- CSP headers configured correctly
- CSRF protection enabled
- OAuth flow secured
- Session management hardened

## [1.0.0] - 2026-07-20

### Added
- Initial production release
- Reddit meme integration
- User authentication with OAuth
- Gamification system (streaks, levels, XP)
- Leaderboard functionality
- Push notifications for streaks
- Search and trending features
- Mobile-responsive design
- AdSense integration
- Comprehensive testing suite

---

**Legend:**
- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for removed features
- `Fixed` for bug fixes
- `Security` for vulnerability fixes
