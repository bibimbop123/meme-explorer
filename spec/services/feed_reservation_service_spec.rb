require_relative '../spec_helper'
require_relative '../../lib/services/feed_reservation_service'

RSpec.describe MemeExplorer::FeedReservationService do
  let(:identity) { SecureRandom.hex(32) }
  let(:content) { '/fixture.jpg' }
  after do
    RedisService.with_redis { |redis| redis.del(*described_class.send(:keys, identity)) }
  end

  it 'reserves once and releases only with the owning token' do
    result = described_class.acquire(identity, content)
    expect(result[:status]).to eq(:reserved)
    expect(described_class.acquire(identity, content)).to eq(status: :already_reserved)
    expect(described_class.release(identity, content, SecureRandom.hex(32))).to eq(false)
    expect(described_class.release(identity, content, result[:token])).to eq(true)
    expect(described_class.release(identity, content, result[:token])).to eq(false)
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