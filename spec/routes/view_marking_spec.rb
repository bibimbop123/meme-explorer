require_relative '../spec_helper'

# feed.view_on_render: prefetched /random.json selections (X-Prefetch: 1)
# must NOT burn unseen inventory at selection time - the client reports the
# view via POST /api/viewed only when the meme actually renders.
RSpec.describe 'View-on-render marking (feed.view_on_render)' do
  let(:url) { 'https://i.redd.it/view-on-render.jpg' }
  let(:meme) { { 'url' => url, 'title' => 'Deferred view marking', 'subreddit' => 'funny' } }

  before do
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true, memes: [meme], pool_size: 1)
    DB.execute('INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 7, 10)', [url, meme['title'], 'funny'])
    allow(FeatureFlags).to receive(:enabled?).and_call_original
  end

  def enable_flag(value)
    allow(FeatureFlags).to receive(:enabled?).with('feed.view_on_render').and_return(value)
  end

  it 'marks selection-time seen for prefetch requests when the flag is off (default behavior)' do
    enable_flag(false)
    expect(MemeExplorer::ViewingHistoryService).to receive(:mark_seen).with(anything, url).at_least(:once)
    get '/random.json', {}, { 'HTTP_X_PREFETCH' => '1' }
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).not_to have_key('view_marking')
  end

  it 'defers seen marking for prefetch requests when the flag is on and self-describes via view_marking' do
    enable_flag(true)
    expect(MemeExplorer::ViewingHistoryService).not_to receive(:mark_seen)
    get '/random.json', {}, { 'HTTP_X_PREFETCH' => '1' }
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body['view_marking']).to eq('render')
    expect(body['impression_id']).to be_a(String)
  end

  it 'still marks selection-time seen for non-prefetch requests when the flag is on' do
    enable_flag(true)
    expect(MemeExplorer::ViewingHistoryService).to receive(:mark_seen).with(anything, url).at_least(:once)
    get '/random.json'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).not_to have_key('view_marking')
  end

  describe 'POST /api/viewed' do
    it 'returns 404 when the flag is off' do
      enable_flag(false)
      post '/api/viewed', { url: url }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(404)
    end

    it 'rejects malformed bodies and urls without marking' do
      enable_flag(true)
      post '/api/viewed', 'not json', 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(400)
      post '/api/viewed', { url: 'javascript:alert(1)' }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(400)
      post '/api/viewed', { url: "https://example.com/#{'x' * 5000}" }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(400)
    end

    it 'does not mark urls the server never issued to this session' do
      enable_flag(true)
      expect(MemeExplorer::ViewingHistoryService).not_to receive(:mark_seen)
      post '/api/viewed', { url: url }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['marked']).to be false
    end

    it 'marks a prefetched meme seen when the client reports its render' do
      enable_flag(true)
      get '/random.json', {}, { 'HTTP_X_PREFETCH' => '1' }
      expect(JSON.parse(last_response.body)['view_marking']).to eq('render')
      marked = []
      allow(MemeExplorer::ViewingHistoryService).to receive(:mark_seen) { |_visitor, u| marked << u }
      post '/api/viewed', { url: url }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['marked']).to be true
      expect(marked).to eq([url])
    end

    it 'marks both session and account history for a signed-in render report' do
      enable_flag(true)
      user_id = create_test_user('view-on-render-account@example.com')
      set_session(user_id: user_id)
      get '/random.json', {}, { 'HTTP_X_PREFETCH' => '1' }
      marked = []
      allow(MemeExplorer::ViewingHistoryService).to receive(:mark_seen) { |visitor, u| marked << [visitor, u] }
      post '/api/viewed', { url: url }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
      expect(marked.map(&:last)).to eq([url, url])
      expect(marked.map(&:first)).to include("user:#{user_id}")
    end
  end
end
