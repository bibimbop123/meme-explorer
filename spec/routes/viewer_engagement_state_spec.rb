require_relative '../spec_helper'
require 'cgi'

RSpec.describe 'Viewer initial engagement state' do
  let(:url) { 'https://i.redd.it/engagement-state.jpg' }
  let(:meme) { { 'url' => url, 'title' => 'Remembered favorite', 'subreddit' => 'funny' } }

  before do
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true, memes: [meme], pool_size: 1)
    DB.execute('INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 7, 10)', [url, meme['title'], 'funny'])
  end

  it 'exposes aggregate post-selection timings without content identifiers' do
    get '/random.json'
    expect(last_response.status).to eq(200)
    timing = last_response.headers['server-timing']
    expect(timing).to match(/\Aresponse_prepare;dur=\d+(?:\.\d+)?, impression_issue;dur=\d+(?:\.\d+)?, serialization;dur=\d+(?:\.\d+)?\z/)
    expect(timing).not_to include(url, meme['title'])
    expect(JSON.parse(last_response.body)).to include('url' => url, 'likes' => 7)
    expect(last_response.headers['cache-control']).to include('no-store')
  end

  ['/random.json', '/similar.json?subreddit=funny'].each do |path|
    it "looks up the server like count only once for #{path}" do
      allow_any_instance_of(MemeExplorer::App).to receive(:get_meme_likes).and_call_original
      expect_any_instance_of(MemeExplorer::App).to receive(:get_meme_likes).with(url).once.and_return(7)
      get path
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('url' => url, 'likes' => 7)
    end
  end

  it 'reuses a zero server count without performing another lookup' do
    expect_any_instance_of(MemeExplorer::App).to receive(:get_meme_likes).with(url).once.and_return(0)
    get '/random.json'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['likes']).to eq(0)
  end

  it 'looks up counts when the engagement helper has no supplied count' do
    viewer = MemeExplorer::App.new!
    allow(viewer).to receive(:current_user_id).and_return(nil)
    allow(viewer).to receive(:session).and_return({})
    expect(viewer).to receive(:get_meme_likes).with(url).once.and_return(9)
    expect(viewer.viewer_engagement_state(url)).to include(likes: 9, liked: false, saved: false)
  end

  it 'returns persistent liked/saved flags on AJAX selection' do
    user_id = create_test_user('viewer-state@example.com')
    set_session(user_id: user_id)
    DB.execute('INSERT INTO user_liked_memes (user_id, meme_url) VALUES (?, ?)', [user_id, url])
    UserService.save_meme(user_id, url, meme['title'], 'funny')
    get '/random.json'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to include('url' => url, 'liked' => true, 'saved' => true, 'likes' => 7)
  end

  ['/', '/random'].each do |path|
    it "renders persisted state before interaction on #{path}" do
      user_id = create_test_user('viewer-html@example.com')
      set_session(user_id: user_id)
      DB.execute('INSERT INTO user_liked_memes (user_id, meme_url) VALUES (?, ?)', [user_id, url])
      UserService.save_meme(user_id, url, meme['title'], 'funny')
      get path
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match(/id="like-btn"[^>]*aria-pressed="true"/)
      expect(last_response.body).to match(/id="save-btn"[^>]*aria-pressed="true"/)
      data = CGI.unescapeHTML(last_response.body[/id="initial-meme-data" hidden data-meme="([^"]+)"/, 1])
      expect(JSON.parse(data)).to include('liked' => true, 'saved' => true, 'likes' => 7)
    end
  end

  it 'restores guest session likes without claiming account saves' do
    session[:liked_memes] = [url]
    get '/random.json'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to include('liked' => true, 'saved' => false)
  end
end