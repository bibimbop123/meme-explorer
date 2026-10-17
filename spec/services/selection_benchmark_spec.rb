# spec/services/selection_benchmark_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/selection_benchmark'

RSpec.describe SelectionBenchmark do
  describe 'batched recording' do
    it 'flushes nested stage samples in one pipeline and returns the result' do
      redis = double('redis')
      pipeline = double('pipeline')
      allow(RedisService).to receive(:with_redis).and_yield(redis)
      expect(redis).to receive(:pipelined).once.and_yield(pipeline)
      [:pool_lookup, :selection, :total].each do |stage|
        expect(pipeline).to receive(:rpush).with("#{described_class::REDIS_KEY_PREFIX}:#{stage}", kind_of(Numeric)).ordered
        expect(pipeline).to receive(:ltrim).with("#{described_class::REDIS_KEY_PREFIX}:#{stage}", -described_class::MAX_SAMPLES, -1).ordered
      end
      result = described_class.measure(batch: true) do
        described_class.measure(stage: :pool_lookup, batch: true) { :pool }
        described_class.measure(stage: :selection) { :selected }
      end
      expect(result).to eq(:selected)
      expect(Thread.current[described_class::BATCH_KEY]).to be_nil
    end

    it 'flushes completed samples on exception and restores standalone behavior' do
      expect do
        described_class.batch_records do
          described_class.record(12, stage: :selection)
          raise 'selection failed'
        end
      end.to raise_error('selection failed')
      expect(Thread.current[described_class::BATCH_KEY]).to be_nil
      described_class.record(18, stage: :selection)
      expect(described_class.stats(stage: :selection)[:count]).to eq(2)
    end

    it 'does not let telemetry failure change the result or retain batch state' do
      allow(RedisService).to receive(:with_redis).and_raise(Redis::CannotConnectError)
      expect(described_class.measure(batch: true) { :selected }).to eq(:selected)
      expect(Thread.current[described_class::BATCH_KEY]).to be_nil
    end

    it 'isolates simultaneous thread batches' do
      ready = Queue.new
      release = Queue.new
      workers = 2.times.map do |index|
        Thread.new do
          described_class.batch_records do
            described_class.record(index + 1, stage: :selection)
            ready << Thread.current[described_class::BATCH_KEY].object_id
            release.pop
          end
          Thread.current[described_class::BATCH_KEY]
        end
      end
      ids = 2.times.map { ready.pop }
      2.times { release << true }
      expect(workers.map(&:value)).to eq([nil, nil])
      expect(ids.uniq.size).to eq(2)
      expect(described_class.stats(stage: :selection)[:count]).to eq(2)
    end

    it 'bounds the pending buffer while retaining every sample' do
      described_class.batch_records do
        (described_class::MAX_BATCH_SAMPLES + 3).times do
          described_class.record(1, stage: :selection)
          expect(Thread.current[described_class::BATCH_KEY].size).to be < described_class::MAX_BATCH_SAMPLES
        end
      end
      expect(described_class.stats(stage: :selection)[:count]).to eq(described_class::MAX_BATCH_SAMPLES + 3)
    end
  end

  before(:each) do
    RedisService.with_redis do |redis|
      redis.del(
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:total",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:pool_lookup",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:pool_manager_lookup",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:reddit_fetch",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:selection"
      )
    end
  end

  describe '.measure' do
    it 'returns the block result unchanged' do
      result = described_class.measure { "the selected meme" }
      expect(result).to eq("the selected meme")
    end

    it 'records a latency sample as a side effect' do
      described_class.measure { sleep(0.01) }
      stats = described_class.stats
      expect(stats[:count]).to eq(1)
      expect(stats[:p50_ms]).to be >= 10.0
    end

    it 'propagates exceptions raised inside the block' do
      expect {
        described_class.measure { raise "boom" }
      }.to raise_error("boom")
    end
  end

  describe '.record and .stats' do
    it 'reports no data when the window is empty' do
      stats = described_class.stats
      expect(stats).to eq(count: 0, p50_ms: nil, p95_ms: nil, p99_ms: nil)
    end

    it 'computes percentiles over recorded samples' do
      (1..100).each { |ms| described_class.record(ms) }
      stats = described_class.stats

      expect(stats[:count]).to eq(100)
      expect(stats[:p50_ms]).to be_between(49, 51)
      expect(stats[:p95_ms]).to be_between(94, 96)
      expect(stats[:p99_ms]).to be_between(98, 100)
    end

    it 'keeps only the most recent MAX_SAMPLES entries' do
      (described_class::MAX_SAMPLES + 50).times { |i| described_class.record(i) }
      stats = described_class.stats

      expect(stats[:count]).to eq(described_class::MAX_SAMPLES)
    end

    it 'does not raise when Redis is unavailable' do
      allow(RedisService).to receive(:with_redis).and_raise(Redis::BaseError.new("down"))
      expect { described_class.record(5.0) }.not_to raise_error
    end

    it 'appends and trims using one connection and one pipeline' do
      pipeline = double('pipeline')
      redis = double('redis')
      expect(RedisService).to receive(:with_redis).once.and_yield(redis)
      expect(redis).to receive(:pipelined).once.and_yield(pipeline)
      key = "#{described_class::REDIS_KEY_PREFIX}:selection"
      expect(pipeline).to receive(:rpush).with(key, 12.35).ordered
      expect(pipeline).to receive(:ltrim).with(key, -described_class::MAX_SAMPLES, -1).ordered
      described_class.record(12.345, stage: :selection)
    end
  end

  describe 'stages' do
    it 'keeps separate rolling windows per stage' do
      described_class.record(10, stage: :pool_lookup)
      described_class.record(200, stage: :pool_lookup)
      described_class.record(1, stage: :selection)

      expect(described_class.stats(stage: :pool_lookup)[:count]).to eq(2)
      expect(described_class.stats(stage: :selection)[:count]).to eq(1)
      expect(described_class.stats(stage: :total)[:count]).to eq(0)
    end

    it 'defaults to the :total stage when none is specified' do
      described_class.record(42)
      expect(described_class.stats[:count]).to eq(1)
      expect(described_class.stats(stage: :pool_lookup)[:count]).to eq(0)
    end

    it 'measure records under the given stage' do
      described_class.measure(stage: :pool_lookup) { "pool" }
      expect(described_class.stats(stage: :pool_lookup)[:count]).to eq(1)
      expect(described_class.stats(stage: :total)[:count]).to eq(0)
    end

    it 'stage_breakdown reports every stage together' do
      described_class.record(5, stage: :total)
      described_class.record(3, stage: :pool_lookup)
      described_class.record(1, stage: :pool_manager_lookup)
      described_class.record(2, stage: :reddit_fetch)
      described_class.record(2, stage: :selection)

      breakdown = described_class.stage_breakdown
      expect(breakdown[:total][:count]).to eq(1)
      expect(breakdown[:pool_lookup][:count]).to eq(1)
      expect(breakdown[:pool_manager_lookup][:count]).to eq(1)
      expect(breakdown[:reddit_fetch][:count]).to eq(1)
      expect(breakdown[:selection][:count]).to eq(1)
    end

    it 'isolates :pool_manager_lookup and :reddit_fetch as distinct sub-stages of :pool_lookup' do
      described_class.record(500, stage: :reddit_fetch) # simulates a slow real network call
      described_class.record(2, stage: :pool_manager_lookup)

      expect(described_class.stats(stage: :reddit_fetch)[:p50_ms]).to eq(500.0)
      expect(described_class.stats(stage: :pool_manager_lookup)[:p50_ms]).to eq(2.0)
      # they don't bleed into each other or into :pool_lookup
      expect(described_class.stats(stage: :pool_lookup)[:count]).to eq(0)
    end
  end
end
