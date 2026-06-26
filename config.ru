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
begin
  if defined?(MemePoolRefreshWorker) && defined?(Sidekiq)
    puts "🚀 [STARTUP] Triggering initial meme pool refresh..."
    MemePoolRefreshWorker.perform_async(true)  # Force refresh on startup
    puts "✅ [STARTUP] Meme pool refresh job queued"
  else
    puts "⚠️  [STARTUP] MemePoolRefreshWorker or Sidekiq not available - cache will be empty until first refresh"
  end
rescue => e
  puts "❌ [STARTUP] Failed to queue meme pool refresh: #{e.message}"
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
