require_relative '../spec_helper'
require_relative '../../lib/services/discovery_preferences_store'

RSpec.describe DiscoveryPreferencesStore do
  let(:identity) { SecureRandom.hex(32) }
  let(:key) { "discovery:preferences:v1:#{identity}" }

  after { REDIS_POOL.with { |redis| redis.del(key) } }

  it 'reads empty state without creating a key' do
    expect(described_class.call(identity)).to eq('hidden' => [], 'revision' => 0)
    expect(REDIS_POOL.with { |redis| redis.exists?(key) }).to be false
  end

  it 'revokes state atomically and rejects late reads and writes without extending marker expiry' do
    described_class.call(identity, action: 'hide', community: 'cats')
    described_class.revoke(identity)
    REDIS_POOL.with { |redis| redis.expire(key, 120) }
    %w[read hide restore undo reset].each do |action|
      expect { described_class.call(identity, action: action, community: 'dogs') }.to raise_error(described_class::Revoked)
    end
    expect(JSON.parse(REDIS_POOL.with { |redis| redis.get(key) })).to eq('revoked' => true)
    expect(REDIS_POOL.with { |redis| redis.ttl(key) }).to be_between(1, 120)
  end

  it 'keeps Undo on duplicate Hide and clears it when its target is restored' do
    described_class.call(identity, action: 'hide', community: 'CATS')
    described_class.call(identity, action: 'hide', community: 'dogs')
    state = described_class.call(identity, action: 'hide', community: 'cats')
    expect(state).to include('hidden' => %w[cats dogs], 'undo' => 'dogs', 'revision' => 3)
    expect(described_class.call(identity, action: 'undo')['hidden']).to eq(['cats'])
    state = described_class.call(identity, action: 'restore', community: 'cats')
    expect(state['hidden']).to eq([])
    expect(state).not_to have_key('undo')
  end

  it 'caps exclusions and preserves expiry across updates and Reset' do
    20.times { |i| described_class.call(identity, action: 'hide', community: "community_#{i}") }
    REDIS_POOL.with { |redis| redis.expire(key, 120) }
    expect(described_class.call(identity, action: 'hide', community: 'extra')).to eq(:cap)
    expect(described_class.call(identity)['hidden'].size).to eq(20)
    expect(described_class.call(identity, action: 'reset')['hidden']).to eq([])
    expect(REDIS_POOL.with { |redis| redis.ttl(key) }).to be_between(1, 120)
  end

  it 'atomically retains simultaneous hides with distinct revisions' do
    results = 10.times.map do |i|
      Thread.new { described_class.call(identity, action: 'hide', community: "community_#{i}") }
    end.map(&:value)
    expect(results.map { |state| state['revision'] }.sort).to eq((1..10).to_a)
    expect(described_class.call(identity)['hidden'].sort).to eq(10.times.map { |i| "community_#{i}" }.sort)
  end

  it 'rejects invalid inputs and fails explicitly on store outage' do
    expect { described_class.call('bad') }.to raise_error(ArgumentError)
    expect { described_class.call(identity, action: 'hide', community: '<script>') }.to raise_error(ArgumentError)
    allow(REDIS_POOL).to receive(:with).and_raise(Redis::CannotConnectError)
    expect { described_class.call(identity) }.to raise_error(described_class::Unavailable)
    allow(REDIS_POOL).to receive(:with).and_call_original
  end
end