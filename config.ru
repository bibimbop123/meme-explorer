require './app'
require 'rack/session/redis'

# Configure session middleware BEFORE mounting the app
# Using Redis sessions to avoid 4K cookie limit (fixes OAuth state issues)
use Rack::Session::Redis,
  key: 'meme_explorer.session',
  redis_server: {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    namespace: 'session'
  },
  path: '/',
  httponly: true,
  same_site: :lax,
  secure: ENV['RACK_ENV'] == 'production',
  expire_after: 2_592_000, # 30 days
  secret: (ENV['SESSION_SECRET'] || begin
    # In development, use persistent secret file
    secret_file = File.join(Dir.pwd, '.session_secret')
    if File.exist?(secret_file)
      File.read(secret_file).strip
    else
      secret = SecureRandom.hex(32)
      File.write(secret_file, secret)
      secret
    end
  end)

# Session validation middleware - validates sessions on each request
require_relative 'lib/middleware/session_validator'
use SessionValidator

# Authorization middleware - protects routes based on permissions
require_relative 'lib/middleware/authorization'
use AuthorizationMiddleware

# Enable gzip compression for all responses (60-70% bandwidth savings!)
use Rack::Deflater

# Shared leases and rate-limit cooldowns survive deployments intentionally.
# Another web/worker process may still own them. Never clear them at startup;
# TTL handles crashed owners, and normal completion releases only its own token.

# Initialize meme pool cache on startup
# If Sidekiq is running, queue via worker. Otherwise let MemePoolManager's
# own coordinated get_pool path handle it on the first request - see
# lib/services/meme_pool_manager.rb#get_pool, which already runs the
# bootstrap in a background thread and rate-limit-checks itself.
#
# BUG FIX (Aug 25, 2026, round 4): this used to call
# InlineRedditFetcher.fetch directly - a THIRD independent, uncoordinated
# Reddit-fetch code path (alongside MemePoolManager's bootstrap and the
# on-demand fetch in meme_pool_helpers.rb#random_memes_pool), competing
# for the same rate-limited Reddit API with no shared cooldown awareness.
# Routing through MemePoolManager.get_pool means every fetch path shares
# the same lock/cooldown coordination instead of three systems
# independently hammering Reddit.
Thread.new do
  Thread.current.name = 'startup-cache-warm'
  sleep 1 # Brief pause to let the app fully initialize

  begin
    if defined?(MemePoolRefreshWorker) && defined?(Sidekiq)
      puts "🚀 [STARTUP] Triggering initial meme pool refresh via Sidekiq..."
      MemePoolRefreshWorker.perform_async(true)
      puts "✅ [STARTUP] Meme pool refresh job queued"
    else
      puts "🚀 [STARTUP] Warming meme pool via MemePoolManager (no Sidekiq)..."
      result = MemePoolManager.get_pool
      if result[:success]
        puts "✅ [STARTUP] Meme pool ready: #{result[:pool_size]} memes"
      else
        puts "⚠️  [STARTUP] Meme pool not ready yet (#{result[:error]}) — background bootstrap may still be running, will retry on first request"
      end
    end
  rescue => e
    puts "❌ [STARTUP] Cache warm failed: #{e.message}"
  end
end

# Mount Sidekiq Web UI with authentication (production only)
if ENV['RACK_ENV'] == 'production'
  begin
    require 'sidekiq/web'
    
    # Protect Sidekiq dashboard with basic auth
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      username == ENV['SIDEKIQ_USERNAME'] && password == ENV['SIDEKIQ_PASSWORD']
    end
    
    # Mount Sidekiq at /sidekiq
    map '/sidekiq' do
      run Sidekiq::Web
    end
    puts "✅ Sidekiq Web UI mounted at /sidekiq"
  rescue LoadError => e
    puts "⚠️  Sidekiq::Web not available: #{e.message}"
  end
end

# Mount main application
map '/' do
  run MemeExplorer::App
end
