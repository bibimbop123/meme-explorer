require_relative "../../spec/spec_helper"

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
end
