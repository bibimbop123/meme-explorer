require './app'

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
