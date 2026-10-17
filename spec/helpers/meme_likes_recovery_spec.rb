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
    expect(helper.instance_variable_get(:@likes_lookup_source)).to eq('unavailable')
    allow(DB).to receive(:execute).and_return([{ 'likes' => 7 }])
    expect(helper.get_meme_likes(url)).to eq(7)
    expect(helper.instance_variable_get(:@likes_lookup_source)).to eq('database_fallback')
  end

  it 'returns zero when the database connection pool times out' do
    allow(DB).to receive(:execute).and_raise(ConnectionPool::TimeoutError)
    expect(helper.get_meme_likes(url)).to eq(0)
  end

  it 'returns cached likes without querying an unavailable database' do
    allow(RedisService).to receive(:fetch).with("meme:likes:#{url}", ttl: 300).and_return(9)
    expect(DB).not_to receive(:execute)
    expect(helper.get_meme_likes(url)).to eq(9)
    expect(helper.instance_variable_get(:@likes_lookup_source)).to eq('cache_hit')
  end

  it 'does not access dependencies for a missing URL' do
    expect(RedisService).not_to receive(:fetch)
    expect(DB).not_to receive(:execute)
    expect(helper.get_meme_likes(nil)).to eq(0)
  end

  [0, 7].each do |count|
    it "caches a successful #{count} count and avoids repeated database queries" do
      allow(RedisService).to receive(:fetch).and_call_original
      key = "meme:likes:#{url}"
      RedisService.with_redis { |redis| redis.del(key) }
      begin
        expect(DB).to receive(:execute).with('SELECT likes FROM meme_stats WHERE url = ?', [url]).once.and_return([{ 'likes' => count }])
        expect(helper.get_meme_likes(url)).to eq(count)
        expect(helper.instance_variable_get(:@likes_lookup_source)).to eq('database_fallback')
        expect(helper.get_meme_likes(url)).to eq(count)
        expect(helper.instance_variable_get(:@likes_lookup_source)).to eq('cache_hit')
        RedisService.with_redis do |redis|
          expect(redis.ttl(key)).to be_between(295, 300)
        end
      ensure
        RedisService.with_redis { |redis| redis.del(key) }
      end
    end
  end
end