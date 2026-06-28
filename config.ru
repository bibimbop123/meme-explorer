require './app'

# Configure session middleware BEFORE mounting the app
use Rack::Session::Cookie,
  key: 'meme_explorer.session',
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
