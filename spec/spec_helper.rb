# RSpec configuration for Meme Explorer
ENV["RACK_ENV"] = "test"

require "rspec"
require "rack/test"
require "json"
require "bcrypt"

# Code coverage
require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/migrations/"
  add_group "Routes",   "routes"
  add_group "Services", "lib/services"
  add_group "Helpers",  "lib/helpers"
  add_group "Workers",  "app/workers"
  minimum_coverage 70             # Enforced — no more "increase weekly" deferral
  minimum_coverage_by_file 30    # Every file must have at least some coverage
end

require_relative "../app"
require_relative "../db/setup"

# Require all services and validators
require_relative "../lib/services/user_service"
require_relative "../lib/services/auth_service"
require_relative "../lib/services/search_service"
require_relative "../lib/validators"
require_relative "../lib/models/user"

# WebMock for HTTP request mocking
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)

# Clean database before each test
RSpec.configure do |config|
  # ROADMAP.md Phase 2: real Stripe premium-tier columns
  # (db/migrations/add_premium_subscriptions.sql - additive/idempotent,
  # same pattern as the meme_activity_log/push_subscriptions tables
  # below). Run once per suite, not per-example like the table
  # cleanup below - ALTER TABLE ADD COLUMN IF NOT EXISTS is safe to
  # skip-if-present but still real DDL overhead not worth paying on
  # every single test. SubscriptionService.premium?/.migration_applied?
  # both fail safe to false without this having run at all, so specs
  # that don't care about premium status are unaffected either way -
  # this only makes the premium-specific specs
  # (spec/services/subscription_service_spec.rb,
  # spec/routes/premium_routes_spec.rb) actually exercise real behavior
  # instead of the "not migrated yet" fallback path.
  config.before(:suite) do
    begin
      DB.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255)")
      DB.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_subscription_id VARCHAR(255)")
      DB.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_status VARCHAR(50) DEFAULT 'none' NOT NULL")
      DB.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_current_period_end TIMESTAMP WITH TIME ZONE")
      DB.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS stripe_webhook_events (
          id SERIAL PRIMARY KEY,
          stripe_event_id VARCHAR(255) UNIQUE NOT NULL,
          event_type VARCHAR(100) NOT NULL,
          processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        )
      SQL
    rescue => e
      warn "[spec_helper] Premium subscription migration setup failed: #{e.message}"
    end
  end

  # Use color output
  config.color = true
  config.tty = true
  
  # Include Rack::Test helpers
  config.include Rack::Test::Methods
  
  # Define app for Rack::Test
  def app
    MemeExplorer::App
  end
  
  # Helper to get/set a fake pre-request session hash, usable BEFORE any
  # real request is made (e.g. `session[:user_id] = user_id` in a `before`
  # block, then `get '/profile'`).
  #
  # BUG FIX: the original version of this helper only ever read
  # `last_request.env['rack.session']`, which raises Rack::Test::Error
  # ("No request yet") the moment it's called before any request has been
  # issued - exactly the pattern used throughout
  # spec/routes/admin_routes_spec.rb and spec/routes/profile_routes_spec.rb
  # (`session[:user_id] = user_id` in a `before` block). Once a real
  # request DOES exist, Rack::Test's `env(name, value)` (used by
  # `set_session`) sets a header for the NEXT request, so writing directly
  # into `@rack_test_session` and passing it via `env 'rack.session', ...`
  # on every request keeps it working before AND after the first real
  # request, and keeps mutations (`session[:user_id] = x`) visible for
  # later reads within the same example without needing an intervening
  # request.
  # BUG FIX: a plain Hash doesn't respond to `.options`, but real
  # production sessions are Rack::Session::Abstract::SessionHash (or
  # similar), which does - routes/auth.rb's real login flow calls
  # `env['rack.session'].options[:renew] = true` to prevent session
  # fixation on login. A singleton method added via `define_singleton_method`
  # doesn't survive `Hash#dup` (and something in the Rack/Sinatra
  # middleware chain does dup the session at some point), so use a real
  # Hash subclass instead - subclass instance methods DO survive dup/clone,
  # unlike singleton methods on a literal Hash instance.
  class FakeSessionHash < Hash
    def options
      @options ||= {}
    end
  end

  def session
    @rack_test_session ||= FakeSessionHash.new
    # Register the SAME Hash object as the env's rack.session on every
    # access (not a copy) - Rack::Test's `env(name, value)` just stores it
    # for the next request without needing a prior one, and because it's
    # the same object reference, later in-place mutations
    # (`session[:user_id] = x`) are visible to whatever request eventually
    # reads `env['rack.session']`, with no extra sync step required.
    env 'rack.session', @rack_test_session
    @rack_test_session
  end

  # Helper to explicitly set the whole session hash (rarely needed
  # directly - prefer `session[:key] = value`, which now works standalone).
  def set_session(hash)
    @rack_test_session = FakeSessionHash.new.merge(hash)
    refresh_csrf_token
  end

  # Models loading a new page after login/logout or replacing the session.
  def refresh_csrf_token
    session['csrf'] ||= SecureRandom.hex(32)
    header 'X-CSRF-Token', session['csrf']
  end

  # Route specs mount Sinatra directly, outside config.ru's session store.
  # Model an ordinary same-session client; security rejection cases are tested
  # independently in tests/csrf_protection_test.rb with missing/forged tokens.
  config.before(:each) do
    refresh_csrf_token
    # Outage simulations can leave the service's 30-second circuit cache false
    # after RSpec restores method stubs. Probe independently in the next test.
    RedisService.refresh_availability! if defined?(RedisService)
  end
  
  # Helper to create test user
  def create_test_user(email = 'test@example.com', password = 'password123', admin = false)
    DB.execute("INSERT INTO users (email, password_hash, role, created_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
      [email, BCrypt::Password.create(password), admin ? 'admin' : 'user'])
    DB.get_first_value("SELECT id FROM users WHERE email = ?", [email])
  end
  
  # Mock external HTTP calls
  config.before(:each) do
    # Mock Reddit OAuth
    stub_request(:post, "https://www.reddit.com/api/v1/access_token")
      .to_return(
        status: 200,
        body: {access_token: "test_token", token_type: "bearer", expires_in: 3600}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
    
    # Mock Reddit API calls (oauth endpoint)
    stub_request(:get, /oauth\.reddit\.com/)
      .to_return(
        status: 200,
        body: {data: {children: []}}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
    
    # Mock Reddit subreddit JSON endpoints (for startup preload)
    stub_request(:get, %r{https://www\.reddit\.com/r/[^/]+/(top|hot|new)\.json})
      .to_return(
        status: 200,
        body: {data: {children: []}}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
  end
  
  # BUG FIX: this suite had no per-test Redis isolation at all - only SQL
  # tables were cleared between examples (below). Several real Redis-backed
  # pieces of app state persist across the whole test process as a result:
  # TrendingService.cached_trending's fixed cache keys ("trending:24h",
  # etc.) and SelectionBenchmark's rolling latency window
  # ("selection_benchmark:latencies_ms:*") both accumulate real values from
  # whatever spec file happened to run earlier in the same process,
  # producing genuine run-order-dependent flakiness (confirmed directly:
  # spec/routes/trending_routes_spec.rb, spec/services/selection_benchmark_spec.rb,
  # and spec/routes/metrics_routes_spec.rb all pass reliably alone, but
  # intermittently fail as part of the full suite depending on what ran
  # before them). Flushing just these known-volatile key patterns (rather
  # than the whole Redis DB, which could wipe unrelated app-level state a
  # future test might legitimately want to persist across steps within a
  # single example) gives every example a clean baseline without needing
  # each file to individually guess which keys some other file might have
  # left behind.
  config.before(:each) do
    if defined?(RedisService) && RedisService.redis_available?
      begin
        RedisService.clear_pattern('trending:*')
        RedisService.clear_pattern('selection_benchmark:*')
        RedisService.clear_pattern('signup_attempts:*')
        RedisService.clear_pattern('failed_login:*')
        RedisService.clear_pattern('account_lockout:*')
      rescue => e
        warn "Test Redis cleanup warning (non-fatal): #{e.message}"
      end
    end
  end

  # Clean up database between tests
  config.before(:each) do
    # Clear test database tables
    begin
      # Create meme_activity_log if it doesn't exist (PostgreSQL syntax)
      DB.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS meme_activity_log (
          id           SERIAL PRIMARY KEY,
          meme_url     TEXT NOT NULL,
          activity_type TEXT NOT NULL,
          user_id      INTEGER,
          session_id   TEXT,
          created_at   TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        )
      SQL

      # Create push_subscriptions table if it doesn't exist (PostgreSQL syntax)
      DB.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS push_subscriptions (
          id         SERIAL PRIMARY KEY,
          user_id    INTEGER NOT NULL,
          endpoint   TEXT NOT NULL,
          p256dh     TEXT NOT NULL,
          auth       TEXT NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        )
      SQL
      
      # Clean all tables
      DB.execute("DELETE FROM push_subscriptions") rescue nil
      DB.execute("DELETE FROM meme_activity_log") rescue nil
      DB.execute("DELETE FROM stripe_webhook_events") rescue nil
      DB.execute("DELETE FROM user_meme_stats") rescue nil
      DB.execute("DELETE FROM meme_impressions") rescue nil
      DB.execute("DELETE FROM meme_catalog") rescue nil
      DB.execute("DELETE FROM user_liked_memes") rescue nil
      DB.execute("DELETE FROM user_meme_exposure") rescue nil
      DB.execute("DELETE FROM user_subreddit_preferences") rescue nil
      DB.execute("DELETE FROM saved_memes") rescue nil
      DB.execute("DELETE FROM meme_stats")
      DB.execute("DELETE FROM broken_images") rescue nil
      DB.execute("DELETE FROM users")
    rescue PG::UndefinedTable, PG::Error => e
      # Tables might not exist yet in a fresh test DB — that is fine
      warn "Test setup warning (non-fatal): #{e.message}" unless e.message =~ /does not exist/
    rescue => e
      warn "Test setup unexpected error: #{e.class}: #{e.message}"
    end
  end

end
