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
  add_group "Routes", "routes"
  add_group "Services", "lib/services"
  add_group "Helpers", "lib/helpers"
  add_group "Workers", "app/workers"
  minimum_coverage 40  # Start with 40%, increase weekly
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
  # Use color output
  config.color = true
  config.tty = true
  
  # Include Rack::Test helpers
  config.include Rack::Test::Methods
  
  # Define app for Rack::Test
  def app
    MemeExplorer::App
  end
  
  # Helper to get Rack session
  def session
    last_request.env['rack.session'] if last_request
  end
  
  # Helper to set session for tests
  def set_session(hash)
    env 'rack.session', hash
  end
  
  # Helper to create test user
  def create_test_user(email = 'test@example.com', password = 'password123', admin = false)
    DB.execute("INSERT INTO users (email, password_hash, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
      [email, BCrypt::Password.create(password)])
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
  
  # Clean up database between tests
  config.before(:each) do
    # Clear test database tables
    begin
      # Create meme_activity_log if it doesn't exist
      DB.execute(<<-SQL)
        CREATE TABLE IF NOT EXISTS meme_activity_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          meme_url TEXT NOT NULL,
          activity_type TEXT NOT NULL,
          user_id INTEGER,
          session_id TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      SQL
      
      # Create push_subscriptions table if it doesn't exist
      DB.execute(<<-SQL)
        CREATE TABLE IF NOT EXISTS push_subscriptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          endpoint TEXT NOT NULL,
          p256dh TEXT NOT NULL,
          auth TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      SQL
      
      # Clean all tables
      DB.execute("DELETE FROM push_subscriptions") rescue nil
      DB.execute("DELETE FROM meme_activity_log") rescue nil
      DB.execute("DELETE FROM user_meme_stats") rescue nil
      DB.execute("DELETE FROM user_meme_exposure") rescue nil
      DB.execute("DELETE FROM user_subreddit_preferences") rescue nil
      DB.execute("DELETE FROM saved_memes") rescue nil
      DB.execute("DELETE FROM meme_stats")
      DB.execute("DELETE FROM broken_images") rescue nil
      DB.execute("DELETE FROM users")
    rescue => e
      # Tables might not exist yet, that's ok
      puts "⚠️  Test setup warning: #{e.message}" unless e.message =~ /no such table/
    end
  end
  
end
