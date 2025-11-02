require_relative "../../spec/spec_helper"

describe "Like Routes" do
  describe "POST /like" do
    before(:each) do
      # Create test meme stats
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, ?, ?)",
        ["https://example.com/test.jpg", "Test Meme", "test", 5, 0]
      )
    end

    it "requires URL parameter" do
      post "/like"
      expect(last_response.status).to eq(400)
      error_data = JSON.parse(last_response.body)
      expect(error_data["error"]).to include("No URL")
    end

    it "increments like count" do
      post "/like", url: "https://example.com/test.jpg"
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data["liked"]).to eq(true)
      expect(data["likes"]).to be >= 1
    end

    it "returns JSON response" do
      post "/like", url: "https://example.com/test.jpg"
      data = JSON.parse(last_response.body)
      expect(data).to have_key("liked")
      expect(data).to have_key("likes")
    end

    it "tracks like state in session" do
      url = "https://example.com/test.jpg"
      
      # First like
      post "/like", url: url
      data1 = JSON.parse(last_response.body)
      expect(data1["liked"]).to eq(true)
      
      # Unlike
      post "/like", url: url
      data2 = JSON.parse(last_response.body)
      expect(data2["liked"]).to eq(false)
    end
  end

  describe "POST /report-broken-image" do
    it "requires URL parameter" do
      post "/report-broken-image"
      expect(last_response.status).to eq(400)
    end

    it "tracks broken images" do
      url = "https://example.com/broken.jpg"
      post "/report-broken-image", url: url
      expect(last_response.status).to eq(200)
      
      # Verify it was recorded
      result = DB.execute("SELECT failure_count FROM broken_images WHERE url = ?", [url]).first
      expect(result["failure_count"]).to be >= 1
    end
  end
end
