# RSpec configuration for Meme Explorer
ENV["RACK_ENV"] = "test"

require "rspec"
require "rack/test"
require_relative "../app"
require_relative "../db/setup"

# Clean database before each test
RSpec.configure do |config|
  # Use color output
  config.color = true
  config.tty = true
  
  # Include Rack::Test helpers
  config.include Rack::Test::Methods
  
  # Define app for Rack::Test
  def app
    MemeExplorer
  end
  
  # Clean up database between tests
  config.before(:each) do
    # Clear test database tables
    begin
      DB.execute("DELETE FROM user_meme_stats")
      DB.execute("DELETE FROM user_meme_exposure")
      DB.execute("DELETE FROM user_subreddit_preferences")
      DB.execute("DELETE FROM saved_memes")
      DB.execute("DELETE FROM meme_stats")
      DB.execute("DELETE FROM broken_images")
      DB.execute("DELETE FROM users")
    rescue => e
      # Tables might not exist yet, that's ok
    end
  end
  
end
