require_relative '../spec_helper'

RSpec.describe 'Default-off legacy impression repair acceptance' do
  let(:url) { '/images/funny1.jpeg' }
  let(:binding) { SecureRandom.hex(32) }

  before do
    allow(FeatureFlags).to receive(:enabled?).and_call_original
    allow(FeatureFlags).to receive(:enabled?).with('feed.legacy_pending_store').and_return(true)
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true,
      memes: [{ 'url' => url, 'title' => 'Repair fixture', 'subreddit' => 'local' }], pool_size: 1)
    session[:impression_session_key] = binding
  end

  after do
    RedisService.with_redis { |redis| redis.del(*LegacyImpressionStore.keys(binding, nil)) }
  end

  def select_id
    get '/random.json'
    expect(last_response.status).to eq(200)
    JSON.parse(last_response.body).fetch('impression_id')
  end

  def acknowledge(id)
    post '/api/impressions', { impression_id: id, url: '/client-substitution.jpg' }.to_json,
      'CONTENT_TYPE' => 'application/json'
  end

  it 'keeps external issuance off under the shipped feature configuration' do
    allow(FeatureFlags).to receive(:enabled?).with('feed.legacy_pending_store').and_call_original
    FeatureFlags.reload!
    expect(FeatureFlags.enabled?('feed.legacy_pending_store')).to be false
    expect(LegacyImpressionStore).not_to receive(:issue)
    id = select_id
    expect(session[:pending_impressions]).to have_key(id)
    acknowledge(id)
    expect(last_response.status).to eq(200)
  end

  it 'uses legacy issuance until a binding exists and preserves that ID after switching stores' do
    session.delete(:impression_session_key)
    legacy_id = select_id
    established_binding = session[:impression_session_key]
    expect(LegacyImpressionStore.valid_id?(established_binding)).to be true
    expect(session[:pending_impressions]).to have_key(legacy_id)
    external_id = select_id
    expect(session[:impression_session_key]).to eq(established_binding)
    expect(session[:pending_impressions]).not_to have_key(external_id)
    expect(LegacyImpressionStore.lookup(established_binding, nil, external_id)[:status]).to eq(:found)
    [legacy_id, external_id].each do |id|
      acknowledge(id)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['recorded']).to be true
    end
  ensure
    if established_binding
      RedisService.with_redis { |redis| redis.del(*LegacyImpressionStore.keys(established_binding, nil)) }
    end
  end

  it 'bounds both stores independently and ACKs mixed credentials across rollback without renewing them' do
    allow(FeatureFlags).to receive(:enabled?).with('feed.legacy_pending_store').and_return(false)
    legacy_ids = 20.times.map { select_id }
    deadlines = session[:pending_impressions].transform_values { |item| item.fetch('expires_at') }
    allow(FeatureFlags).to receive(:enabled?).with('feed.legacy_pending_store').and_return(true)
    external_ids = 20.times.map { select_id }
    expect(session[:pending_impressions].keys).to match_array(legacy_ids)
    RedisService.with_redis do |redis|
      expiry, items = LegacyImpressionStore.keys(binding, nil)
      expect(redis.zcard(expiry)).to eq(20)
      expect(redis.hlen(items)).to eq(20)
    end

    allow(FeatureFlags).to receive(:enabled?).with('feed.legacy_pending_store').and_return(false)
    rollback_id = select_id
    expect(session[:pending_impressions].size).to eq(20)
    expect(session[:pending_impressions]).not_to have_key(legacy_ids.first)
    session[:pending_impressions].each do |id, item|
      expect(item['expires_at']).to eq(deadlines.fetch(id)) unless id == rollback_id
    end
    retained = legacy_ids.drop(1) + external_ids + [rollback_id]
    retained.each do |id|
      2.times do |attempt|
        acknowledge(id)
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)['recorded']).to eq(attempt.zero?)
      end
    end
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(40)
    expect(DB.get_first_value('SELECT COALESCE(SUM(views), 0) FROM meme_stats').to_i).to eq(40)
  end

  it 'keeps media usable but issues no credential when persistence fails' do
    expect(LegacyImpressionMetrics).to receive(:record).with('issue_unavailable').and_call_original
    allow(LegacyImpressionStore).to receive(:issue).and_return(false)
    expect(AppLogger).to receive(:warn).with('Legacy impression issuance unavailable', storage: 'external')
    expect(select_id).to be_nil
    expect(JSON.parse(last_response.body)['url']).to eq(url)
    expect(session[:pending_impressions]).to be_nil
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
  end

  it 'returns unavailable without mutation on lookup failure then permits retry' do
    expect(LegacyImpressionMetrics).to receive(:record).with('issue_external').and_call_original
    expect(LegacyImpressionMetrics).to receive(:record).with('ack_unavailable').and_call_original
    expect(LegacyImpressionMetrics).to receive(:record).with('ack_recorded').and_call_original
    id = select_id
    allow(LegacyImpressionStore).to receive(:lookup).and_return(status: :unavailable)
    acknowledge(id)
    expect(last_response.status).to eq(503)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    allow(LegacyImpressionStore).to receive(:lookup).and_call_original
    acknowledge(id)
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['recorded']).to be true
  end

  it 'rolls back database failures and retries the original externally stored credential' do
    id = select_id
    allow(DB).to receive(:execute).and_call_original
    allow(DB).to receive(:execute).with(/INSERT INTO meme_stats/, anything).and_raise(PG::Error, 'private database payload must not be logged')
    expect(AppLogger).to receive(:error).with('Impression acknowledgment failed', error: 'PG::Error')
    acknowledge(id)
    expect(last_response.status).to eq(503)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    allow(DB).to receive(:execute).with(/INSERT INTO meme_stats/, anything).and_call_original
    acknowledge(id)
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['recorded']).to be true
    expect(DB.get_first_value('SELECT meme_url FROM meme_impressions WHERE id = ?', [id])).to eq(url)
  end

  it 'rejects the credential after authenticated identity changes even with the same binding' do
    id = select_id
    session[:user_id] = create_test_user('legacy-repair-auth@example.test')
    acknowledge(id)
    expect(last_response.status).to eq(404)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
  end

  it 'records authenticated exposure and activity once per external ID without changing selection-time exposure on retry' do
    user_id = create_test_user('ack-accounting@example.test')
    session[:user_id] = user_id
    ids = 2.times.map { select_id }
    exposure = lambda do
      DB.get_first_value('SELECT COALESCE(SUM(shown_count), 0) FROM user_meme_exposure WHERE user_id = ? AND meme_url = ?',
        [user_id, url]).to_i
    end
    selection_exposure = exposure.call
    ids.each do |id|
      2.times do |attempt|
        acknowledge(id)
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)['recorded']).to eq(attempt.zero?)
      end
    end
    expect(exposure.call).to eq(selection_exposure + 2)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(2)
    expect(DB.get_first_value('SELECT views FROM meme_stats WHERE url = ?', [url]).to_i).to eq(2)
    expect(DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view' AND user_id = ? AND session_id = ? AND meme_url = ?",
      [user_id, binding, url]).to_i).to eq(2)
  ensure
    if user_id
      RedisService.with_redis { |redis| redis.del(*LegacyImpressionStore.keys(binding, user_id)) }
    end
  end

  [[:url, '/images/other.jpeg'], [:session, 'f' * 64]].each do |conflict, value|
    it "rejects an existing database impression with conflicting #{conflict} provenance" do
      id = select_id
      DB.execute('INSERT INTO meme_impressions (id, meme_url, session_key) VALUES (?, ?, ?)',
        [id, conflict == :url ? value : url, conflict == :session ? value : binding])
      acknowledge(id)
      expect(last_response.status).to eq(503)
      expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(1)
      expect(DB.get_first_value('SELECT COALESCE(SUM(views), 0) FROM meme_stats').to_i).to eq(0)
    end
  end

  it 'rejects the credential after session replacement' do
    id = select_id
    set_session({})
    acknowledge(id)
    expect(last_response.status).to eq(404)
  end

  it 'rejects an expired external entry without renewing its deadline' do
    id = select_id
    key = LegacyImpressionStore.keys(binding, nil).first
    RedisService.with_redis { |redis| redis.zadd(key, Time.now.to_i - 1, id) }
    acknowledge(id)
    expect(last_response.status).to eq(404)
    RedisService.with_redis { |redis| expect(redis.zscore(key, id)).to be < Time.now.to_i }
  end
end