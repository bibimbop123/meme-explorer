require_relative '../spec_helper'
require_relative '../../lib/services/legacy_impression_store'
require 'open3'
require 'rbconfig'
require 'timeout'

RSpec.describe LegacyImpressionStore do
  let(:binding) { SecureRandom.hex(32) }
  let(:id) { SecureRandom.hex(32) }
  let(:item) { { 'url' => '/images/funny1.jpeg', 'title' => 'Fixture', 'subreddit' => 'local', 'user_id' => nil } }
  after { RedisService.with_redis { |redis| redis.del(*described_class.keys(binding, nil), *described_class.keys(binding, 4)) } }

  it 'binds context to session and user without renewing individual expiry on lookup' do
    expect(described_class.issue(binding, nil, id, item)).to be true
    expect(described_class.lookup(binding, nil, id)).to include(status: :found, item: item)
    expect(described_class.lookup(SecureRandom.hex(32), nil, id)[:status]).to eq(:missing)
    expect(described_class.lookup(binding, 4, id)[:status]).to eq(:missing)
    RedisService.with_redis do |redis|
      redis.zadd(described_class.keys(binding, nil).first, Time.now.to_i - 1, id)
    end
    expect(described_class.lookup(binding, nil, id)[:status]).to eq(:missing)
  end

  it 'bounds concurrent issuance to twenty entries and retains valid retry lookups' do
    threads = 24.times.map do
      Thread.new { described_class.issue(binding, nil, SecureRandom.hex(32), item) }
    end
    expect(threads.map(&:value)).to all(eq(true))
    RedisService.with_redis do |redis|
      expiry, items = described_class.keys(binding, nil)
      expect(redis.zcard(expiry)).to eq(20)
      expect(redis.hlen(items)).to eq(20)
      expect(redis.ttl(items)).to be_between(1790, 1800)
    end
  end

  it 'rejects duplicate issuance without replacing context or renewing the deadline' do
    expect(described_class.issue(binding, nil, id, item)).to be true
    RedisService.with_redis do |redis|
      key = described_class.keys(binding, nil).first
      redis.zadd(key, Time.now.to_i + 60, id)
      deadline = redis.zscore(key, id)
      expect(described_class.issue(binding, nil, id, item.merge('title' => 'Replacement'))).to be false
      expect(redis.zscore(key, id)).to eq(deadline)
    end
    expect(described_class.lookup(binding, nil, id)).to include(status: :found, item: item)
  end

  it 'fails issuance closed without mutating a partially lost expiry or payload structure' do
    expect(described_class.issue(binding, nil, id, item)).to be true
    RedisService.with_redis do |redis|
      expiry, items = described_class.keys(binding, nil)
      redis.del(expiry)
      expect(described_class.issue(binding, nil, SecureRandom.hex(32), item)).to be false
      expect(redis.hlen(items)).to eq(1)
      expect(redis.exists?(expiry)).to be false
      redis.del(items)
      redis.zadd(expiry, Time.now.to_i + 60, id)
      expect(described_class.issue(binding, nil, SecureRandom.hex(32), item)).to be false
      expect(redis.zcard(expiry)).to eq(1)
      expect(redis.exists?(items)).to be false
    end
  end

  it 'prunes expired payloads and evicts earliest deadlines with ID ordering for ties' do
    ids = 20.times.map { |index| format('%064x', index + 1) }
    ids.each { |credential| expect(described_class.issue(binding, nil, credential, item)).to be true }
    RedisService.with_redis do |redis|
      expiry, items = described_class.keys(binding, nil)
      now = redis.time.first.to_i
      ids.each { |credential| redis.zadd(expiry, now + 600, credential) }
      redis.zadd(expiry, now - 1, ids.first)
      replacement = 'e' * 64
      expect(described_class.issue(binding, nil, replacement, item)).to be true
      expect(redis.hget(items, ids.first)).to be_nil
      expect(redis.zcard(expiry)).to eq(20)
      expect(described_class.issue(binding, nil, 'f' * 64, item)).to be true
      expect(redis.hget(items, ids[1])).to be_nil
      expect(redis.zscore(expiry, ids[1])).to be_nil
      expect(redis.hlen(items)).to eq(20)
      expect(redis.zscore(expiry, ids[2])).to eq((now + 600).to_f)
    end
  end

  it 'atomically bounds issuance across fresh Ruby processes with independent Redis connections' do
    # Fresh interpreters avoid inheriting the application's DB connections,
    # thread pools or Redis pool. Only the RedisService transport is adapted;
    # each process runs the real store validation and Lua issuance code.
    program = <<~'RUBY'
      require 'redis'
      require 'securerandom'
      require ARGV.fetch(0)
      class RedisService
        def self.with_redis
          @process_redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))
          yield @process_redis
        end
      end
      STDOUT.sync = true
      puts 'ready'
      STDIN.gets
      item = { 'url' => '/images/funny1.jpeg', 'title' => 'Process', 'subreddit' => 'local', 'user_id' => nil }
      8.times do
        abort 'issuance failed' unless LegacyImpressionStore.issue(ARGV.fetch(1), nil, SecureRandom.hex(32), item)
      end
      puts 'done'
    RUBY
    children = []
    begin
      4.times do
        children << Open3.popen3(RbConfig.ruby, '-e', program,
          File.expand_path('../../lib/services/legacy_impression_store.rb', __dir__), binding)
      end
      Timeout.timeout(20) do
        children.each { |_, output, _, _| expect(output.gets&.strip).to eq('ready') }
        children.each { |input, _, _, _| input.puts('start'); input.close }
        children.each do |_, output, error, waiter|
          expect(output.gets&.strip).to eq('done')
          expect(waiter.value.success?).to be(true), error.read
        end
      end
      RedisService.with_redis do |redis|
        expiry, items = described_class.keys(binding, nil)
        retained = redis.zrange(expiry, 0, -1)
        expect(retained.size).to eq(20)
        expect(redis.hkeys(items)).to match_array(retained)
        retained.each { |credential| expect(described_class.lookup(binding, nil, credential)[:status]).to eq(:found) }
      end
    ensure
      children.each do |input, output, error, waiter|
        Process.kill('KILL', waiter.pid) if waiter.alive?
        waiter.join
        [input, output, error].each { |stream| stream.close unless stream.closed? }
      end
    end
  end

  it 'fails closed for corrupt payloads without replacing their expiry' do
    expect(described_class.issue(binding, nil, id, item)).to be true
    payloads = ['{', '[]', JSON.generate(item.reject { |key, _| key == 'user_id' }),
      JSON.generate(item.merge('user_id' => 4)), JSON.generate(item.merge('title' => [])),
      JSON.generate(item.merge('url' => 'javascript:bad')), 'x' * (described_class::MAX_BYTES + 1)]
    RedisService.with_redis do |redis|
      expiry, items = described_class.keys(binding, nil)
      deadline = redis.zscore(expiry, id)
      payloads.each do |payload|
        redis.hset(items, id, payload)
        expect(described_class.lookup(binding, nil, id)[:status]).to eq(:unavailable)
        expect(redis.zscore(expiry, id)).to eq(deadline)
      end
    end
  end

  it 'fails closed for malformed context, wrong key types and unavailable Redis' do
    expect(described_class.issue(binding, nil, id, item.merge('url' => 'javascript:bad'))).to be false
    RedisService.with_redis { |redis| redis.set(described_class.keys(binding, nil).first, 'wrong') }
    expect(described_class.issue(binding, nil, id, item)).to be false
    expect(described_class.lookup(binding, nil, id)[:status]).to eq(:unavailable)
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(described_class.issue(binding, nil, id, item)).to be false
    expect(described_class.lookup(binding, nil, id)[:status]).to eq(:unavailable)
  end
end