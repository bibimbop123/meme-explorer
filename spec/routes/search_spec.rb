require_relative "../../spec/spec_helper"

describe "Search Routes" do
  describe 'search validation feedback' do
    it 'finds apostrophes through the parameterized database search' do
      DB.execute('INSERT INTO meme_stats (url, title, views, likes) VALUES (?, ?, 1, 1)',
        ['https://example.com/apostrophe.jpg', "O'Reilly programming jokes"])
      allow(MemeService).to receive(:fetch_reddit_memes).and_return([])
      allow(MemeExplorer::App::MEME_CACHE).to receive(:[]).with(:memes).and_return([])
      get '/api/search.json', { q: "O'Reilly" }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['results'].map { |meme| meme['title'] }).to include("O'Reilly programming jokes")
    end

    it 'treats percent and underscore as literal search characters in PostgreSQL' do
      DB.execute('INSERT INTO meme_stats (url, title, views, likes) VALUES (?, ?, 1, 1)',
        ['https://example.com/literal.jpg', '100%_fun'])
      DB.execute('INSERT INTO meme_stats (url, title, views, likes) VALUES (?, ?, 1, 1)',
        ['https://example.com/wildcard.jpg', '100xyzfun'])
      allow(MemeService).to receive(:fetch_reddit_memes).and_return([])
      allow(MemeExplorer::App::MEME_CACHE).to receive(:[]).with(:memes).and_return([])
      get '/api/search.json', { q: '100%_' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['results'].map { |meme| meme['title'] }).to eq(['100%_fun'])
    end

    it 'shows a neutral initial HTML state without invoking search' do
      expect(SearchService).not_to receive(:search)
      get '/search', {}, 'HTTP_ACCEPT' => 'text/html'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Find a meme by topic or community')
      expect(last_response.body).not_to include('No memes found')
    end

    ['', 'x' * 201, 'test--query'].each do |query|
      it "returns actionable JSON validation for #{query.length}-character input" do
        get '/api/search.json', { q: query }
        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body['success']).to be false
        expect(body['error']).not_to be_empty
        expect(body['results']).to eq([])
        expect(body['total']).to eq(0)
      end
    end

    it 'renders an accessible correction state for invalid HTML input' do
      get '/search', { q: 'x' * 201 }, 'HTTP_ACCEPT' => 'text/html'
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('aria-invalid="true"', 'role="alert"', 'Edit your query')
      expect(last_response.body).not_to include('No memes found')
    end

    it 'uses the same error contract for JSON negotiation on /search' do
      get '/search', { q: '' }, 'HTTP_ACCEPT' => 'application/json'
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['success']).to be false
    end
  end

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
