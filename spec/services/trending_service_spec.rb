# Comprehensive test suite for TrendingService
# Week 2: Core Service Tests

require_relative '../spec_helper'

RSpec.describe TrendingService do
  let(:db) { DB }
  let(:service) { described_class.new(db) }

  before do
    # Clean database
    db.execute("DELETE FROM meme_stats")
    db.execute("DELETE FROM meme_activity_log") rescue nil
  end

  describe '.get_trending_memes' do
    context 'with recent activity' do
      before do
        # Create memes with different engagement levels
        3.times do |i|
          url = "https://example.com/meme#{i}.jpg"
          db.execute(
            "INSERT INTO meme_stats (url, title, subreddit, likes, views, created_at, updated_at) VALUES (?, ?, ?, ?, ?, datetime('now', '-#{i} hours'), datetime('now'))",
            [url, "Trending Meme #{i}", "funny", 100 - (i * 20), 500 - (i * 50)]
          )
        end
      end

      it 'returns trending memes' do
        results = service.get_trending_memes(limit: 10)
        expect(results).to be_an(Array)
        expect(results.length).to be > 0
      end

      it 'limits results to specified count' do
        results = service.get_trending_memes(limit: 2)
        expect(results.length).to be <= 2
      end

      it 'orders by engagement score' do
        results = service.get_trending_memes(limit: 3)
        if results.length > 1
          # Higher engagement should come first
          expect(results[0]["likes"].to_i).to be >= results[1]["likes"].to_i
        end
      end
    end

    context 'time-based trending' do
      it 'filters by 24-hour window' do
        # Old meme
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views, created_at, updated_at) VALUES (?, ?, ?, ?, datetime('now', '-48 hours'), datetime('now', '-48 hours'))",
          ["https://example.com/old.jpg", "Old Meme", 1000, 5000]
        )
        
        # Recent meme
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views, created_at, updated_at) VALUES (?, ?, ?, ?, datetime('now', '-2 hours'), datetime('now'))",
          ["https://example.com/recent.jpg", "Recent Meme", 50, 200]
        )
        
        results = service.get_trending_memes(limit: 10, hours: 24)
        recent_urls = results.map { |m| m["url"] }
        
        expect(recent_urls).to include("https://example.com/recent.jpg")
        expect(recent_urls).not_to include("https://example.com/old.jpg")
      end

      it 'handles custom time windows' do
        results_24h = service.get_trending_memes(limit: 10, hours: 24)
        results_7d = service.get_trending_memes(limit: 10, hours: 168) # 7 days
        
        expect(results_7d.length).to be >= results_24h.length
      end
    end

    context 'with no data' do
      it 'returns empty array when no memes exist' do
        results = service.get_trending_memes(limit: 10)
        expect(results).to eq([])
      end
    end

    context 'engagement scoring' do
      before do
        # Meme with high likes, low views
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views, created_at) VALUES (?, ?, ?, ?, datetime('now', '-1 hour'))",
          ["https://example.com/high-likes.jpg", "High Likes", 100, 150]
        )
        
        # Meme with low likes, high views
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views, created_at) VALUES (?, ?, ?, ?, datetime('now', '-1 hour'))",
          ["https://example.com/high-views.jpg", "High Views", 10, 1000]
        )
      end

      it 'balances likes and views in scoring' do
        results = service.get_trending_memes(limit: 10)
        expect(results).not_to be_empty
        
        # Both memes should be included
        urls = results.map { |m| m["url"] }
        expect(urls.length).to be >= 2
      end
    end
  end

  describe '.calculate_trending_score' do
    it 'returns higher score for more likes' do
      meme_high = {"likes" => 100, "views" => 500, "created_at" => Time.now - 3600}
      meme_low = {"likes" => 10, "views" => 500, "created_at" => Time.now - 3600}
      
      score_high = service.calculate_trending_score(meme_high)
      score_low = service.calculate_trending_score(meme_low)
      
      expect(score_high).to be > score_low
    end

    it 'returns higher score for more recent memes' do
      meme_recent = {"likes" => 50, "views" => 200, "created_at" => Time.now - 1800}
      meme_old = {"likes" => 50, "views" => 200, "created_at" => Time.now - 86400}
      
      score_recent = service.calculate_trending_score(meme_recent)
      score_old = service.calculate_trending_score(meme_old)
      
      expect(score_recent).to be > score_old
    end

    it 'handles memes without timestamps' do
      meme = {"likes" => 50, "views" => 200}
      expect { service.calculate_trending_score(meme) }.not_to raise_error
    end

    it 'returns 0 for nil meme' do
      expect(service.calculate_trending_score(nil)).to eq(0)
    end
  end

  describe '.get_trending_by_subreddit' do
    before do
      db.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views, created_at) VALUES (?, ?, ?, ?, ?, datetime('now', '-1 hour'))",
        ["https://example.com/funny1.jpg", "Funny Meme", "funny", 100, 500]
      )
      db.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views, created_at) VALUES (?, ?, ?, ?, ?, datetime('now', '-1 hour'))",
        ["https://example.com/memes1.jpg", "Memes Post", "memes", 80, 400]
      )
    end

    it 'filters trending memes by subreddit' do
      results = service.get_trending_by_subreddit('funny', limit: 10)
      expect(results).not_to be_empty
      expect(results.all? { |m| m["subreddit"] == "funny" }).to be true
    end

    it 'returns empty array for non-existent subreddit' do
      results = service.get_trending_by_subreddit('nonexistent', limit: 10)
      expect(results).to eq([])
    end

    it 'handles nil subreddit parameter' do
      results = service.get_trending_by_subreddit(nil, limit: 10)
      expect(results).to be_an(Array)
    end
  end

  describe 'integration test' do
    it 'full trending workflow' do
      # 1. Add various memes
      5.times do |i|
        db.execute(
          "INSERT INTO meme_stats (url, title, subreddit, likes, views, created_at) VALUES (?, ?, ?, ?, ?, datetime('now', '-#{i} hours'))",
          ["https://example.com/test#{i}.jpg", "Test #{i}", "funny", rand(100), rand(500)]
        )
      end
      
      # 2. Get trending
      trending = service.get_trending_memes(limit: 3)
      expect(trending.length).to be <= 3
      
      # 3. Calculate scores
      trending.each do |meme|
        score = service.calculate_trending_score(meme)
        expect(score).to be_a(Numeric)
        expect(score).to be >= 0
      end
    end
  end
end
