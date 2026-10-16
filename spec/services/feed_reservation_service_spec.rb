require_relative '../spec_helper'
require_relative '../../lib/services/feed_reservation_service'
require 'timeout'

RSpec.describe MemeExplorer::FeedReservationService do
  let(:identity) { SecureRandom.hex(32) }
  let(:content) { '/fixture.jpg' }
  let(:history) { "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history" }
  after do
    RedisService.with_redis { |redis| redis.del(*described_class.send(:keys, identity), history) }
  end

  it 'allows one unseen-admission winner across independent connections without writing history' do
    connections = 2.times.map { Redis.new(url: ENV.fetch('REDIS_URL')) }
    ready, start = Queue.new, Queue.new
    keys = [*described_class.send(:keys, identity), history]
    threads = connections.map do |redis|
      Thread.new do
        ready << true
        start.pop
        redis.eval(described_class::ACQUIRE_UNSEEN, keys: keys,
          argv: [Digest::SHA256.hexdigest(content), SecureRandom.hex(32), described_class::TTL,
                 described_class::LIMIT, content, MemeExplorer::ViewingHistoryService::HISTORY_TTL])
      end
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { start << true }
    expect(threads.map(&:value).sort).to eq([1, 2])
    RedisService.with_redis do |redis|
      expect(redis.exists?(history)).to eq(false)
      expect(redis.zcard(keys.first)).to eq(1)
      expect(redis.hlen(keys[1])).to eq(1)
    end
  ensure
    2.times { start << true } if start
    threads&.each(&:join)
    connections&.each(&:close)
  end

  it 'preserves acknowledged history score and expiry when rejecting repeated admission' do
    score = Time.now.to_f - 10
    RedisService.with_redis do |redis|
      redis.zadd(history, score, content)
      redis.expire(history, 60)
    end
    2.times { expect(described_class.acquire_unseen(identity, content)).to eq(status: :already_acknowledged) }
    RedisService.with_redis do |redis|
      expect(redis.zscore(history, content)).to eq(score)
      expect(redis.ttl(history)).to be_between(58, 60)
      expect(redis.exists?(described_class.send(:keys, identity).first)).to eq(false)
    end
  end

  it 'distinguishes invalid unseen admission from Redis unavailability' do
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(described_class.acquire_unseen('invalid', content)).to eq(status: :invalid)
    expect(RedisService).not_to have_received(:with_redis)
    expect(described_class.acquire_unseen(identity, content)).to eq(status: :unavailable)
  end

  it 'reserves once and releases only with the owning token' do
    result = described_class.acquire(identity, content)
    expect(result[:status]).to eq(:reserved)
    expect(described_class.acquire(identity, content)).to eq(status: :already_reserved)
    expect(described_class.release(identity, content, SecureRandom.hex(32))).to eq(false)
    expect(described_class.release(identity, content, result[:token])).to eq(true)
    expect(described_class.release(identity, content, result[:token])).to eq(false)
  end

  it 'rejects malformed content consistently before Redis access across all lease operations' do
    token = SecureRandom.hex(32)
    malformed = [nil, 42, [], '', ' ', 'x' * 4097, "\xFF".dup.force_encoding(Encoding::UTF_8)]
    allow(RedisService).to receive(:with_redis).and_call_original
    malformed.each do |value|
      expect(described_class.acquire(identity, value)).to eq(status: :invalid)
      expect(described_class.acquire_unseen(identity, value)).to eq(status: :invalid)
      expect(described_class.validate(identity, value, token)).to eq(status: :invalid)
      expect(described_class.release(identity, value, token)).to eq(false)
    end
    expect(RedisService).not_to have_received(:with_redis)
  end

  it 'preserves owner metadata when release encounters a wrong-type expiry key' do
    lease = described_class.acquire(identity, content)
    expiry, owners = described_class.send(:keys, identity)
    member = Digest::SHA256.hexdigest(content)
    RedisService.with_redis do |redis|
      redis.del(expiry)
      redis.set(expiry, 'wrong-type')
    end
    expect(described_class.release(identity, content, lease[:token])).to eq(false)
    RedisService.with_redis do |redis|
      expect(redis.hget(owners, member)).to eq(lease[:token])
      redis.del(expiry)
      redis.zadd(expiry, Time.now.to_f + described_class::TTL, member)
    end
    expect(described_class.release(identity, content, lease[:token])).to eq(true)
  end

  it 'rejects wrong-type acquire keys without pruning expired metadata' do
    expiry, owners = described_class.send(:keys, identity)
    member = Digest::SHA256.hexdigest(content)
    RedisService.with_redis do |redis|
      redis.zadd(expiry, 0, member)
      redis.set(owners, 'wrong-type')
    end
    expect(described_class.acquire(identity, content)).to eq(status: :unavailable)
    RedisService.with_redis do |redis|
      expect(redis.zscore(expiry, member)).to eq(0)
      expect(redis.get(owners)).to eq('wrong-type')
      redis.del(owners)
    end
    expect(described_class.acquire(identity, content)[:status]).to eq(:reserved)
  end

  it 'enforces a bounded active limit' do
    described_class::LIMIT.times { |i| expect(described_class.acquire(identity, "/#{i}.jpg")[:status]).to eq(:reserved) }
    expect(described_class.acquire(identity, '/extra.jpg')).to eq(status: :limit_reached)
  end

  it 'validates only the active session/content/token association without renewal' do
    token = described_class.acquire(identity, content)[:token]
    expiry = described_class.send(:keys, identity).first
    score = RedisService.with_redis { |redis| redis.zscore(expiry, Digest::SHA256.hexdigest(content)) }
    expect(described_class.validate(identity, content, token)).to eq(status: :active)
    expect(described_class.validate(SecureRandom.hex(32), content, token)).to eq(status: :invalid)
    expect(described_class.validate(identity, '/other.jpg', token)).to eq(status: :invalid)
    expect(described_class.validate(identity, content, SecureRandom.hex(32))).to eq(status: :invalid)
    expect(RedisService.with_redis { |redis| redis.zscore(expiry, Digest::SHA256.hexdigest(content)) }).to eq(score)
    described_class.release(identity, content, token)
    expect(described_class.validate(identity, content, token)).to eq(status: :invalid)
  end

  it 'rejects expired owner metadata and rejects an old token after reacquisition' do
    token = described_class.acquire(identity, content)[:token]
    RedisService.with_redis do |redis|
      redis.zadd(described_class.send(:keys, identity).first, 0, Digest::SHA256.hexdigest(content))
    end
    expect(described_class.validate(identity, content, token)).to eq(status: :invalid)
    successor = described_class.acquire(identity, content)[:token]
    expect(described_class.validate(identity, content, token)).to eq(status: :invalid)
    expect(described_class.validate(identity, content, successor)).to eq(status: :active)
  end

  it 'distinguishes validation unavailability from invalid credentials' do
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(described_class.validate(identity, content, SecureRandom.hex(32))).to eq(status: :unavailable)
    expect(described_class.validate(identity, content, 'bad')).to eq(status: :invalid)
  end

  it 'prunes expired leases and never lets an old token release its successor' do
    old = described_class.acquire(identity, content)
    expiry, owners = described_class.send(:keys, identity)
    RedisService.with_redis { |redis| redis.zadd(expiry, 0, Digest::SHA256.hexdigest(content)) }
    successor = described_class.acquire(identity, content)
    expect(successor[:status]).to eq(:reserved)
    expect(described_class.release(identity, content, old[:token])).to eq(false)
    expect(described_class.release(identity, content, successor[:token])).to eq(true)
    RedisService.with_redis do |redis|
      expect(redis.ttl(expiry)).to be_between(-2, described_class::TTL)
      expect(redis.hlen(owners)).to eq(0)
    end
  end

  it 'isolates sessions and rejects malformed input before Redis access' do
    expect(described_class.acquire(identity, content)[:status]).to eq(:reserved)
    other = SecureRandom.hex(32)
    expect(described_class.release(other, content, SecureRandom.hex(32))).to eq(false)
    allow(RedisService).to receive(:with_redis).and_call_original
    expect(described_class.acquire('ip-address', content)).to eq(status: :invalid)
    expect(described_class.acquire(identity, 'x' * 4097)).to eq(status: :invalid)
    expect(RedisService).not_to have_received(:with_redis)
  end

  it 'reports Redis unavailability without inventing a reservation' do
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(described_class.acquire(identity, content)).to eq(status: :unavailable)
    expect(described_class.release(identity, content, SecureRandom.hex(32))).to eq(false)
  end

  it 'allows the same content in separate sessions without changing viewed history' do
    other = SecureRandom.hex(32)
    expect(described_class.acquire(identity, content)[:status]).to eq(:reserved)
    result = described_class.acquire(other, content)
    expect(result[:status]).to eq(:reserved)
    expect(MemeExplorer::ViewingHistoryService.get_seen_memes(identity)).to eq([])
    expect(described_class.release(other, content, result[:token])).to eq(true)
  ensure
    RedisService.with_redis { |redis| redis.del(*described_class.send(:keys, other)) } if other
  end

  it 'expires both metadata keys and recovers capacity after leases expire' do
    described_class::LIMIT.times { |i| described_class.acquire(identity, "/#{i}.jpg") }
    expiry, owners = described_class.send(:keys, identity)
    RedisService.with_redis do |redis|
      [expiry, owners].each { |key| expect(redis.ttl(key)).to be_between(1, described_class::TTL) }
      redis.zrange(expiry, 0, -1).each { |member| redis.zadd(expiry, 0, member) }
    end
    expect(described_class.acquire(identity, '/replacement.jpg')[:status]).to eq(:reserved)
    RedisService.with_redis do |redis|
      expect(redis.zcard(expiry)).to eq(1)
      expect(redis.hlen(owners)).to eq(1)
    end
  end

  it 'fails safely on unexpected Redis errors and invalid release tokens' do
    allow(RedisService).to receive(:with_redis).and_raise(Redis::CommandError, 'fixture error')
    expect(described_class.acquire(identity, content)).to eq(status: :unavailable)
    expect(described_class.release(identity, content, SecureRandom.hex(32))).to eq(false)
    expect(described_class.release(identity, content, 'bad-token')).to eq(false)
    allow(RedisService).to receive(:with_redis).and_call_original
  end

  it 'allows only one winner from independent concurrent Redis connections' do
    connections = 2.times.map { Redis.new(url: ENV.fetch('REDIS_URL')) }
    keys = described_class.send(:keys, identity)
    ready = Queue.new
    start = Queue.new
    threads = connections.map do |redis|
      Thread.new do
        ready << true
        start.pop
        redis.eval(described_class::ACQUIRE, keys: keys,
          argv: [Digest::SHA256.hexdigest(content), SecureRandom.hex(32), described_class::TTL, described_class::LIMIT])
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    expect(threads.map(&:value).sort).to eq([1, 2])
  ensure
    connections&.each(&:close)
  end
end