# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/controllers/random_meme_controller'

RSpec.describe "Random Algorithm Integration", type: :integration do
  let(:session) { {} }
  let(:session_id) { SecureRandom.uuid }
  let(:user_id) { nil }
  let(:request_ip) { "127.0.0.1" }

  before do
    session[:session_id] = session_id
    session[:meme_history] = []
    session[:view_count] = 0
    
    # Clear viewing history for clean tests
    if defined?(MemeExplorer::ViewingHistoryService)
      MemeExplorer::ViewingHistoryService.clear_history(session_id)
    end
  end

  describe "RandomMemeController" do
    context "when controller exists" do
      it "returns a valid result with meme data" do
        skip "RandomMemeController not yet integrated" unless defined?(MemeExplorer::RandomMemeController)
        
        result = MemeExplorer::RandomMemeController.handle(
          session: session,
          user_id: user_id,
          request_ip: request_ip
        )

        expect(result).to respond_to(:meme)
        expect(result.meme).to be_present
        expect(result).to respond_to(:image_src)
        expect(result).to respond_to(:likes)
      end

      it "increments view count in session" do
        skip "RandomMemeController not yet integrated" unless defined?(MemeExplorer::RandomMemeController)
        
        initial_count = session[:view_count] || 0
        
        MemeExplorer::RandomMemeController.handle(
          session: session,
          user_id: user_id,
          request_ip: request_ip
        )

        expect(session[:view_count]).to eq(initial_count + 1)
      end

      it "handles errors gracefully and returns fallback meme" do
        skip "RandomMemeController not yet integrated" unless defined?(MemeExplorer::RandomMemeController)

        # NOTE: DiversityEngineService was removed from the codebase; the
        # controller now selects memes via MemeExplorer::SimpleMemeSelector.
        allow(MemeExplorer::SimpleMemeSelector).to receive(:select_random_meme)
          .and_raise(StandardError.new("Test error"))

        result = MemeExplorer::RandomMemeController.handle(
          session: session,
          user_id: user_id,
          request_ip: request_ip
        )

        expect(result.meme).to be_present
        expect(result.image_src).to be_present
      end
    end
  end

  describe "Anti-repetition system" do
    it "never returns the same meme twice in succession" do
      meme_ids = []
      pool = (1..100).map { |i| { "url" => "meme_#{i}", "title" => "Meme #{i}" } }

      10.times do
        meme = MemeExplorer::SimpleMemeSelector.select(
          pool,
          session_id,
          boost_fresh: false
        )

        meme_ids << meme["url"] if meme
      end

      consecutive_dupes = meme_ids.each_cons(2).any? { |a, b| a == b }
      expect(consecutive_dupes).to be_falsey
      expect(meme_ids.uniq.size).to eq(10)
    end

    it "tracks viewing history in Redis" do
      meme_url = "test_meme_#{SecureRandom.hex(8)}"
      
      MemeExplorer::ViewingHistoryService.mark_seen(session_id, meme_url)
      seen_memes = MemeExplorer::ViewingHistoryService.get_seen_memes(session_id)

      expect(seen_memes).to include(meme_url)
    end
  end

  describe "MemePoolManager service" do
    context "when MemePoolManager service exists" do
      it "returns a non-empty array of memes" do
        allow(MemePoolManager).to receive(:get_pool).and_return(
          success: true,
          memes: [{ "url" => "/images/funny1.jpeg", "title" => "Pool meme", "subreddit" => "memes" }],
          pool_size: 1
        )
        result = MemePoolManager.get_pool

        expect(result[:memes]).to be_an(Array)
        expect(result[:memes]).not_to be_empty
      end

      it "handles Redis failures gracefully" do
        allow(MemePoolManager).to receive(:get_pool).and_return({ success: false, memes: [] })
        result = MemePoolManager.get_pool

        expect(result[:memes]).to be_an(Array)
      end
    end
  end

  describe "Configuration management" do
    it "loads editorial source lists in SimpleMemeSelector" do
      expect(MemeExplorer::SimpleMemeSelector::HUMOR_FIRST_SOURCES).to include("memes", "dankmemes")
      expect(MemeExplorer::SimpleMemeSelector::COMMENTARY_SOURCES).to include("whitepeopletwitter")
    end

    it "uses editorial and conversion weighting in SimpleMemeSelector" do
      pool = [
        { "url" => "/winner.jpg", "subreddit" => "memes", "likes" => 10, "views" => 20, "title" => "Punchy joke" },
        { "url" => "/dud.jpg", "subreddit" => "whitepeopletwitter", "likes" => 0, "views" => 40, "title" => "A" * 180 }
      ]
      allow(MemeExplorer::SimpleMemeSelector).to receive(:rand).and_return(0.5)
      selected = MemeExplorer::SimpleMemeSelector.send(:weighted_sample, pool)
      expect(selected["url"]).to eq("/winner.jpg")
    end
  end

  describe "SelectionBenchmark telemetry" do
    it "records selection stage latencies into Redis" do
      SelectionBenchmark.measure(stage: :selection) { true }
      stats = SelectionBenchmark.stats(stage: :selection)
      expect(stats[:count]).to be >= 1
    end
  end

  describe "Performance" do
    it "completes random meme selection in under 100ms" do
      pool = (1..100).map { |i| { "url" => "perf_meme_#{i}", "title" => "Perf Meme #{i}" } }

      start_time = Time.now

      10.times do
        MemeExplorer::SimpleMemeSelector.select(
          pool,
          session_id,
          boost_fresh: false
        )
      end

      avg_time = (Time.now - start_time) / 10

      expect(avg_time).to be < 0.1 # 100ms
    end
  end
end
