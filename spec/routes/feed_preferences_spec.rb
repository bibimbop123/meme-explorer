require_relative '../spec_helper'

RSpec.describe 'Session discovery controls' do
  around do |example|
    previous = ENV['ENABLE_DISCOVERY_CONTROLS']
    ENV['ENABLE_DISCOVERY_CONTROLS'] = 'true'
    example.run
  ensure
    previous.nil? ? ENV.delete('ENABLE_DISCOVERY_CONTROLS') : ENV['ENABLE_DISCOVERY_CONTROLS'] = previous
  end

  before do
    session[:feed_session_id] = SecureRandom.hex(32)
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true, pool_size: 2, memes: [
      { 'url' => '/images/funny1.jpeg', 'title' => 'Hidden fixture', 'subreddit' => 'cats' },
      { 'url' => '/images/funny2.jpeg', 'title' => 'Allowed fixture', 'subreddit' => 'dogs' }
    ])
  end

  after do
    REDIS_POOL.with { |redis| redis.del("discovery:preferences:v1:#{session[:feed_session_id]}") }
  end

  def stored_preferences
    DiscoveryPreferencesStore.call(session[:feed_session_id])
  end

  def preference(action, community = nil)
    post '/feed/preferences', { action: action, community: community }
    expect(last_response.status).to eq(303)
  end

  it 'deletes discovery state on logout even with controls disabled' do
    preference('hide', 'cats')
    identity = session[:feed_session_id]
    ENV['ENABLE_DISCOVERY_CONTROLS'] = 'false'
    post '/logout'
    expect(last_response.status).to eq(303)
    expect(session[:feed_session_id]).to be_nil
    expect(DiscoveryPreferencesStore.call(identity)['hidden']).to eq([])
  end

  it 'still clears authentication state if discovery cleanup is unavailable' do
    preference('hide', 'cats')
    identity = session[:feed_session_id]
    allow(DiscoveryPreferencesStore).to receive(:delete).and_raise(DiscoveryPreferencesStore::Unavailable)
    post '/logout'
    expect(last_response.status).to eq(303)
    expect(session[:feed_session_id]).to be_nil
  ensure
    REDIS_POOL.with { |redis| redis.del("discovery:preferences:v1:#{identity}") } if identity
  end

  it 'fails closed on preference-store outage for reads and writes' do
    preference('hide', 'cats')
    allow(DiscoveryPreferencesStore).to receive(:call).and_raise(DiscoveryPreferencesStore::Unavailable)
    ['/random', '/random.json', '/'].each do |path|
      get path
      expect(last_response.status).to eq(503)
      expect(last_response.body).not_to include('Allowed fixture', 'Hidden fixture', 'id="meme-display"')
    end
    post '/feed/preferences', action: 'reset'
    expect(last_response.status).to eq(503)
    allow(DiscoveryPreferencesStore).to receive(:call).and_call_original
    expect(stored_preferences['hidden']).to eq(['cats'])
  end

  it 'defaults off, ignores stored exclusions and rejects writes without mutating them' do
    preference('hide', 'cats')
    preference('hide', 'dogs')
    [nil, 'false', 'TRUE', '1'].each do |value|
      value.nil? ? ENV.delete('ENABLE_DISCOVERY_CONTROLS') : ENV['ENABLE_DISCOVERY_CONTROLS'] = value
      get '/random'
      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include('id="discovery-controls"')
      get '/random.json'
      expect(last_response.status).to eq(200)
      post '/feed/preferences', action: 'reset'
      expect(last_response.status).to eq(404)
      expect(stored_preferences['hidden']).to eq(['cats', 'dogs'])
      expect(stored_preferences['undo']).to eq('dogs')
    end
  end

  it 'does not classify an empty supply as exclusions exhausting an otherwise populated pool' do
    preference('hide', 'cats')
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true, pool_size: 0, memes: [])
    allow_any_instance_of(MemeExplorer::App).to receive(:random_memes_pool).and_return([])
    get '/random.json'
    expect(last_response.status).to eq(404)
    expect(JSON.parse(last_response.body)).not_to have_key('preferences_exhausted')
  end

  it 'keeps a hidden form available when initial media has no community so later navigation can reveal it' do
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true, pool_size: 1, memes: [
      { 'url' => '/images/funny1.jpeg', 'title' => 'No community fixture' }
    ])
    get '/random'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('id="hide-current-community" method="post" action="/feed/preferences" hidden',
      'name="community" value=""')
  end

  it 'rejects missing and forged CSRF tokens without changing exclusions' do
    preference('hide', 'cats')
    [nil, 'x' * 64].each do |token|
      header 'X-CSRF-Token', token
      post '/feed/preferences', action: 'reset'
      expect(last_response.status).to eq(403)
      expect(stored_preferences['hidden']).to eq(['cats'])
    end
  ensure
    refresh_csrf_token
  end

  it 'keeps exact shared memes available despite Random exclusions' do
    id = MemeIdentityService.register({ 'url' => '/images/funny1.jpeg', 'title' => 'Exact hidden-community meme', 'subreddit' => 'cats' })
    preference('hide', 'cats')
    get "/meme/#{id}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Exact hidden-community meme', 'id="meme-display"', "data-share-path=\"/meme/#{id}\"")
    expect(stored_preferences['hidden']).to eq(['cats'])
  end

  it 'does not let a duplicate hide replace the last real undo target' do
    preference('hide', 'cats')
    preference('hide', 'dogs')
    preference('hide', 'cats')
    preference('undo')
    expect(stored_preferences['hidden']).to eq(['cats'])
  end

  it 'clears stale undo after restoring its target without undoing another hidden community' do
    preference('hide', 'cats')
    preference('hide', 'dogs')
    preference('restore', 'dogs')
    expect(stored_preferences['undo']).to be_nil
    get '/random'
    expect(last_response.body).not_to include('Undo last hide')
    expect(last_response.body).to include('Reset hidden communities', 'Restore r/cats')
    preference('undo')
    expect(stored_preferences['hidden']).to eq(['cats'])
  end

  it 'enforces the cap without replacing exclusions and still permits duplicate hides' do
    names = 20.times.map { |i| "community_#{i}" }
    names.each { |name| preference('hide', name) }
    post '/feed/preferences', action: 'hide', community: 'extra'
    expect(last_response.status).to eq(400)
    expect(stored_preferences['hidden']).to eq(names)
    preference('hide', names.first)
    expect(stored_preferences['hidden']).to eq(names)
  end

  it 'filters Random JSON, initial viewer and home while preserving visible restore controls' do
    preference('hide', 'CATS')
    get '/random.json'
    expect(JSON.parse(last_response.body)['subreddit']).to eq('dogs')
    ['/random', '/'].each do |path|
      get path
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Allowed fixture', 'Restore r/cats', 'not an account preference')
    end
  end

  it 'keeps exclusions on scarcity and permits reset instead of silently widening' do
    preference('hide', 'cats')
    preference('hide', 'dogs')
    get '/random.json'
    expect(last_response.status).to eq(409)
    expect(JSON.parse(last_response.body)['preferences_exhausted']).to be true
    get '/random'
    expect(last_response.body).to include('No memes match your discovery controls', 'Reset hidden communities')
    preference('reset')
    get '/random.json'
    expect(last_response.status).to eq(200)
  end

  it 'supports undo and individual restore and validates names' do
    preference('hide', 'cats')
    preference('hide', 'dogs')
    preference('undo')
    expect(stored_preferences['hidden']).to eq(['cats'])
    preference('restore', 'cats')
    expect(stored_preferences['hidden']).to eq([])
    post '/feed/preferences', { action: 'hide', community: '<script>' }
    expect(last_response.status).to eq(400)
  end

  ['/random', '/'].each do |path|
    it "keeps hidden community excluded when selection fails on #{path}" do
      preference('hide', 'cats')
      allow(MemeExplorer::SimpleMemeSelector).to receive(:select).and_raise(StandardError, 'fixture selector unavailable')
      allow_any_instance_of(MemeExplorer::App).to receive(:fallback_meme).and_return({
        'url' => '/images/funny1.jpeg', 'title' => 'Excluded fallback', 'subreddit' => 'cats'
      })
      get path
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('No memes match your discovery controls', 'Restore r/cats')
      expect(last_response.body).not_to include('Excluded fallback', 'id="meme-display"')
      expect(stored_preferences['hidden']).to eq(['cats'])
    end
  end
end