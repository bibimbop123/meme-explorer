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
    durations = timing.split(', ').to_h do |entry|
      name, value = entry.split(';dur=')
      expect(value).to match(/\A\d+(?:\.\d+)?\z/)
      [name, value.to_f]
    end
    expect(durations.keys).to eq(%w[response_prepare history_write media_detect likes_lookup impression_issue serialization])
    expect(durations['response_prepare']).to be >= durations['history_write']
    expect(timing).not_to include(url, meme['title'])
    expect(JSON.parse(last_response.body)).to include('url' => url, 'likes' => 7)
    expect(last_response.headers['cache-control']).to include('no-store')
  end

  it 'attributes a delayed likes lookup to its sub-stage and preparation parent' do
    expect_any_instance_of(MemeExplorer::App).to receive(:get_meme_likes).with(url).once do
      sleep 0.015
      7
    end
    get '/random.json'
    expect(last_response.status).to eq(200)
    timings = last_response.headers['server-timing'].split(', ').to_h do |entry|
      name, duration = entry.split(';dur=')
      [name, duration.to_f]
    end
    expect(timings.fetch('likes_lookup')).to be >= 15.0
    expect(timings.fetch('response_prepare')).to be >= timings.fetch('likes_lookup')
    expect(JSON.parse(last_response.body)['likes']).to eq(7)
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