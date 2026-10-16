require_relative '../spec_helper'
require_relative '../../lib/services/meme_identity_service'

RSpec.describe MemeIdentityService do
  let(:meme) { { 'url' => 'https://i.redd.it/identity.jpg', 'title' => 'Exact meme', 'subreddit' => 'funny' } }

  it 'assigns a stable ID and resolves independently of visitor session' do
    id = described_class.register(meme)
    expect(id).to match(/\A[a-f0-9]{64}\z/)
    expect(described_class.register(meme)).to eq(id)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_catalog').to_i).to eq(1)
    expect(described_class.find(id)).to include('url' => meme['url'], 'title' => 'Exact meme')
  end

  it 'does not let later duplicate registration replace the original snapshot' do
    id = described_class.register(meme)
    described_class.register(meme.merge('title' => 'Changed'))
    expect(described_class.find(id)['title']).to eq('Exact meme')
  end

  it 'does not resurrect removed content when it reappears in a source pool' do
    id = described_class.register(meme)
    DB.execute('UPDATE meme_catalog SET removed_at = CURRENT_TIMESTAMP WHERE id = ?', [id])
    expect(described_class.find(id)).to be_nil
    described_class.register(meme)
    expect(described_class.find(id)).to be_nil
  end

  it 'rejects unsafe sources, oversized snapshots and malformed IDs without fetching URLs' do
    expect(described_class.register({ 'url' => 'javascript:alert(1)' })).to be_nil
    expect(described_class.register(meme.merge('title' => 'x' * 140_000))).to be_nil
    expect(DB).not_to receive(:execute)
    expect(described_class.find("'; DROP TABLE users; --")).to be_nil
    expect(described_class.find('https://attacker.example')).to be_nil
  end
end