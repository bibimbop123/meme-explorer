require_relative '../spec_helper'
require_relative '../../lib/concerns/distributed_lock'

RSpec.describe DistributedLock do
  let(:helper) { Object.new.extend(described_class) }
  let(:redis) { double('isolated lock Redis') }

  before { stub_const('REDIS', redis) }

  it 'acquires atomically and releases with the same ownership token' do
    token = nil
    expect(redis).to receive(:set).with('lock:refresh', kind_of(String), nx: true, ex: 30) { |_, value, **_| token = value; 'OK' }
    expect(redis).to receive(:eval).with(include('redis.call("get", KEYS[1]) == ARGV[1]'), keys: ['lock:refresh'], argv: kind_of(Array)) do |_, **options|
      expect(options[:argv]).to eq([token])
      1
    end
    executed = false
    expect(helper.with_redis_lock('refresh', ttl: 30) { executed = true }).to eq(true)
    expect(executed).to eq(true)
  end

  it 'does not execute or release when acquisition is denied' do
    allow(redis).to receive(:set).and_return(nil)
    expect(redis).not_to receive(:eval)
    expect(helper.with_redis_lock('refresh') { raise 'must not execute' }).to eq(false)
  end

  it 'releases on work failure and propagates the original exception for retry' do
    allow(redis).to receive(:set).and_return('OK')
    expect(redis).to receive(:eval).and_return(1)
    expect { helper.with_redis_lock('refresh') { raise ArgumentError, 'work failed' } }.to raise_error(ArgumentError, 'work failed')
  end

  it 'does not mask work failure when release also fails' do
    allow(redis).to receive(:set).and_return('OK')
    allow(redis).to receive(:eval).and_raise(Redis::CannotConnectError)
    expect { helper.with_redis_lock('refresh') { raise ArgumentError, 'original failure' } }.to raise_error(ArgumentError, 'original failure')
  end

  it 'bounds retries and sleeps only between attempts' do
    expect(helper).to receive(:with_redis_lock).with('refresh', ttl: 20).exactly(3).times.and_return(false)
    expect(helper).to receive(:sleep).with(0.1).twice
    expect(helper.with_redis_lock_retry('refresh', ttl: 20, max_attempts: 3, retry_delay: 0.1) {}).to eq(false)
  end

  it 'stops retrying immediately after acquisition' do
    expect(helper).to receive(:with_redis_lock).twice.and_return(false, true)
    expect(helper).to receive(:sleep).once
    expect(helper.with_redis_lock_retry('refresh') {}).to eq(true)
  end

  it 'checks held state and safely declines when Redis is disabled' do
    expect(redis).to receive(:exists?).with('lock:refresh').and_return(true)
    expect(helper.lock_held?('refresh')).to eq(true)
    stub_const('REDIS', nil)
    expect(helper.lock_held?('refresh')).to eq(false)
    expect(helper.with_redis_lock('refresh') { raise 'must not execute' }).to eq(false)
  end
end