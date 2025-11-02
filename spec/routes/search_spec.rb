require_relative "../../spec/spec_helper"

describe "Search Routes" do
  before(:each) do
    # Create test memes in database
    DB.execute(
      "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, ?, ?)",
      ["https://example.com/search1.jpg", "Programming Humor", "programmer", 50, 25]
    )
    DB.execute(
      "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, ?, ?)",
      ["https://example.com/search2.jpg", "Tech Jokes", "tech", 30, 15]
    )
  end

  describe "GET /search" do
    it "returns search page" do
      get "/search?q=programming"
      expect(last_response.status).to eq(200)
    end

    it "displays search results" do
      get "/search?q=programming"
      expect([last_response.body.include?("search"), last_response.body.include?("result")].any?).to be true
    end
  end

  describe "GET /api/search.json" do
    it "returns JSON search results" do
      get "/api/search.json?q=program"
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data).to have_key("query")
      expect(data).to have_key("results")
      expect(data).to have_key("total")
    end

    it "filters by query term" do
      get "/api/search.json?q=program"
      data = JSON.parse(last_response.body)
      expect(data["query"]).to eq("program")
    end

    it "returns empty results for non-existent query" do
      get "/api/search.json?q=nonexistentmemequerystring"
      data = JSON.parse(last_response.body)
      expect(data["total"]).to eq(0)
    end
  end
end
