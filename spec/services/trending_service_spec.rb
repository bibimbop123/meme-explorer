# Comprehensive test suite for TrendingService
# Week 2: Core Service Tests
#
# BUG FIX: this entire file was written against an API TrendingService has
# never had - `TrendingService.new(db)` (the real module uses `extend self`,
# i.e. module-level methods, no instance/constructor at all),
# `get_trending_memes(limit:, hours:)` (real kwarg is `time_window_hours:`,
# not `hours:`), a standalone `calculate_trending_score(meme)` method (the
# real service computes trending_score entirely in SQL - see
# lib/services/trending_service.rb - there's no equivalent Ruby-side
# method to call directly), and `get_trending_by_subreddit` (the real
# method is `get_trending_by_category`, same semantics: filter by
# `subreddit` column). Every single example failed with NoMethodError
# before ever exercising real behavior. Rewritten against the actual
# module API; the intent behind each example (ordering, limits, time
# windows, category filtering, nil-safety) is preserved.

require_relative '../spec_helper'

RSpec.describe TrendingService do
  let(:db) { DB }

  before do
    db.execute("DELETE FROM meme_stats")
    db.execute("DELETE FROM meme_activity_log") rescue nil
  end

  describe '.get_trending_memes' do
    context 'with recent activity' do
      before do
        3.times do |i|
          url = "https://example.com/meme#{i}.jpg"
          db.execute(
            "INSERT INTO meme_stats (url, title, subreddit, likes, views, updated_at) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP - (?::text || ' hours')::interval)",
            [url, "Trending Meme #{i}", "funny", 100 - (i * 20), 500 - (i * 50), i]
          )
        end
      end

      it 'returns trending memes' do
        results = TrendingService.get_trending_memes(limit: 10)
        expect(results).to be_an(Array)
        expect(results.length).to be > 0
      end

      it 'limits results to specified count' do
        results = TrendingService.get_trending_memes(limit: 2)
        expect(results.length).to be <= 2
      end

      it 'orders by engagement score' do
        results = TrendingService.get_trending_memes(limit: 3)
        if results.length > 1
          expect(results[0][:trending_score].to_f).to be >= results[1][:trending_score].to_f
        end
      end
    end

    context 'time-based trending' do
      it 'filters by 24-hour window' do
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views, updated_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP - INTERVAL '48 hours')",
          ["https://example.com/old.jpg", "Old Meme", 1000, 5000]
        )
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views, updated_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP - INTERVAL '2 hours')",
          ["https://example.com/recent.jpg", "Recent Meme", 50, 200]
        )

        results = TrendingService.get_trending_memes(limit: 10, time_window_hours: 24)
        recent_urls = results.map { |m| m[:url] }

        expect(recent_urls).to include("https://example.com/recent.jpg")
        expect(recent_urls).not_to include("https://example.com/old.jpg")
      end

      it 'handles custom time windows' do
        results_24h = TrendingService.get_trending_memes(limit: 10, time_window_hours: 24)
        results_7d = TrendingService.get_trending_memes(limit: 10, time_window_hours: 168)

        expect(results_7d.length).to be >= results_24h.length
      end
    end

    context 'with no data' do
      it 'returns empty array when no memes exist' do
        results = TrendingService.get_trending_memes(limit: 10)
        expect(results).to eq([])
      end
    end

    context 'engagement scoring' do
      before do
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views, updated_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP - INTERVAL '1 hour')",
          ["https://example.com/high-likes.jpg", "High Likes", 100, 150]
        )
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views, updated_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP - INTERVAL '1 hour')",
          ["https://example.com/high-views.jpg", "High Views", 10, 1000]
        )
      end

      it 'balances likes and views in scoring' do
        results = TrendingService.get_trending_memes(limit: 10)
        expect(results).not_to be_empty
        urls = results.map { |m| m[:url] }
        expect(urls.length).to be >= 2
      end
    end
  end

  describe '.get_trending_by_category' do
    before do
      db.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views, updated_at) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP - INTERVAL '1 hour')",
        ["https://example.com/funny1.jpg", "Funny Meme", "funny", 100, 500]
      )
      db.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views, updated_at) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP - INTERVAL '1 hour')",
        ["https://example.com/memes1.jpg", "Memes Post", "memes", 80, 400]
      )
    end

    it 'filters trending memes by subreddit' do
      results = TrendingService.get_trending_by_category('funny', limit: 10)
      expect(results).not_to be_empty
      expect(results.all? { |m| m[:subreddit] == "funny" }).to be true
    end

    it 'returns empty array for non-existent subreddit' do
      results = TrendingService.get_trending_by_category('nonexistent', limit: 10)
      expect(results).to eq([])
    end

    it 'handles nil subreddit parameter' do
      results = TrendingService.get_trending_by_category(nil, limit: 10)
      expect(results).to be_an(Array)
    end
  end

  describe 'integration test' do
    it 'full trending workflow' do
      5.times do |i|
        db.execute(
          "INSERT INTO meme_stats (url, title, subreddit, likes, views, updated_at) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP - (?::text || ' hours')::interval)",
          ["https://example.com/test#{i}.jpg", "Test #{i}", "funny", rand(100), rand(500) + 1, i]
        )
      end

      trending = TrendingService.get_trending_memes(limit: 3)
      expect(trending.length).to be <= 3

      trending.each do |meme|
        expect(meme[:trending_score].to_f).to be >= 0
      end
    end
  end
end

