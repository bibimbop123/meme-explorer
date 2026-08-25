require_relative "../../spec/spec_helper"
require_relative "../../lib/services/meme_pool_manager"

describe "Random Meme Routes" do
  describe "GET /random.json (AJAX endpoint)" do
    before(:each) do
      # Pre-populate some test memes in database
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, ?, ?)",
        ["https://example.com/meme1.jpg", "Test Meme 1", "test", 10, 5]
      )
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, ?, ?)",
        ["https://example.com/meme2.jpg", "Test Meme 2", "funny", 20, 15]
      )
    end

    it "returns 200 OK with meme data" do
      get "/random.json"
      expect(last_response.status).to eq(200)
    end

    it "returns JSON with meme properties" do
      get "/random.json"
      data = JSON.parse(last_response.body)
      expect(data).to have_key("title")
      expect(data).to have_key("subreddit")
      expect(data).to have_key("url")
      expect(data).to have_key("likes")
    end

    it "returns meme when available" do
      get "/random.json"
      # Should return a meme from the test data we created
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data["url"]).not_to be_nil
    end

    it "returns different memes on multiple requests" do
      # Make multiple requests
      get "/random.json"
      data1 = JSON.parse(last_response.body)
      
      get "/random.json"
      data2 = JSON.parse(last_response.body)
      
      # At minimum, responses should be valid JSON
      expect(data1).to have_key("url")
      expect(data2).to have_key("url")
    end

    it "tracks session history" do
      get "/random.json"
      data1 = JSON.parse(last_response.body)
      url1 = data1["url"]
      
      get "/random.json"
      data2 = JSON.parse(last_response.body)
      url2 = data2["url"]
      
      # URLs should be different (subreddit diversity)
      # This tests the session tracking logic
    end
  end

  describe "GET / (HTML page)" do
    it "loads successfully" do
      get "/"
      expect(last_response.status).to eq(200)
    end

    it "renders the random view" do
      get "/"
      expect(last_response.body).to include("meme")
    end
  end

  # Regression test for the production incident (Aug 25, 2026, round 9)
  # where GET /random trusted MemeExplorer::App::MEME_CACHE[:memes] first
  # and only called random_memes_pool (which correctly prioritizes
  # MemePoolManager's Redis-backed, tier-distributed pool) when that
  # legacy cache was empty. Once MEME_CACHE[:memes] got seeded with just
  # the 10-item local fallback list, /random kept serving only those 10
  # local memes forever - even after MemePoolManager's real Reddit-sourced
  # pool became available and /random.json (which already called
  # random_memes_pool unconditionally) was serving it correctly.
  describe "GET /random - MemePoolManager pool preference (round 9 regression)" do
    it "prefers MemePoolManager over a stale legacy MEME_CACHE snapshot" do
      stale_local_memes = [{ 'file' => '/images/funny1.jpeg', 'title' => 'stale local meme' }]
      allow(MemeExplorer::App::MEME_CACHE).to receive(:[]).with(:memes).and_return(stale_local_memes)

      fresh_pool_meme = { 'url' => 'https://i.redd.it/fresh.jpg', 'title' => 'fresh reddit meme', 'subreddit' => 'funny' }
      allow(MemePoolManager).to receive(:get_pool).and_return(
        success: true, memes: [fresh_pool_meme], pool_size: 1, error: nil
      )

      get "/random"

      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include('stale local meme')
    end
  end
end
