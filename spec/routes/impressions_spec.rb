require_relative '../spec_helper'

RSpec.describe 'Acknowledged AJAX impressions' do
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