require_relative '../spec_helper'
require_relative '../../lib/concerns/performance_profiler'

RSpec.describe PerformanceProfiler do
  around do |example|
    previous = described_class.metrics.transform_values(&:dup)
    described_class.reset!
    example.run
  ensure
    described_class.instance_variable_set(:@metrics, previous)
  end

  it 'returns work results and aggregates timing measurements' do
    now = Time.utc(2026, 10, 15)
    allow(Time).to receive(:now).and_return(now, now + 0.02, now, now + 0.04)
    allow(AppLogger).to receive(:info)
    expect(described_class.profile('work') { :result }).to eq(:result)
    described_class.profile('work') { :again }
    expect(described_class.summary.first).to include(label: 'work', calls: 2, avg_ms: 30.0, min_ms: 20.0, max_ms: 40.0, total_ms: 60.0)
  end

  it 'warns on slow work and propagates failures without recording success' do
    now = Time.utc(2026, 10, 15)
    allow(Time).to receive(:now).and_return(now, now + 2)
    allow(AppLogger).to receive(:warn)
    described_class.profile('slow', threshold_ms: 100) { true }
    expect(AppLogger).to have_received(:warn).with(include('[SLOW] slow'))
    expect { described_class.profile('failed') { raise ArgumentError, 'failure' } }.to raise_error(ArgumentError, 'failure')
    expect(described_class.metrics).not_to have_key('failed')
  end

  it 'profiles parameterized queries and HTTP blocks without replacing results' do
    expect(DB).to receive(:execute).with('SELECT ? AS value', [1]).and_return([{ 'value' => 1 }])
    expect(described_class.profile_query('SELECT ? AS value', [1])).to eq([{ 'value' => 1 }])
    expect(described_class.profile_http('https://example.com') { :response }).to eq(:response)
    expect(described_class.metrics.keys).to include('SQL: SELECT ? AS value', 'HTTP: https://example.com')
  end

  it 'sorts summaries by total time and clears metrics' do
    described_class.record_metric('small', 1.0)
    described_class.record_metric('large', 20.0)
    expect(described_class.summary.map { |row| row[:label] }).to eq(['large', 'small'])
    described_class.reset!
    expect(described_class.summary).to eq([])
  end

  it 'returns memory-profile work results and safely handles measurement errors' do
    allow(described_class).to receive(:get_memory_usage).and_return(1_048_576, 2_097_152)
    allow(AppLogger).to receive(:info)
    expect(described_class.profile_memory('allocation') { :value }).to eq(:value)
    expect(AppLogger).to have_received(:info).with(include('1.0MB delta'))
  end

  it 'falls back to zero if GC measurement fails' do
    allow(GC).to receive(:stat).and_raise(StandardError)
    expect(described_class.send(:get_memory_usage)).to eq(0)
  end
end