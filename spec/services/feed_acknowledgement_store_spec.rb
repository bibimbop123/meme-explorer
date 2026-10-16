require_relative '../spec_helper'
require_relative '../../lib/services/feed_acknowledgement_store'

RSpec.describe MemeExplorer::FeedAcknowledgementStore do
  let(:identity) { SecureRandom.hex(32) }
  after { RedisService.with_redis { |r| r.del(*described_class.send(:keys, identity)) } }

  it 'binds metadata to session and token without renewing expiry on lookup' do
    token = described_class.issue(identity, '/fixture.jpg')[:token]
    keys = described_class.send(:keys, identity)
    before = RedisService.with_redis { |r| r.zscore(keys.first, Digest::SHA256.hexdigest(token)) }
    expect(described_class.lookup(identity, token)).to eq(status: :valid, content: '/fixture.jpg')
    expect(described_class.lookup(SecureRandom.hex(32), token)).to eq(status: :invalid)
    expect(described_class.lookup(identity, SecureRandom.hex(32))).to eq(status: :invalid)
    expect(RedisService.with_redis { |r| r.zscore(keys.first, Digest::SHA256.hexdigest(token)) }).to eq(before)
  end

  it 'bounds issuance, prunes expired metadata and rejects expired credentials' do
    tokens = described_class::LIMIT.times.map { |i| described_class.issue(identity, "/#{i}.jpg")[:token] }
    expect(described_class.issue(identity, '/extra.jpg')).to eq(status: :limit_reached)
    expiry, metadata = described_class.send(:keys, identity)
    RedisService.with_redis { |r| r.zadd(expiry, 0, Digest::SHA256.hexdigest(tokens.first)) }
    expect(described_class.lookup(identity, tokens.first)).to eq(status: :invalid)
    expect(described_class.issue(identity, '/replacement.jpg')[:status]).to eq(:issued)
    RedisService.with_redis do |r|
      expect(r.hlen(metadata)).to eq(described_class::LIMIT)
      [expiry, metadata].each { |key| expect(r.ttl(key)).to be_between(1, described_class::TTL) }
    end
  end

  it 'rejects malformed input and distinguishes infrastructure failure' do
    expect(described_class.issue('bad', '/a')).to eq(status: :invalid)
    expect(described_class.issue(identity, 'x' * 4097)).to eq(status: :invalid)
    expect(described_class.lookup(identity, 'bad')).to eq(status: :invalid)
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(described_class.issue(identity, '/a')).to eq(status: :unavailable)
    expect(described_class.lookup(identity, SecureRandom.hex(32))).to eq(status: :unavailable)
  end

  it 'keeps issued credentials separate from viewed history and active leases' do
    token = described_class.issue(identity, '/fixture.jpg')[:token]
    expect(described_class.lookup(identity, token)[:status]).to eq(:valid)
    expect(MemeExplorer::ViewingHistoryService.get_seen_memes(identity)).to eq([])
  end

  it 'rejects corrupt or oversized stored metadata without returning content' do
    token = described_class.issue(identity, '/fixture.jpg')[:token]
    metadata = described_class.send(:keys, identity).last
    ['{broken', '[]', '{"content":42}', '{"content":" "}', JSON.generate('content' => 'x' * 4097), 'x' * 32_769].each do |payload|
      RedisService.with_redis { |r| r.hset(metadata, Digest::SHA256.hexdigest(token), payload) }
      expect(described_class.lookup(identity, token)).to eq(status: :unavailable)
    end
  end

  it 'enforces the last capacity slot across independent concurrent connections' do
    (described_class::LIMIT - 1).times { |i| described_class.issue(identity, "/#{i}.jpg") }
    connections = 2.times.map { Redis.new(url: ENV.fetch('REDIS_URL')) }
    ready = Queue.new
    start = Queue.new
    threads = connections.map do |redis|
      Thread.new do
        ready << true
        start.pop
        redis.eval(described_class::ISSUE, keys: described_class.send(:keys, identity),
          argv: [Digest::SHA256.hexdigest(SecureRandom.hex(32)), JSON.generate('content' => '/concurrent.jpg'), described_class::TTL, described_class::LIMIT])
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    expect(threads.map(&:value).sort).to eq([1, 2])
    RedisService.with_redis do |r|
      expiry, metadata = described_class.send(:keys, identity)
      expect(r.zcard(expiry)).to eq(described_class::LIMIT)
      expect(r.hlen(metadata)).to eq(described_class::LIMIT)
    end
  ensure
    connections&.each(&:close)
  end
end