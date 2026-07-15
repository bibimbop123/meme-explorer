# frozen_string_literal: true

require_relative '../spec_helper'

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
        
        allow(MemeExplorer::DiversityEngineService).to receive(:select_diverse_meme)
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
      skip "ViewingHistoryService not available" unless defined?(MemeExplorer::ViewingHistoryService)
      skip "DiversityEngineService not available" unless defined?(MemeExplorer::DiversityEngineService)

      meme_ids = []
      
      10.times do
        # Simulate getting a meme from pool
        pool = (1..100).map { |i| { "url" => "meme_#{i}", "title" => "Meme #{i}" } }
        
        meme = MemeExplorer::DiversityEngineService.select_diverse_meme(
          pool,
          session_id: session_id,
          preferences: {}
        )
        
        meme_ids << meme["url"] if meme
        
        # Mark as seen
        MemeExplorer::ViewingHistoryService.mark_seen(session_id, meme["url"]) if meme
      end

      # Check no consecutive duplicates
      consecutive_dupes = meme_ids.each_cons(2).any? { |a, b| a == b }
      expect(consecutive_dupes).to be_falsey
    end

    it "tracks viewing history in Redis" do
      skip "ViewingHistoryService not available" unless defined?(MemeExplorer::ViewingHistoryService)
      
      meme_url = "test_meme_#{SecureRandom.hex(8)}"
      
      MemeExplorer::ViewingHistoryService.mark_seen(session_id, meme_url)
      seen_memes = MemeExplorer::ViewingHistoryService.get_seen_memes(session_id)

      expect(seen_memes).to include(meme_url)
    end
  end

  describe "MemePool service" do
    context "when MemePool service exists" do
      it "returns a non-empty array of memes" do
        skip "MemePool not yet created" unless defined?(MemeExplorer::MemePool)
        
        pool = MemeExplorer::MemePool.get
        
        expect(pool).to be_an(Array)
        expect(pool).not_to be_empty
      end

      it "handles Redis failures gracefully" do
        skip "MemePool not yet created" unless defined?(MemeExplorer::MemePool)
        
        # Mock Redis failure
        if defined?(MemePoolManager)
          allow(MemePoolManager).to receive(:get_pool)
            .and_return({ success: false, memes: [] })
        end

        pool = MemeExplorer::MemePool.get
        
        # Should fallback to local memes
        expect(pool).to be_an(Array)
      end
    end
  end

  describe "Configuration management" do
    it "loads algorithm config from YAML" do
      skip "AlgorithmConfigService not available" unless defined?(MemeExplorer::AlgorithmConfigService)
      
      config = MemeExplorer::AlgorithmConfigService.config
      
      expect(config).to be_a(Hash)
      expect(config).to have_key('streak_bonuses')
      expect(config).to have_key('freshness')
      expect(config).to have_key('viral')
    end

    it "uses configuration in contextual scoring" do
      skip "ContextualScoringService not available" unless defined?(MemeExplorer::ContextualScoringService)
      
      meme = {
        "score" => 1000,
        "num_comments" => 100,
        "created_utc" => Time.now.to_i - 3600 # 1 hour ago
      }

      scored = MemeExplorer::ContextualScoringService.calculate_contextual_boost(meme)
      
      # Should return a boosted score based on config
      expect(scored).to be > 0
    end
  end

  describe "Async DB writes" do
    context "when MemeStatsWriter worker exists" do
      it "queues background job for meme stats" do
        skip "MemeStatsWriter not available" unless defined?(MemeStatsWriter)
        skip "Sidekiq not configured" unless defined?(Sidekiq)
        
        expect {
          MemeStatsWriter.perform_async(
            "test_meme_url",
            "Test Meme",
            "test_subreddit",
            nil
          )
        }.to change { MemeStatsWriter.jobs.size }.by(1)
      end
    end
  end

  describe "Performance" do
    it "completes random meme selection in under 100ms" do
      skip "Performance test - run manually" if ENV['CI']
      skip "DiversityEngineService not available" unless defined?(MemeExplorer::DiversityEngineService)

      pool = (1..100).map { |i| { "url" => "meme_#{i}", "title" => "Meme #{i}" } }
      
      start_time = Time.now
      
      10.times do
        MemeExplorer::DiversityEngineService.select_diverse_meme(
          pool,
          session_id: session_id,
          preferences: {}
        )
      end
      
      avg_time = (Time.now - start_time) / 10
      
      expect(avg_time).to be < 0.1 # 100ms
    end
  end
end
