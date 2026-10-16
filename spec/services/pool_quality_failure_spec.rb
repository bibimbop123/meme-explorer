require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Pool quality evaluation failure' do
  let(:candidate) { { 'url' => '/candidate.jpg', 'title' => 'Candidate', 'subreddit' => 'cats' } }

  before do
    stub_const('QualityPipelineService', Class.new)
  end

  it 'returns only approved candidates when evaluation succeeds' do
    rejected = candidate.merge('url' => '/rejected.jpg')
    allow(QualityPipelineService).to receive(:passes_all_gates?).with(candidate).and_return(true)
    allow(QualityPipelineService).to receive(:passes_all_gates?).with(rejected).and_return(false)
    expect(MemePoolManager.send(:quality_filter, [candidate, rejected])).to eq([candidate])
  end

  it 'rejects the batch rather than returning unfiltered candidates after an error' do
    allow(QualityPipelineService).to receive(:passes_all_gates?).and_raise('Evaluation unavailable')
    expect(MemePoolManager.send(:quality_filter, [candidate])).to eq([])
  end

  it 'reports aggregate rejection stages without logging candidate or exception content' do
    rejected = candidate.merge('url' => '/rejected.jpg')
    allow(QualityPipelineService).to receive(:passes_all_gates?).with(candidate).and_return(true)
    allow(QualityPipelineService).to receive(:passes_all_gates?).with(rejected).and_return(false)
    expect(AppLogger).to receive(:info).with('[PoolManager] Candidate filter outcome',
      input_count: 3, basic_rejected: 1, optional_rejected: 1, accepted_count: 1,
      pipeline_enabled: true, evaluation_failed: false)
    expect(MemePoolManager.send(:quality_filter, [nil, candidate, rejected])).to eq([candidate])
  end

  it 'reports zero accepted and unknown optional rejection count on evaluation failure' do
    allow(QualityPipelineService).to receive(:passes_all_gates?).and_raise('private candidate contents')
    expect(AppLogger).to receive(:warn).with('[PoolManager] Candidate filter outcome',
      input_count: 2, basic_rejected: 1, optional_rejected: nil, accepted_count: 0,
      pipeline_enabled: true, evaluation_failed: true)
    expect(MemePoolManager.send(:quality_filter, [nil, candidate])).to eq([])
  end

  it 'discards partial approvals if evaluation fails later in the batch' do
    calls = 0
    allow(QualityPipelineService).to receive(:passes_all_gates?) do
      calls += 1
      raise 'Evaluation unavailable' if calls > 1
      true
    end
    expect(MemePoolManager.send(:quality_filter, [candidate, candidate.dup])).to eq([])
  end

  it 'does not evaluate an empty batch' do
    expect(QualityPipelineService).not_to receive(:passes_all_gates?)
    expect(MemePoolManager.send(:quality_filter, [])).to eq([])
  end

  it 'never sends malformed or browser-unsafe candidates to the optional pipeline' do
    invalid = [nil, {}, candidate.merge('url' => 'javascript:alert(1)'),
      candidate.merge('title' => ''), candidate.merge('subreddit' => 42)]
    expect(QualityPipelineService).to receive(:passes_all_gates?).with(candidate).once.and_return(true)
    expect(MemePoolManager.send(:quality_filter, [*invalid, candidate])).to eq([candidate])
  end

  it 'skips optional evaluation when every candidate fails the mandatory basic checks' do
    expect(QualityPipelineService).not_to receive(:passes_all_gates?)
    expect(MemePoolManager.send(:quality_filter, [nil, candidate.merge('url' => '//evil.example/image.jpg')])).to eq([])
  end

  it 'preserves working inventory and does not publish after evaluation fails' do
    retained = { 'url' => '/working.jpg' }
    allow(QualityPipelineService).to receive(:passes_all_gates?).and_raise('Evaluation unavailable')
    allow(MemePoolManager).to receive(:create_fetcher).and_return(double(rate_limited?: false))
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([candidate])
    allow(MemePoolManager).to receive(:get_current_pool).and_return([retained])
    expect(MemePoolManager).not_to receive(:store_in_pool)
    expect(MemePoolManager).not_to receive(:remove_from_pool)
    expect(MemePoolManager.send(:fetch_batch, size: 100, replacement_urls: ['/working.jpg'])).to include(
      validated: 0, stored: 0, replaced: 0, publication_succeeded: false, previous_unique: 1)
  end
end

RSpec.describe 'Basic pool candidate validation' do
  let(:candidate) { { 'url' => 'https://i.redd.it/usable.jpg', 'title' => 'Usable', 'subreddit' => 'cats' } }

  before { hide_const('QualityPipelineService') }

  it 'accepts renderable remote and local media candidates without claiming availability' do
    local = candidate.merge('url' => '/images/funny1.jpeg')
    expect(MemePoolManager.send(:quality_filter, [candidate, local])).to eq([candidate, local])
  end

  it 'rejects unsafe URL schemes, embedded credentials and malformed metadata' do
    invalid = [nil, 'not a meme', {}, candidate.merge('url' => 'javascript:alert(1)'),
      candidate.merge('url' => '//evil.example/a.jpg'),
      candidate.merge('url' => 'https://user:pass@example.test/a.jpg'),
      candidate.merge('title' => '   '), candidate.merge('subreddit' => ''),
      candidate.merge('title' => 123), candidate.merge('url' => nil)]
    expect(MemePoolManager.send(:quality_filter, invalid + [candidate])).to eq([candidate])
  end

  it 'does not mutate the accepted candidate' do
    original = candidate.dup
    expect(MemePoolManager.send(:quality_filter, [candidate]).first).to equal(candidate)
    expect(candidate).to eq(original)
  end
end