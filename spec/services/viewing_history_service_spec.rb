require_relative '../spec_helper'
require_relative '../../lib/services/viewing_history_service'

RSpec.describe MemeExplorer::ViewingHistoryService do
  let(:visitor) { "history-spec-#{SecureRandom.hex(12)}" }

  after { described_class.clear_history(visitor) }

  it 'batches ordered history writes without depending on command replies' do
    redis = double('Redis connection')
    pipeline = double('Redis pipeline')
    allow(RedisService).to receive(:with_redis).and_yield(redis)
    allow(Time).to receive(:now).and_return(Time.at(1_800_000_000))
    key = "viewing_history:#{visitor}"
    expect(redis).to receive(:pipelined).once.and_yield(pipeline)
    expect(pipeline).to receive(:zremrangebyscore).with(key, '-inf', 1_800_000_000.0 - described_class::HISTORY_TTL).ordered
    expect(pipeline).to receive(:zadd).with(key, 1_800_000_000.0, 'batched').ordered
    expect(pipeline).to receive(:zremrangebyrank).with(key, 0, -(described_class::MAX_HISTORY_SIZE + 1)).ordered
    expect(pipeline).to receive(:expire).with(key, described_class::HISTORY_TTL).ordered
    described_class.mark_seen(visitor, 'batched')
    allow(redis).to receive(:del) # after-hook cleanup uses the same stubbed connection
  end

  it 'fails soft when the pipeline raises' do
    redis = double('Redis connection')
    allow(RedisService).to receive(:with_redis).and_yield(redis)
    allow(redis).to receive(:pipelined).and_raise(Redis::CannotConnectError)
    allow(redis).to receive(:del)
    expect { described_class.mark_seen(visitor, 'offline') }.not_to raise_error
  end

  it 'persists seen identifiers and supports membership, count, and clear' do
    described_class.mark_seen(visitor, 'first')
    described_class.mark_seen(visitor, 'second')
    expect(described_class.get_seen_memes(visitor)).to contain_exactly('first', 'second')
    expect(described_class.seen?(visitor, 'first')).to be true
    expect(described_class.seen?(visitor, 'missing')).to be false
    expect(described_class.seen_count(visitor)).to eq(2)
    described_class.clear_history(visitor)
    expect(described_class.get_seen_memes(visitor)).to eq([])
  end

  it 'deduplicates repeated identifiers and expires history' do
    2.times { described_class.mark_seen(visitor, 'same') }
    expect(described_class.seen_count(visitor)).to eq(1)
    stats = described_class.get_stats(visitor)
    expect(stats[:total_seen]).to eq(1)
    expect(stats[:ttl_seconds]).to be_between(1, described_class::HISTORY_TTL)
  end

  it 'bounds history growth' do
    (described_class::MAX_HISTORY_SIZE + 5).times do |index|
      described_class.mark_seen(visitor, "meme-#{index}")
    end
    expect(described_class.seen_count(visitor)).to eq(described_class::MAX_HISTORY_SIZE)
  end

  it 'prunes old entries even when the session key remains active' do
    key = "viewing_history:#{visitor}"
    RedisService.with_redis do |redis|
      redis.zadd(key, Time.now.to_f - described_class::HISTORY_TTL - 1, 'expired')
      redis.zadd(key, Time.now.to_f, 'recent')
      redis.expire(key, described_class::HISTORY_TTL)
    end
    expect(described_class.get_seen_memes(visitor)).to eq(['recent'])
    described_class.mark_seen(visitor, 'new')
    expect(described_class.get_seen_memes(visitor)).to eq(%w[recent new])
  end

  it 'prunes expired scores and renews expiry during the write pipeline itself' do
    key = "viewing_history:#{visitor}"
    now = Time.now.to_f
    RedisService.with_redis do |redis|
      redis.zadd(key, now - described_class::HISTORY_TTL - 10, 'expired')
      redis.zadd(key, now - 10, 'recent')
      redis.expire(key, 60)
    end
    described_class.mark_seen(visitor, 'new')
    # Read directly: get_seen_memes also prunes and would mask a broken write.
    RedisService.with_redis do |redis|
      expect(redis.zrange(key, 0, -1)).to eq(%w[recent new])
      expect(redis.ttl(key)).to be_between(described_class::HISTORY_TTL - 5, described_class::HISTORY_TTL)
    end
  end

  it 'returns safe empty values during Redis unavailability' do
    allow(RedisService).to receive(:redis_available?).and_return(false)
    expect { described_class.mark_seen(visitor, 'offline') }.not_to raise_error
    expect(described_class.get_seen_memes(visitor)).to eq([])
    expect(described_class.seen_count(visitor)).to eq(0)
    expect(described_class.get_stats(visitor)).to eq({})
  end

  it 'ignores missing visitor identifiers' do
    expect(described_class.mark_seen(nil, 'meme')).to be_nil
    expect(described_class.get_seen_memes(nil)).to eq([])
    expect(described_class.seen?(nil, 'meme')).to be false
    expect(described_class.seen_count(nil)).to eq(0)
    expect(described_class.get_stats(nil)).to eq({})
  end
end