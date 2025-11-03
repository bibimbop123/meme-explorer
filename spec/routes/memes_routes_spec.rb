require 'spec_helper'

describe 'Meme Routes' do
  describe 'GET /' do
    it 'returns homepage with random meme' do
      get '/'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /random' do
    it 'returns random meme page' do
      get '/random'
      expect(last_response.status).to eq(200)
    end

    it 'returns JSON when requested' do
      get '/random.json'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('title', 'subreddit', 'likes')
    end
  end

  describe 'POST /like' do
    it 'returns error without URL' do
      post '/like', {}
      expect(last_response.status).to eq(400)
    end

    it 'toggles like on meme' do
      post '/like', { url: 'http://example.com/meme.jpg' }
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('liked', 'likes')
    end

    it 'dislikes when already liked' do
      post '/like', { url: 'http://example.com/meme.jpg' }
      first_response = JSON.parse(last_response.body)
      
      post '/like', { url: 'http://example.com/meme.jpg' }
      second_response = JSON.parse(last_response.body)
      
      expect(first_response['liked']).not_to eq(second_response['liked'])
    end
  end

  describe 'GET /search' do
    before do
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
        ['http://example.com/meme.jpg', 'Funny Test Meme', 'funny', 100, 500])
    end

    it 'returns search results page' do
      get '/search?q=funny'
      expect(last_response.status).to eq(200)
    end

    it 'returns JSON results when requested' do
      get '/search?q=funny', {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('query', 'results', 'total')
    end

    it 'returns empty results for non-matching query' do
      get '/api/search.json?q=xyznotexist'
      response_body = JSON.parse(last_response.body)
      expect(response_body['total']).to eq(0)
    end
  end

  describe 'GET /trending' do
    before do
      5.times do |i|
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ["http://example.com/meme#{i}.jpg", "Trending Meme #{i}", 'funny', (i + 1) * 100, (i + 1) * 500])
      end
    end

    it 'returns trending page' do
      get '/trending'
      expect(last_response.status).to eq(200)
    end

    it 'shows top memes by engagement' do
      get '/trending'
      expect(last_response.body).to include('Trending Meme')
    end
  end

  describe 'GET /category/:name' do
    it 'returns category page for valid category' do
      get '/category/funny'
      expect(last_response.status).to eq(200)
    end

    it 'returns JSON for valid category' do
      get '/category/wholesome.json'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to be_a(Array)
    end

    it 'returns 404 for invalid category' do
      get '/category/nonexistent'
      expect([404]).to include(last_response.status)
    end
  end

  describe 'POST /report-broken-image' do
    it 'returns error without URL' do
      post '/report-broken-image', {}
      expect(last_response.status).to eq(400)
    end

    it 'reports broken image' do
      post '/report-broken-image', { url: 'http://example.com/broken.jpg' }
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body['reported']).to eq(true)
    end
  end
end
