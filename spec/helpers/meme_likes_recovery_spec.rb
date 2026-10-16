require_relative '../spec_helper'

RSpec.describe 'Meme likes outage recovery' do
  let(:helper) { Object.new.extend(MemeNavigationHelpers) }
  let(:url) { 'https://i.redd.it/likes-recovery.jpg' }

  before do
    allow(RedisService).to receive(:fetch).and_wrap_original do |_, *_, &fallback|
      fallback.call
    end
  end

  it 'returns zero on a database connection failure and recovers on the next call' do
    allow(DB).to receive(:execute).and_raise(PG::ConnectionBad, 'simulated outage')
    expect(helper.get_meme_likes(url)).to eq(0)
    allow(DB).to receive(:execute).and_return([{ 'likes' => 7 }])
    expect(helper.get_meme_likes(url)).to eq(7)
  end

  it 'returns zero when the database connection pool times out' do
    allow(DB).to receive(:execute).and_raise(ConnectionPool::TimeoutError)
    expect(helper.get_meme_likes(url)).to eq(0)
  end

  it 'returns cached likes without querying an unavailable database' do
    allow(RedisService).to receive(:fetch).with("meme:likes:#{url}", ttl: 300).and_return(9)
    expect(DB).not_to receive(:execute)
    expect(helper.get_meme_likes(url)).to eq(9)
  end

  it 'does not access dependencies for a missing URL' do
    expect(RedisService).not_to receive(:fetch)
    expect(DB).not_to receive(:execute)
    expect(helper.get_meme_likes(nil)).to eq(0)
  end
end