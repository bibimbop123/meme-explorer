require_relative '../spec_helper'

RSpec.describe LegacyImpressionMetrics do
  let(:day) { Time.now.utc.to_date }
  before { RedisService.with_redis { |redis| redis.del(described_class.key(day)) } }
  after do
    allow(RedisService).to receive(:with_redis).and_call_original
    RedisService.with_redis { |redis| redis.del(described_class.key(day)) }
  end

  it 'counts fixed events atomically with bounded retention' do
    threads = 8.times.map { Thread.new { 5.times { described_class.record('ack_recorded') } } }
    threads.each(&:value)
    expect(described_class.record('arbitrary-secret-label')).to be false
    expect(described_class.snapshot).to include(available: true,
      counts: include('ack_recorded' => 40, 'ack_duplicate' => 0))
    RedisService.with_redis do |redis|
      expect(redis.hkeys(described_class.key(day))).to eq(['ack_recorded'])
      expect(redis.ttl(described_class.key(day))).to be_between(172_790, 172_800)
    end
  end

  it 'distinguishes an empty available store from unavailable telemetry' do
    expect(described_class.snapshot).to include(available: true, counts: include('issue_external' => 0))
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(described_class.record('issue_external')).to be false
    expect(described_class.snapshot).to eq(available: false, counts: nil)
  end

  it 'does not raise if telemetry storage fails' do
    allow(RedisService).to receive(:with_redis).and_raise(StandardError, 'unavailable')
    expect(described_class.record('ack_recorded')).to be false
    expect(described_class.snapshot).to eq(available: false, counts: nil)
  end

  it 'uses UTC buckets even when the local date is different' do
    local_time = Time.new(2026, 10, 17, 23, 30, 0, '-07:00')
    allow(Time).to receive(:now).and_return(local_time)
    expect(described_class.record('issue_external')).to be true
    expect(described_class.snapshot).to include(date: '2026-10-18', counts: include('issue_external' => 1))
  ensure
    RedisService.with_redis { |redis| redis.del(described_class.key(Date.new(2026, 10, 18))) }
  end

  it 'reports corrupt counters as unavailable instead of zero' do
    RedisService.with_redis { |redis| redis.hset(described_class.key(day), 'ack_recorded', 'corrupt') }
    expect(described_class.snapshot).to eq(available: false, counts: nil)
  end
end