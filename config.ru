require './app'
require 'rack/session/redis'

# Configure session middleware BEFORE mounting the app
# SWITCHED FROM COOKIES TO REDIS (fixes "session dropped" error for large histories)
use Rack::Session::Redis,
  redis_server: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  key: 'meme_explorer.session',
  expire_after: 7200, # 2 hours (was 30 days, but Redis session storage is more flexible)
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

# Enable gzip compression for all responses (60-70% bandwidth savings!)
use Rack::Deflater

# Initialize meme pool cache on startup
# If Sidekiq is running, queue via worker. Otherwise fetch directly via OAuth.
Thread.new do
  Thread.current.name = 'startup-cache-warm'
  sleep 1 # Brief pause to let the app fully initialize

  begin
    cache = MemeExplorer::App::MEME_CACHE

    if defined?(MemePoolRefreshWorker) && defined?(Sidekiq)
      puts "🚀 [STARTUP] Triggering initial meme pool refresh via Sidekiq..."
      MemePoolRefreshWorker.perform_async(true)
      puts "✅ [STARTUP] Meme pool refresh job queued"
    else
      # No Sidekiq — fetch directly from Reddit using OAuth (client credentials)
      puts "🚀 [STARTUP] Fetching memes directly from Reddit (no Sidekiq)..."
      subreddits = MemeExplorer::App::POPULAR_SUBREDDITS.sample(20)
      memes = InlineRedditFetcher.fetch(subreddits, limit: 25)

      if memes.any?
        cache.set(:memes, memes.shuffle)
        cache.set(:last_refresh, Time.now)
        puts "✅ [STARTUP] Meme cache warmed: #{memes.size} memes from Reddit"
      else
        puts "⚠️  [STARTUP] Reddit fetch returned 0 memes — will retry on first request"
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
