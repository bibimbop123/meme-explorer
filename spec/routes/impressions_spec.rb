require_relative '../spec_helper'

RSpec.describe 'Acknowledged AJAX impressions' do
  it 'reconciles gross like actions and current saved state after reversing interactions' do
    user_id = create_test_user('interaction-report@example.test')
    set_session(user_id: user_id)
    meme = select_meme
    acknowledge(meme['impression_id'])
    baseline = MetricsReport.build(period: '24h')
    [true, true, false, false].each do |liked|
      post '/like', { url: meme['url'], liked: liked }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200)
    end
    2.times do
      post '/api/save-meme', { url: meme['url'], title: 'Controlled fixture', subreddit: 'funny' }
      expect(last_response.status).to eq(200)
    end
    2.times do
      post '/api/unsave-meme', url: meme['url']
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['unsaved']).to be true
    end
    events = DB.execute('SELECT activity_type, COUNT(*) AS count FROM meme_activity_log WHERE user_id = ? GROUP BY activity_type', [user_id])
      .to_h { |row| [row['activity_type'], row['count'].to_i] }
    expect(events).to eq('view' => 1, 'like' => 1, 'unlike' => 1, 'save' => 1, 'unsave' => 1)
    report = MetricsReport.build(period: '24h')
    expect(report[:total_likes]).to eq(baseline[:total_likes] + 1)
    expect(report[:chart_likes].sum).to eq(report[:total_likes])
    expect(report[:total_saved_memes]).to eq(baseline[:total_saved_memes])
    expect(DB.get_first_value('SELECT likes FROM meme_stats WHERE url = ?', [meme['url']]).to_i).to eq(0)
  end

  it 'reconciles speculative selections, acknowledgment retries and rolling dashboard counts' do
    user_id = create_test_user('report-reconciliation@example.test')
    set_session(user_id: user_id)
    baseline = MetricsReport.build(period: '24h')[:total_views]
    displayed = select_meme
    speculative = select_meme
    expect(speculative['impression_id']).not_to eq(displayed['impression_id'])
    expect(MetricsReport.build(period: '24h')[:total_views]).to eq(baseline)
    2.times { acknowledge(displayed['impression_id']) }
    expect(last_response.status).to eq(200)
    report = MetricsReport.build(period: '24h')
    expect(report[:total_views]).to eq(baseline + 1)
    expect(report[:chart_views].sum).to eq(report[:total_views])
    expect(DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view' AND user_id = ?", [user_id]).to_i).to eq(1)
    get '/metrics.json?period=24h'
    expect(last_response.status).to eq(200)
    metrics_json = JSON.parse(last_response.body)
    expect(metrics_json['total_views']).to eq(report[:total_views])
    expect(metrics_json.dig('browser_visitors', 'available')).to be true
    expect(metrics_json.dig('browser_visitors', 'counts', '24h')).to be >= 1
  end

  def select_meme
    get '/random.json'
    expect(last_response.status).to eq(200)
    expect(last_response.headers['cache-control']).to include('no-store', 'private')
    JSON.parse(last_response.body)
  end

  def acknowledge(id)
    post '/api/impressions', { impression_id: id }.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  it 'does not count selection as a view and records repeated acknowledgments once' do
    before = DB.get_first_value('SELECT COALESCE(SUM(views), 0) FROM meme_stats').to_i
    meme = select_meme
    expect(DB.get_first_value('SELECT COALESCE(SUM(views), 0) FROM meme_stats').to_i).to eq(before)
    acknowledge(meme['impression_id'])
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['recorded']).to be true
    acknowledge(meme['impression_id'])
    expect(JSON.parse(last_response.body)['recorded']).to be false
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(1)
    expect(DB.get_first_value('SELECT COALESCE(SUM(views), 0) FROM meme_stats').to_i).to eq(before + 1)
  end

  it 'rejects IDs issued to another session' do
    meme = select_meme
    set_session({})
    acknowledge(meme['impression_id'])
    expect(last_response.status).to eq(404)
  end

  it 'identifies missing pending state after a stale session snapshot without trusting client content' do
    selected = select_meme
    session[:pending_impressions] = {} # Model a later response restoring stale state.
    allow(AppLogger).to receive(:info).and_call_original
    expect(AppLogger).to receive(:info).with('Impression acknowledgment rejected', reason: 'missing_pending')
    post '/api/impressions', { impression_id: selected['impression_id'], url: selected['url'] }.to_json,
      'CONTENT_TYPE' => 'application/json'
    expect(last_response.status).to eq(404)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
  end

  it 'distinguishes expired pending metadata from malformed IDs without echoing credentials' do
    selected = select_meme
    session[:pending_impressions][selected['impression_id']]['expires_at'] = Time.now.to_i - 1
    allow(AppLogger).to receive(:info).and_call_original
    expect(AppLogger).to receive(:info).with('Impression acknowledgment rejected', reason: 'expired_pending')
    acknowledge(selected['impression_id'])
    expect(last_response.status).to eq(404)
    expect(AppLogger).to receive(:info).with('Impression acknowledgment rejected', reason: 'malformed_id')
    acknowledge('not-an-issued-id')
    expect(last_response.status).to eq(404)
    expect(last_response.body).not_to include('not-an-issued-id')
  end

  it 'rejects expired IDs and malformed JSON' do
    meme = select_meme
    session[:pending_impressions][meme['impression_id']]['expires_at'] = Time.now.to_i - 1
    acknowledge(meme['impression_id'])
    expect(last_response.status).to eq(404)
    post '/api/impressions', 'bad', 'CONTENT_TYPE' => 'application/json'
    expect(last_response.status).to eq(400)
  end

  it 'rolls back the dedupe record on failed view update and permits a safe retry' do
    meme = select_meme
    allow(DB).to receive(:execute).and_call_original
    allow(DB).to receive(:execute).with(/INSERT INTO meme_stats/, anything).and_raise(PG::Error, 'simulated write failure')
    acknowledge(meme['impression_id'])
    expect(last_response.status).to eq(503)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    allow(DB).to receive(:execute).with(/INSERT INTO meme_stats/, anything).and_call_original
    acknowledge(meme['impression_id'])
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['recorded']).to be true
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(1)
  end

  ['/', '/random'].each do |path|
    it "does not count an initial #{path} page request until acknowledged" do
      get path
      expect(last_response.status).to eq(200)
      id = last_response.body[/data-impression-id="([a-f0-9]{64})"/, 1]
      expect(id).not_to be_nil
      expect(DB.get_first_value('SELECT COALESCE(SUM(views), 0) FROM meme_stats').to_i).to eq(0)
      acknowledge(id)
      expect(last_response.status).to eq(200)
      expect(DB.get_first_value('SELECT COALESCE(SUM(views), 0) FROM meme_stats').to_i).to eq(1)
    end
  end

  it 'counts authenticated exposure once, on acknowledgment rather than selection' do
    user_id = create_test_user('impression-exposure@example.com')
    set_session(user_id: user_id)
    meme = select_meme
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_meme_exposure').to_i).to eq(0)
    2.times { acknowledge(meme['impression_id']) }
    expect(DB.get_first_value('SELECT SUM(shown_count) FROM user_meme_exposure').to_i).to eq(1)
    expect(DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view'").to_i).to eq(1)
  end
end