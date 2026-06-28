# Meme Explorer — Engineering Roadmap
**Generated:** 2026-06-28 | **Audit Score:** 54/100 | **Target:** 80+/100

Sequenced by risk. Fix bugs before features. Every item has the exact file and line.

---

## Priority Legend
- P0 BLOCKING — silently broken right now
- P1 STRUCTURAL — will fail under load
- P2 HYGIENE — professional maintainability
- P3 TESTS — safety net for future changes
- P4 POLISH — only after P0-P3 done

## Score Projection
| Sprint | Score | What it unlocks |
|---|---|---|
| Now | 54/100 | — |
| Sprint 1 P0 | 65/100 | App is no longer silently broken |
| Sprint 2 P1 | 73/100 | Memory-safe under load |
| Sprint 3 P2 | 77/100 | Maintainable, professional repo |
| Sprint 4 P3 | 82/100 | Safe to ship new features |
| Sprint 5 P4 | 88/100 | Production-grade Sinatra app |

---

## SPRINT 1 — P0 Blocking Bugs · Est. 3-4 days

These are not improvements. They are active bugs causing silent failures right now.

### 1.1 P0 — Fix Double Session Middleware | app.rb:188-190
Two middlewares active simultaneously: enable :sessions (Sinatra) AND Rack::Session::Cookie (config.ru).
session[:user_id] reads from whichever lands on top. Auth is unreliable across environments.
DELETE these 3 lines from app.rb:
  enable :sessions
  set :session_expire_after, MemeExplorerConfig::SESSION_EXPIRE_AFTER
  set :cookie_options, MemeExplorerConfig::COOKIE_OPTIONS
config.ru already has the correct, secure session config (httponly/same_site/secure/SESSION_SECRET).

### 1.2 P0 — Delete Triplicate Route Definitions | app.rb:1053-1197, routes/memes.rb:11-68
GET "/" is defined 3 times. GET "/random" is defined 3 times.
Sinatra uses the LAST registered route. Route modules at lines 2074-2088 silently win.
Dead inline versions in app.rb still run analytics + initialize instance vars on every request.
Fix A: Delete app.rb lines 1053-1197 (both inline GET blocks).
Fix B: Delete GET "/random" from routes/memes.rb lines 11-68.
       routes/random_meme.rb is the single authoritative handler.

### 1.3 P0 — Fix DBWrapper#transaction Deadlock | db/setup.rb:73-84
transaction() checks out a pool connection then yields. The block calls DB.execute()
which calls @pool.with AGAIN on the same thread. With timeout:5 this raises
ConnectionPool::TimeoutError after 5s hang on ANY transactional code path.
Fix: use Thread.current[:db_connection] to reuse the checked-out connection:

  def transaction
    return yield if Thread.current[:db_connection]  # re-entrant safe
    @pool.with do |conn|
      Thread.current[:db_connection] = conn
      conn.exec('BEGIN')
      begin; yield; conn.exec('COMMIT')
      rescue => e; conn.exec('ROLLBACK'); raise e
      ensure; Thread.current[:db_connection] = nil
      end
    end
  end

  def execute(sql, params = [])
    sql, params = expand_array_params(sql, params)
    translated  = translate_sql(sql)
    conn = Thread.current[:db_connection]
    if conn
      conn.exec_params(translated, params).map { |row| row }
    else
      @pool.with { |c| c.exec_params(translated, params).map { |row| row } }
    end
  end

Apply the same Thread.current[:db_connection] reuse to get_first_value and last_insert_row_id.

### 1.4 P0 — Fix SQLite Syntax in PostgreSQL Queries | 7 locations
INSERT OR IGNORE and INSERT OR REPLACE are SQLite-only — they raise PG::SyntaxError.

  app.rb:836               -> INSERT INTO meme_stats ... ON CONFLICT(url) DO NOTHING
  app.rb:842               -> INSERT INTO user_meme_stats ... ON CONFLICT(user_id, meme_url) DO NOTHING
  lib/services/user_service.rb:52   -> INSERT INTO saved_memes ... ON CONFLICT(user_id, meme_url) DO NOTHING
  lib/services/meme_service.rb:264  -> INSERT INTO meme_stats ... ON CONFLICT(url) DO NOTHING
  lib/services/view_tracker_service.rb:245 -> DELETE this line, record_view_postgres() above it is correct
  lib/helpers/gamification_helpers.rb:322  -> ON CONFLICT(user_id, collection_id) DO UPDATE SET progress=EXCLUDED.progress
  lib/helpers/gamification_helpers.rb:334  -> Same ON CONFLICT pattern

Also add a safety net inside translate_sql() in db/setup.rb:
  sql = sql.gsub(/INSERT\s+OR\s+IGNORE\s+INTO/i, 'INSERT INTO')
  sql = sql.rstrip + ' ON CONFLICT DO NOTHING' if sql.match?(/INSERT\s+INTO/i) && !sql.match?(/ON\s+CONFLICT/i)
  raise ArgumentError, "INSERT OR REPLACE is SQLite-only" if sql.match?(/INSERT\s+OR\s+REPLACE/i)

### 1.5 P0 — Fix Routes::ABTesting | routes/ab_testing.rb, app.rb:2073
Bug 1: Mounted via `use` as Rack middleware — no access to parent app session/helpers.
       is_admin? calls User.find(session[:user_id]) on raw Rack env hash. Auth fails silently.
Bug 2: flash[:success]/flash[:error] used but sinatra-flash NOT in Gemfile.
       Raises NoMethodError, silently eaten by bare rescue in is_admin?.
Fix: Convert to standard Sinatra extension pattern:
  module Routes
    module ABTesting
      def self.registered(app)
        app.get '/admin/ab-testing' do
          halt 403, 'Forbidden' unless UserService.is_admin?(session[:user_id])
          @experiments = ABTestingService.list_experiments
          erb :'admin/ab_testing'
        end
        # All routes follow same pattern.
        # Replace flash[] with: redirect '/admin/ab-testing?notice=created'
      end
    end
  end
In app.rb:2073 change `use Routes::ABTesting` to `register Routes::ABTesting`.

---


## SPRINT 2 — P1 Structural Debt · Est. 3-4 days

These won't crash today but will cause hard failures under load.

### 2.1 P1 — Replace All Rogue Thread.new With ANALYTICS_POOL.post
4 production files still spawn raw unbounded threads — a memory bomb under concurrent load.

  lib/helpers/meme_helpers.rb:52         -> ANALYTICS_POOL.post { ... }
  routes/random_meme.rb:129              -> ANALYTICS_POOL.post { ... }
  lib/services/meme_pool_manager.rb:149  -> Concurrent::Future for fan-out:
    futures = tiers.map { |t, n| Concurrent::Future.execute { fetch_from_tier(t, n) } }
    results = futures.map { |f| f.value(30) || [] }
  lib/services/redis_service.rb:275      -> Named thread with abort_on_exception=false

### 2.2 P1 — Replace All puts With AppLogger
359 puts calls bypass AppLogger, cannot be silenced by LOG_LEVEL, corrupt JSON log streams.

  puts "..." info    -> AppLogger.info("message")
  puts "Error..."    -> AppLogger.error("message", error: e.message)
  puts "Warning..."  -> AppLogger.warn("message")
  puts "Debug..."    -> AppLogger.debug("message")
  puts e.backtrace   -> add backtrace: e.backtrace.first(5) to AppLogger.error context

Do file-by-file, not mass sed. Counts: app.rb(56), lib/(248), routes/(55). ~2 hours.

### 2.3 P1 — Replace rescue nil With Logged Handling
70 instances of bare `rescue nil` make bugs invisible.
Worst offender: ErrorHandler::Logger.log(...) rescue nil — silencing the error handler.

Rule: rescue nil is only OK when you have already logged the error.
  # BEFORE:
  DB.execute("INSERT INTO meme_stats ...") rescue nil
  # AFTER:
  rescue => e
    AppLogger.warn("meme_stats insert failed", error: e.message, url: identifier)

Note: `session[:user_id] rescue nil` — session cannot raise. Just write `session[:user_id]`.

### 2.4 P1 — Move require_relative Out of Route Handler Bodies
3 files call require_relative inside handler blocks (runs on every request).
Ruby caches the file but still acquires the global require mutex — lock contention.

  routes/random_meme.rb:21, 176, 272  -> move all 3 to top of file
  routes/trending_api.rb:45           -> move to top of file

### 2.5 P1 — Consolidate 3 Overlapping Constant Modules
MemeExplorerConfig, MemeExplorerConstants, AppConstants define overlapping constants
with different values (3 CACHE_TTL variants, 2 SESSION_* sets, etc.).

Merge into one module:
  module MemeExplorer
    module Config
      CACHE_TTL_SHORT   = ENV.fetch('CACHE_TTL_SHORT', 300).to_i
      CACHE_TTL_MEDIUM  = ENV.fetch('CACHE_TTL_MEDIUM', 1800).to_i
      CACHE_TTL_LONG    = ENV.fetch('CACHE_TTL_LONG', 3600).to_i
      # ... all constants in one place, all ENV-overridable
    end
  end
  # Backward-compat aliases until callsites updated:
  MemeExplorerConfig    = MemeExplorer::Config
  MemeExplorerConstants = MemeExplorer::Config
  AppConstants          = MemeExplorer::Config

---

## SPRINT 3 — P2 Hygiene · Est. 1-2 days

### 3.1 P2 — Nuke the Backups Directory (18 dirs committed to git)
  git rm -r backups/
  echo 'backups/' >> .gitignore && echo '*.backup' >> .gitignore
  git commit -m "chore: remove backup dirs — use git history instead"

### 3.2 P2 — Delete Dead Service Files
  git rm lib/services/random_selector_service_BACKUP.rb.deprecated
  git rm lib/services/random_selector_service_v2.rb
  git rm routes/reactions_v2.rb  (defines rogue MemeExplorer class, never mounted)
Before deleting: grep -rn 'random_selector_service_v2' . --include='*.rb'

### 3.3 P2 — Consolidate 7 Competing Meme-Selection Services
  random_selector_service.rb    -> KEEP (primary, tested)
  random_selector_service_v2.rb -> DELETE (see 3.2)
  enhanced_random_selector.rb   -> AUDIT then merge unique logic or delete
  meme_selection_service.rb     -> AUDIT then merge unique logic or delete
  meme_pool_manager.rb          -> KEEP (manages pool, different responsibility)
  smart_pools_service.rb        -> AUDIT then merge or delete
  diversity_engine_service.rb   -> KEEP (actively used in routes/random_meme.rb)

### 3.4 P2 — Fix .gitignore for Runtime Artifacts
Add: db/*.db, tmp/, log/*.log, .session_secret, .env.production, backups/, coverage/

### 3.5 P2 — Fix the Gemfile
  sqlite3 -> move to group :development (not needed in production)
  gem "thread" -> DELETE (Thread/Mutex/Queue are Ruby core, not a gem)
  gem "ostruct" -> DELETE or move to dev
  gem "whenever" -> DELETE (sidekiq-scheduler already handles scheduling via sidekiq.yml)

### 3.6 P2 — Replace $start_time Global Variable
  app.rb: $start_time = Time.now  ->  MemeExplorer::START_TIME = Time.now.freeze
  Update 6 callsites: app.rb, routes/health.rb, lib/services/health_check_service.rb

### 3.7 P2 — Fix Reddit User-Agent Placeholder
  app.rb:372: "MemeExplorer/1.0 (by YourRedditUsername)"  <- violates Reddit ToS
  Fix: "MemeExplorer/1.0 (by \#{ENV.fetch('REDDIT_USERNAME', 'meme-explorer-bot')})"
  Add REDDIT_USERNAME to .env.example and production env.

### 3.8 P2 — Add a Simple Migration Runner (Rakefile)
29 SQL files in db/migrations/ with no runner or version tracking.
Add Rakefile with db:migrate task that:
  1. Creates a schema_migrations table (version VARCHAR PRIMARY KEY)
  2. Sorts files by filename prefix (rename files with YYYYMMDD_ timestamps)
  3. Runs each unapplied file and records its version
  ~50 lines of plain Ruby. No framework needed.

---

## SPRINT 4 — P3 Test Coverage · Est. 1 week

### 4.1 P3 — Fix Test DB Setup (SQLite Syntax in PostgreSQL Tests)
spec/spec_helper.rb:100-120 uses `AUTOINCREMENT` (SQLite-only) in CREATE TABLE.
Replace with SERIAL PRIMARY KEY for PostgreSQL throughout spec_helper.rb.

### 4.2 P3 — Raise Coverage Minimum to 70%
spec/spec_helper.rb: minimum_coverage 40  ->  minimum_coverage 70
The "increase weekly" comment is months old. Enforce it now.
Also add: minimum_coverage_by_file 40

### 4.3 P3 — Replace All TODO Worker Specs With Real Assertions
Every worker spec has 4 identical TODO comments and zero assertions.
Each worker needs minimum 3 tests:
  (a) performs without raising
  (b) handles primary failure (API down, Redis unavailable)
  (c) verifies primary side effect (cache populated, row inserted, etc.)

Priority order:
  CacheRefreshWorker           -> verify MEME_CACHE[:memes] populated after perform
  ImageHealthWorker            -> verify broken images are blacklisted
  DatabaseCleanupWorker        -> verify old rows are deleted
  LeaderboardCalculationWorker -> verify scores computed and stored
  SessionCleanupWorker         -> verify expired sessions removed

### 4.4 P3 — Add Integration Tests for Route Registration
  GET /              -> 200, renders meme viewer
  GET /random        -> 200, renders meme viewer
  GET /              returns same template as GET /random (not two different pages)
  GET /admin/*       -> 403 without admin session
  Session persists:  POST /login -> GET / -> session[:user_id] present

### 4.5 P3 — Add Regression Tests for Each Sprint 1 Fix
One test per P0 bug that would have caught it:
  1.1: session[:user_id] persists across 3 sequential requests
  1.2: No duplicate route warnings in log on startup
  1.3: DB.transaction { DB.execute("SELECT 1") } does not raise or timeout
  1.4: grep confirms no INSERT OR IGNORE/REPLACE in production *.rb files
  1.5: GET /admin/ab-testing returns 403 for non-admin (not 500 NoMethodError)

---

## SPRINT 5 — P4 Polish · Only after P0-P3 complete

### 5.1 P4 — Add current_user Helper and require_auth! Macro
347 raw session[:user_id] checks scattered everywhere. Centralize in AuthHelpers:
  module AuthHelpers
    def current_user
      return nil unless session[:user_id]
      @current_user ||= UserService.find_by_id(session[:user_id].to_i)
    end
    def logged_in?; !current_user.nil?; end
    def require_auth!
      unless logged_in?
        if request.xhr? || request.accept.include?('application/json')
          halt 401, { error: 'Authentication required' }.to_json
        else
          session[:return_to] = request.path
          redirect '/login'
        end
      end
    end
    def require_admin!
      require_auth!
      halt 403, 'Forbidden' unless UserService.is_admin?(current_user['id'])
    end
  end
Register in app.rb: helpers AuthHelpers
Replace all `if session[:user_id]` guards with require_auth!

### 5.2 P4 — Reduce app.rb to Under 200 Lines
Move all business logic into route modules and helpers.
app.rb should only: configure middleware, register helpers, register route modules.
Target structure:
  require_relative 'config/boot'
  module MemeExplorer
    class App < Sinatra::Base
      configure { ... }    # ~20 lines
      use RequestIdMiddleware, RequestTimer, SecurityHeaders, Rack::Attack, Rack::CSRF
      helpers MemeHelpers, AuthHelpers, GamificationHelpers, AdHelpers, SeoHelpers
      before { ... }       # ~15 lines
      after  { ... }       # ~10 lines
      get '/ads.txt' do ... end
      get '/adsense-verification' do ... end
      require_relative 'config/routes'
    end
  end

### 5.3 P4 — Remove Inline Rack::Attack Config From app.rb
config/rack_attack.rb already has the correct comprehensive config (per-endpoint limits,
proper retry headers, safelist for assets). app.rb:128-136 has a conflicting simpler version.
Delete the inline version. Add: require_relative './config/rack_attack' to app.rb.

### 5.4 P4 — Standardize Auth Pattern Across All Route Modules
Three incompatible auth patterns currently exist:
  halt 403 unless session[:user_id]            (most routes)
  halt 403 unless UserService.is_admin?()      (admin_routes)
  halt 403 unless is_admin?                    (ab_testing — broken)
After 5.1 is done, replace ALL with require_auth! and require_admin!.
Zero raw session[:user_id] checks should remain in routes/*.rb.

---

## Quick Reference — Files Changed Per Sprint

| Sprint | Primary Files |
|---|---|
| 1 P0 | app.rb, db/setup.rb, routes/memes.rb, routes/ab_testing.rb, lib/services/user_service.rb, lib/services/meme_service.rb, lib/helpers/gamification_helpers.rb |
| 2 P1 | lib/helpers/meme_helpers.rb, routes/random_meme.rb, lib/services/meme_pool_manager.rb, lib/services/redis_service.rb, config/app_constants.rb, all files with puts/rescue nil |
| 3 P2 | .gitignore, Gemfile, Rakefile (new), lib/services/ (deletions), app.rb ($start_time) |
| 4 P3 | spec/spec_helper.rb, all spec/workers/*_spec.rb, new integration + regression specs |
| 5 P4 | lib/helpers/auth_helpers.rb (new), app.rb (shrink to 200 lines), all route files |

---

## Definition of Done Per Sprint

Sprint 1 DONE when:
  [ ] POST /login then GET /profile — session[:user_id] persists (no double-session)
  [ ] GET / returns 200 with no duplicate route warnings
  [ ] DB.transaction { DB.execute("SELECT 1") } does not raise
  [ ] grep for INSERT OR IGNORE/REPLACE in lib/ routes/ app.rb returns zero
  [ ] GET /admin/ab-testing returns 403 for non-admin (not 500)

Sprint 2 DONE when:
  [ ] grep -r 'Thread.new' lib/ routes/ app.rb = zero results
  [ ] grep -r 'puts ' lib/ routes/ app.rb = zero results
  [ ] grep -r 'rescue nil' lib/ routes/ app.rb = zero results
  [ ] All require_relative at file top level (not inside def/do blocks)
  [ ] One canonical MemeExplorer::Config module, old module names are aliases

Sprint 3 DONE when:
  [ ] ls backups/ = empty or removed
  [ ] git ls-files db/*.db = empty
  [ ] bundle exec rake db:status runs without error, all migrations applied
  [ ] bundle install with no sqlite3/thread/whenever in production Gemfile group

Sprint 4 DONE when:
  [ ] bundle exec rspec passes with coverage >= 70%
  [ ] Zero TODO comments in spec/workers/
  [ ] All 5 P0 regression tests pass

Sprint 5 DONE when:
  [ ] wc -l app.rb < 200
  [ ] grep -r 'session\[:user_id\]' routes/ = zero results
  [ ] Single Rack::Attack config in config/rack_attack.rb, none inline in app.rb
