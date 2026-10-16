require_relative '../spec_helper'
require_relative '../../lib/services/feed_traversal'
require_relative '../../lib/services/feed_acknowledgement_service'
require 'timeout'

RSpec.describe MemeExplorer::FeedTraversal do
  let(:identity) { SecureRandom.hex(32) }
  let(:issuer) { MemeExplorer::FeedIssuanceService }
  let(:store) { MemeExplorer::FeedAcknowledgementStore }

  after do
    RedisService.with_redis do |r|
      r.del(*store.send(:keys, identity), store.send(:pending_key, identity),
        *MemeExplorer::FeedReservationService.send(:keys, identity),
        "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history")
    end
  end

  it 'issues and acknowledges a real copied snapshot without speculative history or duplicate counters' do
    pool = [{ url: '/snapshot-lifecycle.jpg', title: 'Snapshot original' }]
    traversal = described_class.new(pool, identity)
    pool.first[:url].replace('/changed-after-snapshot.jpg')
    pool.first[:title].replace('Changed')
    result = traversal.advance
    expect(result[:status]).to eq(:issued)
    expect(result[:meme]).to include('url' => '/snapshot-lifecycle.jpg', 'title' => 'Snapshot original')
    expect(traversal.advance).to eq(status: :closed)
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    ack = MemeExplorer::FeedAcknowledgementService
    expect(ack.acknowledge(identity, result[:token], impression_id: result[:impression_id])).to eq(status: :acknowledged, recorded: true)
    expect(ack.acknowledge(identity, result[:token], impression_id: result[:impression_id])).to eq(status: :acknowledged, recorded: false)
    expect(store.history(identity)[:entries].map { |entry| entry[:content] }).to eq(['/snapshot-lifecycle.jpg'])
    row = DB.execute('SELECT title, views FROM meme_stats WHERE url = ?', ['/snapshot-lifecycle.jpg']).first
    expect(row['title']).to eq('Snapshot original')
    expect(row['views'].to_i).to eq(1)
    next_pass = described_class.new([{ url: '/snapshot-lifecycle.jpg' }], identity)
    expect(next_pass.advance).to eq(status: :snapshot_complete, reserved: false, empty: false)
  end

  it 'binds copied metadata and deduplicates identities across chunk boundaries' do
    pool = 101.times.map { |i| { url: "/snapshot-#{i}.jpg", title: 'Original' } }
    pool << pool.first.dup
    traversal = described_class.new(pool, identity)
    pool.last[:url].replace('/mutated.jpg')
    pool.last[:title].replace('Mutated')
    pool.clear
    expect(issuer).to receive(:issue).with(identity, a_string_matching(%r{\A/snapshot-\d+\.jpg\z}),
      title: 'Original', subreddit: nil, user_id: nil).exactly(101).times.and_return(status: :already_acknowledged)
    expect(traversal.advance).to eq(status: :traversal_incomplete, reserved: false)
    expect(traversal.advance).to eq(status: :snapshot_complete, reserved: false, empty: false)
    expect(traversal.advance).to eq(status: :closed)
  end

  it 'aggregates prefix contention without treating snapshot completion as global exhaustion' do
    pool = 101.times.map { |i| { url: "/conflict-snapshot-#{i}.jpg" } }
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    allow(issuer).to receive(:issue).with(identity, pool.first[:url], anything).and_return(status: :already_reserved)
    traversal = described_class.new(pool, identity)
    expect(traversal.advance).to eq(status: :traversal_incomplete, reserved: true)
    expect(traversal.advance).to eq(status: :snapshot_complete, reserved: true, empty: false)
  end

  it 'preserves real prefix contention across chunks even if that lease expires before completion' do
    leases = MemeExplorer::FeedReservationService
    pool = 101.times.map { |i| { url: "/real-conflict-snapshot-#{i}.jpg" } }
    lease = leases.acquire(identity, pool.first[:url])
    expect(lease[:status]).to eq(:reserved)
    pool.drop(1).each do |meme|
      issued = issuer.issue(identity, meme[:url])
      expect(MemeExplorer::FeedAcknowledgementService.acknowledge(identity, issued[:token],
        impression_id: issued[:impression_id])[:status]).to eq(:acknowledged)
    end
    original = store.history(identity)
    traversal = described_class.new(pool, identity)
    expect(traversal.advance).to eq(status: :traversal_incomplete, reserved: true)
    RedisService.with_redis do |r|
      r.zadd(leases.send(:keys, identity).first, 0, Digest::SHA256.hexdigest(pool.first[:url]))
    end
    expect(traversal.advance).to eq(status: :snapshot_complete, reserved: true, empty: false)
    expect(store.history(identity)).to eq(original)
    expect(DB.get_first_value('SELECT SUM(views) FROM meme_stats').to_i).to eq(100)
    # A fresh pass must recheck the earlier conflict, not reuse completion as proof.
    fresh = described_class.new(pool, identity).advance
    expect(fresh[:status]).to eq(:issued)
    expect(fresh[:meme]['url']).to eq(pool.first[:url])
  end

  it 'validates the entire bounded snapshot before any issuance' do
    expect(issuer).not_to receive(:issue)
    [nil, Array.new(described_class::MAX_CANDIDATES + 1), [{ url: '/valid.jpg' }, {}],
     [{ url: '/bad-context.jpg', title: [] }]].each do |pool|
      expect(described_class.new(pool, identity).advance).to eq(status: :invalid)
    end
    expect(described_class.new([], identity).advance).to eq(status: :snapshot_complete, reserved: false, empty: true)
  end

  it 'closes after issuance or failure instead of silently retrying the same snapshot' do
    [:issued, :unavailable, :receipt_limit_reached].each do |status|
      allow(issuer).to receive(:issue).and_return(status: status)
      traversal = described_class.new([{ url: '/terminal.jpg' }], identity)
      expect(traversal.advance[:status]).to eq(status)
      expect(traversal.advance).to eq(status: :closed)
    end
  end

  it 'enforces aggregate copied metadata bytes without charging duplicate identities twice' do
    stub_const('MemeExplorer::FeedTraversal::MAX_METADATA_BYTES', 10)
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    expect(described_class.new([{ url: '/a', title: '123456789' }], identity).advance).to eq(status: :invalid)
    expect(described_class.new([{ url: '/a', title: '1234' }, { url: '/b', title: '123' }], identity).advance).to eq(status: :invalid)
    expect(issuer).not_to have_received(:issue)
    exact = { url: '/a', title: '1234', subreddit: '1234' }
    expect(described_class.new([exact, exact.dup], identity).advance).to eq(status: :snapshot_complete, reserved: false, empty: false)
  end

  it 'closes on an unexpected exception instead of repeating partially completed work' do
    traversal = described_class.new([{ url: '/exception.jpg' }], identity)
    expect(issuer).to receive(:issue).once.and_raise(StandardError, 'private details')
    expect(traversal.advance).to eq(status: :unavailable, stage: :traversal)
    expect(traversal.advance).to eq(status: :closed)
  end

  it 'preserves frozen gallery and video metadata without copying credentials or viewer state' do
    gallery = [{ url: '/slide.jpg', width: 640, height: 900 }]
    pool = [{ url: '/media.jpg', file: '/video.mp4', media_type: 'video', width: 640,
              gallery_images: gallery, is_gallery: true, ack_token: 'private', saved: true }]
    traversal = described_class.new(pool, identity)
    gallery.first[:url].replace('/mutated.jpg')
    allow(issuer).to receive(:issue).and_return(status: :issued)
    result = traversal.advance[:meme]
    expect(result).to include('file' => '/video.mp4', 'media_type' => 'video', 'width' => 640)
    expect(result['gallery_images']).to eq([{ 'url' => '/slide.jpg', 'width' => 640, 'height' => 900 }])
    expect(result['gallery_images'].first['url']).to be_frozen
    expect(result).not_to have_key('ack_token')
    expect(result).not_to have_key('saved')
  end

  it 'rejects oversized, deeply nested and unsupported media payloads before issuance' do
    expect(issuer).not_to receive(:issue)
    deep = 'value'
    8.times { deep = [deep] }
    [deep, Object.new, ['x' * (described_class::MAX_PAYLOAD_BYTES + 1)],
     Array.new(described_class::MAX_PAYLOAD_NODES + 1, nil), [{ url: '/a', 'url' => '/b' }]].each do |payload|
      traversal = described_class.new([{ url: '/payload.jpg', gallery_images: payload }], identity)
      expect(traversal.advance).to eq(status: :invalid)
    end
  end

  it 'preserves gallery and video fields through the existing JSON response builder' do
    gallery = { url: '/builder-gallery.jpg', title: 'Gallery', subreddit: 'test',
      width: 640, height: 900, is_gallery: true,
      gallery_images: [{ url: '/builder-slide.jpg', width: 320, height: 450 }],
      permalink: '/r/test/comments/abc123/gallery' }
    video = { file: '/builder-video.mp4', title: 'Video', media_type: 'video',
      width: 1280, height: 720, permalink: '/r/test/comments/def456/video' }
    [gallery, video].each do |source|
      result = described_class.new([source], identity).advance
      expect(result[:status]).to eq(:issued)
      snapshot = result[:meme]
      response = Routes::RandomMeme.build_meme_json(snapshot,
        media_type: snapshot['media_type'] || 'image', likes: 3)
      expect(response).to include(url: source[:url] || source[:file], title: source[:title],
        width: source[:width], height: source[:height], reddit_path: source[:permalink], likes: 3)
      if source[:is_gallery]
        expect(response).to include(is_gallery: true, total_images: 1)
        expect(response[:gallery_images].first).to include('url' => '/builder-slide.jpg', 'width' => 320)
      else
        expect(response).to include(file: '/builder-video.mp4', media_type: 'video')
      end
      expect(store.history(identity)).to eq(status: :available, entries: [])
    end
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
  end

  it 'shares payload byte limits across unique candidates and accepts the exact boundary' do
    stub_const('MemeExplorer::FeedTraversal::MAX_PAYLOAD_BYTES', 8)
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    first = { url: '/bytes-one.jpg', media_type: '1234' }
    second = { url: '/bytes-two.jpg', media_type: '12345' }
    invalid = described_class.new([first, second], identity)
    expect(invalid.advance).to eq(status: :invalid)
    expect(invalid.instance_variable_get(:@candidates)).to eq([])
    expect(issuer).not_to have_received(:issue)
    second[:media_type] = '1234'
    expect(described_class.new([first, first.dup, second], identity).advance).to eq(status: :snapshot_complete, reserved: false, empty: false)
    expect(issuer).to have_received(:issue).twice
  end

  it 'shares payload node limits across unique candidates before any issuance' do
    stub_const('MemeExplorer::FeedTraversal::MAX_PAYLOAD_NODES', 3)
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    pool = [{ url: '/nodes-one.jpg', gallery_images: [nil] },
            { url: '/nodes-two.jpg', gallery_images: [nil] }]
    expect(described_class.new(pool, identity).advance).to eq(status: :invalid)
    expect(issuer).not_to have_received(:issue)
    pool.last[:gallery_images] = []
    expect(described_class.new(pool, identity).advance).to eq(status: :snapshot_complete, reserved: false, empty: false)
  end

  it 'drops internal candidate and identity references after invalid or terminal passes' do
    invalid = described_class.new([{ url: '/partial.jpg' }, {}], identity)
    expect(invalid.advance).to eq(status: :invalid)
    expect(invalid.instance_variable_get(:@candidates)).to eq([])
    expect(invalid.instance_variable_get(:@session_id)).to be_nil
    [:already_acknowledged, :issued, :unavailable].each do |status|
      allow(issuer).to receive(:issue).and_return(status: status)
      traversal = described_class.new([{ url: '/retained.jpg' }], identity)
      traversal.advance
      expect(traversal.instance_variable_get(:@candidates)).to eq([])
      expect(traversal.instance_variable_get(:@session_id)).to be_nil
      expect(traversal.advance).to eq(status: :closed)
    end
  end

  it 'issues only once when simultaneous callers advance the same snapshot' do
    traversal = described_class.new([{ url: '/serialized.jpg' }], identity)
    entered, release, ready, start = Queue.new, Queue.new, Queue.new, Queue.new
    expect(issuer).to receive(:issue).once do
      entered << true
      Timeout.timeout(10) { release.pop }
      { status: :issued, token: 'single-credential' }
    end
    threads = 2.times.map do
      Thread.new do
        ready << true
        start.pop
        traversal.advance
      end
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { start << true }
    Timeout.timeout(10) { entered.pop }
    release << true
    results = Timeout.timeout(10) { threads.map(&:value) }
    expect(results.map { |result| result[:status] }).to contain_exactly(:issued, :closed)
    expect(traversal.advance).to eq(status: :closed)
  ensure
    2.times { start << true } if start
    release << true if release
    threads&.each(&:join)
  end

  it 'cancels an incomplete pass without changing Redis state and makes cancellation idempotent' do
    pool = 101.times.map { |i| { url: "/cancel-#{i}.jpg" } }
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    traversal = described_class.new(pool, identity)
    expect(traversal.advance[:status]).to eq(:traversal_incomplete)
    allow(RedisService).to receive(:with_redis).and_call_original
    expect(traversal.cancel).to eq(status: :cancelled)
    expect(traversal.cancel).to eq(status: :closed)
    expect(traversal.advance).to eq(status: :closed)
    expect(RedisService).not_to have_received(:with_redis)
    expect(traversal.instance_variable_get(:@candidates)).to eq([])
    expect(traversal.instance_variable_get(:@session_id)).to be_nil
    expect(described_class.new(nil, identity).cancel).to eq(status: :invalid)
  end

  it 'does not undo issuance when cancellation follows an in-flight advance' do
    traversal = described_class.new([{ url: '/cancel-in-flight.jpg' }], identity)
    entered, release, cancelling = Queue.new, Queue.new, Queue.new
    expect(issuer).to receive(:issue).once do
      entered << true
      Timeout.timeout(10) { release.pop }
      { status: :issued, token: 'returned-credential' }
    end
    expect(MemeExplorer::FeedReservationService).not_to receive(:release)
    advance = Thread.new { traversal.advance }
    Timeout.timeout(10) { entered.pop }
    cancel = Thread.new do
      cancelling << true
      traversal.cancel
    end
    Timeout.timeout(10) { cancelling.pop }
    release << true
    expect(Timeout.timeout(10) { advance.value }[:status]).to eq(:issued)
    expect(Timeout.timeout(10) { cancel.value }).to eq(status: :closed)
    expect(traversal.advance).to eq(status: :closed)
  ensure
    release << true if release
    advance&.join
    cancel&.join
  end

  it 'bounds scheduled chunks and retains progress for a later invocation' do
    pool = 201.times.map { |i| { url: "/run-budget-#{i}.jpg" } }
    traversal = described_class.new(pool, identity)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(10.0)
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    expect(traversal.advance_with_budget).to eq(status: :traversal_incomplete, reserved: false)
    expect(issuer).to have_received(:issue).exactly(200).times
    expect(traversal.advance_with_budget).to eq(status: :snapshot_complete, reserved: false, empty: false)
    expect(issuer).to have_received(:issue).exactly(201).times
  end

  it 'does not schedule a second chunk once the soft time budget is reached' do
    traversal = described_class.new(101.times.map { |i| { url: "/time-budget-#{i}.jpg" } }, identity)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(10.0, 11.0)
    allow(issuer).to receive(:issue).and_return(status: :already_reserved)
    expect(traversal.advance_with_budget).to eq(status: :traversal_incomplete, reserved: true)
    expect(issuer).to have_received(:issue).exactly(100).times
  end

  it 'returns issued credentials without another scheduling step even if issuance is slow' do
    traversal = described_class.new([{ url: '/slow-issuance.jpg' }], identity)
    expect(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).once.and_return(10.0)
    expect(issuer).to receive(:issue).once.and_return(status: :issued, token: 'keep-credential')
    expect(traversal.advance_with_budget).to include(status: :issued, token: 'keep-credential')
    expect(traversal.advance).to eq(status: :closed)
  end

  it 'stops scheduling at the exact monotonic budget boundary' do
    traversal = described_class.new(101.times.map { |i| { url: "/exact-time-#{i}.jpg" } }, identity)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC)
      .and_return(0.0, described_class::RUN_BUDGET_SECONDS)
    expect(issuer).to receive(:issue).exactly(100).times.and_return(status: :already_acknowledged)
    expect(traversal.advance_with_budget).to eq(status: :traversal_incomplete, reserved: false)
  end

  it 'returns terminal capacity and outage outcomes without scheduling another chunk' do
    [:unavailable, :limit_reached, :receipt_limit_reached].each do |status|
      traversal = described_class.new([{ url: '/terminal-run.jpg' }], identity)
      allow(issuer).to receive(:issue).and_return(status: status, stage: :credential)
      expect(traversal.advance_with_budget).to eq(status: status, stage: :credential)
      expect(traversal.advance_with_budget).to eq(status: :closed)
    end
    expect(issuer).to have_received(:issue).exactly(3).times
  end
end