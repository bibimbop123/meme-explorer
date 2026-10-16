require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Transactional pool publication' do
  let(:meme) { { 'url' => 'https://i.redd.it/published.jpg', 'subreddit' => 'funny', 'title' => 'Published' } }

  before do
    allow(MemePoolManager).to receive(:categorize_by_tier) do |memes|
      { random: memes, fresh: [], trending: [], surprise: [], diverse: [] }
    end
  end

  it 'publishes matching JSON, list, media and count with stable fallback IDs and TTLs' do
    expect(MemePoolManager.send(:store_in_pool, [meme])).to eq(1)
    id = Digest::SHA256.hexdigest(meme['url'])
    RedisService.with_redis do |redis|
      expect(redis.lrange('meme_pool:random_ids', 0, -1)).to eq([id])
      expect(JSON.parse(redis.hget('meme:data', id))).to eq(meme)
      expect(JSON.parse(redis.get('meme_pool:random'))).to eq([meme])
      expect(JSON.parse(redis.get('meme_pool'))).to eq([meme])
      expect(redis.get('meme_pool:count')).to eq('1')
      ['meme_pool', 'meme_pool:random_ids', 'meme_pool:count', 'meme_pool:fresh'].each do |key|
        expect(redis.ttl(key)).to be_between(21590, 21600)
      end
    end
    expect(MemePoolManager.send(:get_tier_pool, :random)).to eq([meme])
  end

  it 'clears previously populated tiers when the new snapshot has no eligible items' do
    RedisService.with_redis do |redis|
      redis.set('meme_pool:fresh', '[{"url":"old"}]')
      redis.rpush('meme_pool:fresh_ids', 'old')
    end
    expect(MemePoolManager.send(:store_in_pool, [meme])).to eq(1)
    expect(RedisService.get('meme_pool:fresh')).to eq([])
    expect(RedisService.lrange('meme_pool:fresh_ids')).to eq([])
  end

  it 'does not claim publication when Redis is unavailable' do
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(MemePoolManager.send(:store_in_pool, [meme])).to eq(0)
  end

  it 'leaves the old snapshot intact if transaction submission fails' do
    RedisService.set('meme_pool', [{ 'url' => '/retained.jpg' }])
    connection = double
    allow(connection).to receive(:watch).with('meme_pool').and_yield
    allow(connection).to receive(:unwatch)
    allow(connection).to receive(:multi).and_raise(Redis::CannotConnectError, 'Unavailable')
    allow(RedisService).to receive(:with_redis).and_yield(connection)
    expect(MemePoolManager.send(:store_in_pool, [meme])).to eq(0)
    expect(RedisService.get('meme_pool')).to eq([{ 'url' => '/retained.jpg' }])
  end

  it 'does not claim success for EXEC replies containing a command error' do
    allow(RedisService).to receive(:with_redis).and_return(['OK', Redis::CommandError.new('WRONGTYPE')])
    expect(MemePoolManager.send(:store_in_pool, [meme])).to eq(0)
  end

  it 'does not write an empty inventory' do
    expect(RedisService).not_to receive(:with_redis)
    expect(MemePoolManager.send(:store_in_pool, [])).to eq(0)
  end

  it 'rejects a stale merge without replacing newer inventory' do
    expect(MemePoolManager.send(:store_in_pool, [meme])).to eq(1)
    stale = meme.merge('url' => '/stale.jpg')
    expect(MemePoolManager.send(:store_in_pool, [stale], expected_pool: [])).to eq(0)
    expect(RedisService.get('meme_pool').map { |m| m['url'] }).to eq([meme['url']])
  end

  it 'publishes when the merge snapshot matches the current pool' do
    expect(MemePoolManager.send(:store_in_pool, [meme])).to eq(1)
    snapshot = RedisService.get('meme_pool')
    fresh = meme.merge('url' => '/new.jpg', 'id' => 'new-id')
    expect(MemePoolManager.send(:store_in_pool, [fresh, *snapshot], expected_pool: snapshot)).to eq(2)
    expect(RedisService.get('meme_pool').map { |m| m['url'] }).to eq(['/new.jpg', meme['url']])
  end

  it 'aborts EXEC when another connection changes the pool after WATCH' do
    redis = Redis.new(url: ENV.fetch('REDIS_URL'))
    allow(RedisService).to receive(:with_redis).and_wrap_original do |original, &block|
      original.call do |connection|
        allow(connection).to receive(:multi).and_wrap_original do |multi, &commands|
          redis.set('meme_pool', [{ 'url' => '/concurrent.jpg' }].to_json)
          multi.call(&commands)
        end
        block.call(connection)
      end
    end
    expect(MemePoolManager.send(:store_in_pool, [meme])).to eq(0)
    expect(RedisService.get('meme_pool')).to eq([{ 'url' => '/concurrent.jpg' }])
  ensure
    redis&.close
  end

  it 'captures the expected snapshot before adding generated IDs to retained records' do
    snapshot = [meme.dup]
    RedisService.set('meme_pool', snapshot)
    expect(snapshot.first).not_to have_key('id')
    expect(MemePoolManager.send(:store_in_pool, snapshot, expected_pool: snapshot)).to eq(1)
    expect(RedisService.get('meme_pool').first['id']).to eq(Digest::SHA256.hexdigest(meme['url']))
  end

  it 'clears WATCH after rejecting a stale snapshot before reusing the connection' do
    RedisService.with_redis do |connection|
      connection.set('meme_pool', [{ 'url' => '/current.jpg' }].to_json)
      allow(RedisService).to receive(:with_redis).and_yield(connection)
      expect(MemePoolManager.send(:store_in_pool, [meme], expected_pool: [])).to eq(0)
      other = Redis.new(url: ENV.fetch('REDIS_URL'))
      other.set('meme_pool', [{ 'url' => '/newer.jpg' }].to_json)
      replies = connection.multi { |transaction| transaction.ping }
      expect(replies).to eq(['PONG'])
    ensure
      other&.close
    end
  end
end