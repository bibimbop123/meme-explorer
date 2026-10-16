require_relative '../spec_helper'
require_relative '../../lib/services/viewing_history_service'

RSpec.describe MemeExplorer::ViewingHistoryService do
  let(:visitor) { "history-spec-#{SecureRandom.hex(12)}" }

  after { described_class.clear_history(visitor) }

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