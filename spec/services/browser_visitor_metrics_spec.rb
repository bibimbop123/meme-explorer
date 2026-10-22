require_relative '../spec_helper'

RSpec.describe BrowserVisitorMetrics do
  before do
    DB_POOL.with { |connection| connection.exec(File.read(File.expand_path('../../db/migrations/add_browser_visitors.sql', __dir__))) }
    DB.execute('DELETE FROM browser_visitors')
    DB.execute('DELETE FROM browser_visitor_collection')
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ENABLE_VISITOR_METRICS').and_return('true')
  end

  it 'deduplicates browser observations and reports rolling windows with partial coverage' do
    now = Time.utc(2026, 10, 21, 12)
    described_class.record('a' * 64, now: now - 20 * 86_400)
    described_class.record('a' * 64, now: now)
    described_class.record('b' * 64, now: now - 2 * 86_400)
    described_class.record('c' * 64, now: now - 10 * 86_400)
    described_class.record('d' * 64, now: now + 3600)
    snapshot = described_class.snapshot(now: now)
    expect(snapshot).to include(available: true, counts: { '24h' => 1, '7d' => 2, '30d' => 3 }, partial_windows: ['30d'])
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors').to_i).to eq(4)
    expect(DB.get_first_value('SELECT visitor_key FROM browser_visitors LIMIT 1')).not_to eq('a' * 64)
  end

  it 'does not invent zero counts on query failure and rejects malformed identities' do
    expect { described_class.record('bad') }.to raise_error(ArgumentError)
    allow(DB).to receive(:get_first_value).and_raise(PG::Error)
    expect(described_class.snapshot).to eq(available: false, status: 'unavailable')
  end

  it 'requires explicit consent and respects privacy signals before setting a cookie' do
    expect(described_class).not_to receive(:record)
    post '/api/visitor-observation', consent: 'rejected'
    expect(last_response.status).to eq(400)
    header 'Sec-GPC', '1'
    post '/api/visitor-observation', consent: 'accepted'
    expect(last_response.status).to eq(204)
    expect(last_response.headers['set-cookie'].to_s).not_to include('meme_visitor=')
  end

  it 'keeps a browser identity across repeated observations without account linkage' do
    2.times do
      post '/api/visitor-observation', consent: 'accepted'
      expect(last_response.status).to eq(204)
    end
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors').to_i).to eq(1)
    expect(last_response.headers['set-cookie'].to_s).to include('meme_visitor=')
  end
end