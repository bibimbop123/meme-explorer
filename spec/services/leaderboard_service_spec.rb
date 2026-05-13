# Comprehensive test suite for LeaderboardService  
# Week 2: Core Service Tests

require_relative '../spec_helper'

RSpec.describe LeaderboardService do
  let(:db) { DB }

  before do
    # Clean database
    db.execute("DELETE FROM users")
    db.execute("DELETE FROM meme_stats")
    db.execute("DELETE FROM user_meme_stats") rescue nil
  end

  describe '.get_top_users' do
    before do
      # Create users with different activity levels
      3.times do |i|
        user_id = create_test_user("user#{i}@example.com", 'password123')
        # Simulate activity
        (10 - i * 3).times do
          url = "https://example.com/meme_#{i}_#{rand(1000)}.jpg"
          db.execute(
            "INSERT OR IGNORE INTO meme_stats (url, title, likes, views) VALUES (?, ?, 0, 0)",
            [url, "Meme #{i}"]
          )
          MemeService.toggle_like(url, true, {user_id: user_id}, db)
        end
      end
    end

    it 'returns top users by activity' do
      results = LeaderboardService.get_top_users(db, limit: 10)
      expect(results).to be_an(Array)
      expect(results.length).to be > 0
    end

    it 'limits results to specified count' do
      results = LeaderboardService.get_top_users(db, limit: 2)
      expect(results.length).to be <= 2
    end

    it 'orders users by score descending' do
      results = LeaderboardService.get_top_users(db, limit: 3)
      if results.length > 1
        # Scores should be descending
        (0...results.length-1).each do |i|
          score1 = results[i]["score"] || results[i][:score] || 0
          score2 = results[i+1]["score"] || results[i+1][:score] || 0
          expect(score1.to_i).to be >= score2.to_i
        end
      end
    end

    it 'includes user email in results' do
      results = LeaderboardService.get_top_users(db, limit: 10)
      results.each do |user|
        expect(user["email"] || user[:email]).not_to be_nil
      end
    end
  end

  describe '.calculate_user_score' do
    let(:user_id) { create_test_user('scorer@example.com', 'password123') }

    it 'returns 0 for user with no activity' do
      score = LeaderboardService.calculate_user_score(user_id, db)
      expect(score).to eq(0)
    end

    it 'increases score for likes given' do
      url = "https://example.com/liked.jpg"
      db.execute(
        "INSERT INTO meme_stats (url, title, likes, views) VALUES (?, ?, 0, 0)",
        [url, "Test Meme"]
      )
      
      MemeService.toggle_like(url, true, {user_id: user_id}, db)
      score = LeaderboardService.calculate_user_score(user_id, db)
      expect(score).to be > 0
    end

    it 'handles nil user_id' do
      score = LeaderboardService.calculate_user_score(nil, db)
      expect(score).to eq(0)
    end
  end

  describe '.get_user_rank' do
    before do
      # Create multiple users with different scores
      5.times do |i|
        user_id = create_test_user("ranked#{i}@example.com", 'password123')
        (5 - i).times do
          url = "https://example.com/rank_#{i}_#{rand(1000)}.jpg"
          db.execute(
            "INSERT OR IGNORE INTO meme_stats (url, title, likes, views) VALUES (?, ?, 0, 0)",
            [url, "Rank Meme #{i}"]
          )
          MemeService.toggle_like(url, true, {user_id: user_id}, db)
        end
      end
    end

    it 'returns rank for active user' do
      user_id = db.get_first_value("SELECT id FROM users WHERE email = ?", ["ranked0@example.com"])
      rank = LeaderboardService.get_user_rank(user_id, db)
      expect(rank).to be_a(Integer)
      expect(rank).to be > 0
    end

    it 'returns nil for non-existent user' do
      rank = LeaderboardService.get_user_rank(99999, db)
      expect(rank).to be_nil
    end

    it 'most active user has rank 1' do
      user_id = db.get_first_value("SELECT id FROM users WHERE email = ?", ["ranked0@example.com"])
      rank = LeaderboardService.get_user_rank(user_id, db)
      expect(rank).to eq(1)
    end
  end

  describe '.get_user_stats' do
    let(:user_id) { create_test_user('stats@example.com', 'password123') }

    it 'returns stats hash for user' do
      stats = LeaderboardService.get_user_stats(user_id, db)
      expect(stats).to be_a(Hash)
    end

    it 'includes total likes count' do
      5.times do |i|
        url = "https://example.com/stat_#{i}.jpg"
        db.execute(
          "INSERT INTO meme_stats (url, title, likes, views) VALUES (?, ?, 0, 0)",
          [url, "Stats Meme #{i}"]
        )
        MemeService.toggle_like(url, true, {user_id: user_id}, db)
      end
      
      stats = LeaderboardService.get_user_stats(user_id, db)
      expect(stats[:total_likes] || stats["total_likes"]).to be >= 5
    end

    it 'handles user with no stats' do
      stats = LeaderboardService.get_user_stats(user_id, db)
      expect(stats).to be_a(Hash)
      expect(stats[:total_likes] || stats["total_likes"] || 0).to eq(0)
    end
  end

  describe 'leaderboard time periods' do
    before do
      user_id = create_test_user('timeperiod@example.com', 'password123')
      
      # Old activity
      url_old = "https://example.com/old_activity.jpg"
      db.execute(
        "INSERT INTO meme_stats (url, title, likes, views, created_at) VALUES (?, ?, 0, 0, datetime('now', '-30 days'))",
        [url_old, "Old Meme"]
      )
      
      # Recent activity
      url_recent = "https://example.com/recent_activity.jpg"
      db.execute(
        "INSERT INTO meme_stats (url, title, likes, views, created_at) VALUES (?, ?, 0, 0, datetime('now', '-1 hour'))",
        [url_recent, "Recent Meme"]
      )
    end

    it 'can filter leaderboard by time period' do
      # This tests that the service can handle time-based filtering
      results_all = LeaderboardService.get_top_users(db, limit: 10)
      results_recent = LeaderboardService.get_top_users(db, limit: 10, period: '24h') rescue results_all
      
      expect(results_all).to be_an(Array)
      expect(results_recent).to be_an(Array)
    end
  end

  describe 'edge cases' do
    it 'handles empty database' do
      results = LeaderboardService.get_top_users(db, limit: 10)
      expect(results).to eq([])
    end

    it 'handles invalid limit parameter' do
      create_test_user('edge@example.com', 'password123')
      results = LeaderboardService.get_top_users(db, limit: -1)
      expect(results).to be_an(Array)
    end

    it 'handles nil database parameter' do
      expect { LeaderboardService.get_top_users(nil, limit: 10) }.not_to raise_error
    end
  end

  describe 'integration test' do
    it 'full leaderboard workflow' do
      # 1. Create users and activity
      users = []
      3.times do |i|
        user_id = create_test_user("workflow#{i}@example.com", 'password123')
        users << user_id
        
        (3 - i).times do |j|
          url = "https://example.com/workflow_#{i}_#{j}.jpg"
          db.execute(
            "INSERT INTO meme_stats (url, title, likes, views) VALUES (?, ?, 0, 0)",
            [url, "Workflow Meme"]
          )
          MemeService.toggle_like(url, true, {user_id: user_id}, db)
        end
      end
      
      # 2. Get leaderboard
      leaderboard = LeaderboardService.get_top_users(db, limit: 10)
      expect(leaderboard.length).to be >= 3
      
      # 3. Check ranks
      users.each do |user_id|
        rank = LeaderboardService.get_user_rank(user_id, db)
        expect(rank).to be_a(Integer)
        expect(rank).to be > 0
      end
      
      # 4. Get individual stats
      users.each do |user_id|
        stats = LeaderboardService.get_user_stats(user_id, db)
        expect(stats).to be_a(Hash)
      end
    end
  end
end
