# frozen_string_literal: true

require_relative '../spec_helper'
require 'benchmark'

# BUG FIX: this entire file was written against fictional APIs -
# `DB[:memes].where(...).order(...).limit(...).all` (a Sequel::Dataset
# chain; the real `DB` is a hand-rolled `DBWrapper` around raw SQL via
# `DB.execute`, with no dataset/query-builder API at all),
# `DB[:users].insert(...)`, `DB.pool.size` (the real pool is internal to
# `DBWrapper` - see db/setup.rb - not exposed as `DB.pool`),
# `CacheManager.fetch(key, ttl:) { ... }` (CacheManager only has
# `get`/`set`/`delete`, no `fetch`), `/api/memes/random` (doesn't exist -
# the real route is `/random.json`), and `/login` accepting a `username`
# param (real routes only accept `email`). Every example either raised
# NoMethodError immediately or silently measured the wrong thing.
# Rewritten against real routes/APIs; the performance-testing *intent*
# (P95 latency budgets, cache speedup, memory stability) is preserved
# wherever a real corresponding code path exists to measure.
RSpec.describe 'Performance and Load Tests' do
  describe 'Response Time Benchmarks' do
    it 'homepage loads in under 150ms' do
      times = []
      10.times { times << Benchmark.realtime { get '/' } }
      p95 = times.sort[8]

      expect(p95).to be < 0.150, "P95: #{(p95 * 1000).round}ms (target: <150ms)"
      puts "  ✓ Homepage P95: #{(p95 * 1000).round(2)}ms"
    end

    it 'random meme endpoint loads in under 150ms' do
      get '/random' # warm up cache
      times = []
      10.times { times << Benchmark.realtime { get '/random' } }
      p95 = times.sort[8]

      expect(p95).to be < 0.150, "P95: #{(p95 * 1000).round}ms (target: <150ms)"
      puts "  ✓ Random meme P95: #{(p95 * 1000).round(2)}ms"
    end

    it 'trending page loads in under 200ms (more complex query)' do
      times = []
      10.times { times << Benchmark.realtime { get '/trending' } }
      p95 = times.sort[8]

      expect(p95).to be < 0.200, "P95: #{(p95 * 1000).round}ms (target: <200ms)"
      puts "  ✓ Trending page P95: #{(p95 * 1000).round(2)}ms"
    end

    it 'profile page loads in under 150ms' do
      user_id = UserService.create_email_user("perf_#{Time.now.to_i}@test.com", 'TestPass123!')
      session[:user_id] = user_id

      times = []
      10.times { times << Benchmark.realtime { get '/profile' } }
      p95 = times.sort[8]

      expect(p95).to be < 0.150, "P95: #{(p95 * 1000).round}ms (target: <150ms)"
      puts "  ✓ Profile page P95: #{(p95 * 1000).round(2)}ms"
    end

    it 'leaderboard loads in under 100ms' do
      times = []
      10.times { times << Benchmark.realtime { get '/leaderboard' } }
      p95 = times.sort[8]

      expect(p95).to be < 0.100, "P95: #{(p95 * 1000).round}ms (target: <100ms)"
      puts "  ✓ Leaderboard P95: #{(p95 * 1000).round(2)}ms"
    end
  end

  describe 'Database Query Performance' do
    it 'meme_stats query completes in under 50ms' do
      time = Benchmark.realtime do
        DB.execute(
          "SELECT * FROM meme_stats WHERE updated_at > ? ORDER BY updated_at DESC LIMIT 100",
          [Time.now - 86400 * 7]
        )
      end

      expect(time).to be < 0.050, "Query time: #{(time * 1000).round}ms (target: <50ms)"
      puts "  ✓ Meme stats query: #{(time * 1000).round(2)}ms"
    end

    it 'trending calculation query completes in under 100ms' do
      time = Benchmark.realtime { TrendingService.get_trending_memes(limit: 50) }
      expect(time).to be < 0.100, "Query time: #{(time * 1000).round}ms (target: <100ms)"
      puts "  ✓ Trending query: #{(time * 1000).round(2)}ms"
    end

    it 'user lookup query completes in under 30ms' do
      user_id = UserService.create_email_user("perfquery_#{Time.now.to_i}@test.com", 'TestPass123!')

      time = Benchmark.realtime { UserService.find_by_id(user_id) }
      expect(time).to be < 0.030, "Query time: #{(time * 1000).round}ms (target: <30ms)"
      puts "  ✓ User lookup: #{(time * 1000).round(2)}ms"
    end
  end

  describe 'Memory and Resource Usage' do
    it 'does not leak memory over multiple requests' do
      GC.start
      before_memory = `ps -o rss= -p #{Process.pid}`.to_i

      100.times { get '/random' }

      GC.start
      after_memory = `ps -o rss= -p #{Process.pid}`.to_i
      memory_increase = after_memory - before_memory

      # Allow up to 50MB memory increase for 100 requests
      expect(memory_increase).to be < 50_000, "Memory increased by #{memory_increase}KB"
      puts "  ✓ Memory increase: #{memory_increase}KB"
    end
  end

  describe 'Cache Performance' do
    it 'CacheManager get/set round-trips quickly' do
      cache_key = 'performance_test_key'
      CacheManager.delete(cache_key)

      set_time = Benchmark.realtime { CacheManager.set(cache_key, 'test_value', 300) }
      get_time = Benchmark.realtime { CacheManager.get(cache_key) }

      expect(CacheManager.get(cache_key)).to eq('test_value')
      expect(set_time).to be < 0.050
      expect(get_time).to be < 0.050
      puts "  ✓ Cache set: #{(set_time * 1000).round(2)}ms, get: #{(get_time * 1000).round(2)}ms"
    end

    it 'handles cache failures gracefully' do
      allow(CacheManager).to receive(:get).and_return(nil)

      time = Benchmark.realtime { get '/random' }

      # Should fall back to database/pool, still reasonable performance
      expect(time).to be < 0.300
      expect(last_response).to be_ok
      puts "  ✓ Cache failure handled: #{(time * 1000).round(2)}ms"
    end
  end

  describe 'API Endpoint Performance' do
    it 'random meme JSON API completes in under 150ms' do
      time = Benchmark.realtime { get '/random.json' }

      expect(time).to be < 0.150
      expect(last_response).to be_ok
      puts "  ✓ /random.json: #{(time * 1000).round(2)}ms"
    end

    it 'trending JSON API completes in under 150ms' do
      time = Benchmark.realtime { get '/trending.json' }

      expect(time).to be < 0.150
      expect(last_response).to be_ok
      puts "  ✓ /trending.json: #{(time * 1000).round(2)}ms"
    end
  end
end
