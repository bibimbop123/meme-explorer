# frozen_string_literal: true

require_relative '../spec_helper'
require 'benchmark'

RSpec.describe 'Performance and Load Tests' do
  describe 'Response Time Benchmarks' do
    it 'homepage loads in under 150ms' do
      times = []
      10.times do
        time = Benchmark.realtime { get '/' }
        times << time
      end
      
      p95 = times.sort[8] # 95th percentile (10 * 0.95 ≈ 9th item, 0-indexed)
      
      expect(p95).to be < 0.150, "P95: #{(p95 * 1000).round}ms (target: <150ms)"
      puts "  ✓ Homepage P95: #{(p95 * 1000).round(2)}ms"
    end

    it 'random meme endpoint loads in under 150ms' do
      # Warm up cache
      get '/random'
      
      times = []
      10.times do
        time = Benchmark.realtime { get '/random' }
        times << time
      end
      
      p95 = times.sort[8]
      
      expect(p95).to be < 0.150, "P95: #{(p95 * 1000).round}ms (target: <150ms)"
      puts "  ✓ Random meme P95: #{(p95 * 1000).round(2)}ms"
    end

    it 'trending page loads in under 200ms (more complex query)' do
      times = []
      10.times do
        time = Benchmark.realtime { get '/trending' }
        times << time
      end
      
      p95 = times.sort[8]
      
      expect(p95).to be < 0.200, "P95: #{(p95 * 1000).round}ms (target: <200ms)"
      puts "  ✓ Trending page P95: #{(p95 * 1000).round(2)}ms"
    end

    it 'profile page loads in under 150ms' do
      user = login_test_user
      
      times = []
      10.times do
        time = Benchmark.realtime { get '/profile' }
        times << time
      end
      
      p95 = times.sort[8]
      
      expect(p95).to be < 0.150, "P95: #{(p95 * 1000).round}ms (target: <150ms)"
      puts "  ✓ Profile page P95: #{(p95 * 1000).round(2)}ms"
    end

    it 'leaderboard loads in under 100ms (materialized view)' do
      times = []
      10.times do
        time = Benchmark.realtime { get '/leaderboard' }
        times << time
      end
      
      p95 = times.sort[8]
      
      expect(p95).to be < 0.100, "P95: #{(p95 * 1000).round}ms (target: <100ms)"
      puts "  ✓ Leaderboard P95: #{(p95 * 1000).round(2)}ms"
    end
  end

  describe 'Database Query Performance' do
    it 'meme selection query completes in under 50ms' do
      time = Benchmark.realtime do
        DB[:memes]
          .where(is_deleted: false)
          .where { created_at > Time.now - 86400 * 7 }
          .order(Sequel.desc(:created_at))
          .limit(100)
          .all
      end
      
      expect(time).to be < 0.050, "Query time: #{(time * 1000).round}ms (target: <50ms)"
      puts "  ✓ Meme selection: #{(time * 1000).round(2)}ms"
    end

    it 'trending calculation query completes in under 100ms' do
      time = Benchmark.realtime do
        DB[:trending_memes_hourly]
          .limit(50)
          .all
      end
      
      expect(time).to be < 0.100, "Query time: #{(time * 1000).round}ms (target: <100ms)"
      puts "  ✓ Trending query: #{(time * 1000).round(2)}ms"
    end

    it 'user profile query completes in under 30ms' do
      user_id = DB[:users].first[:id]
      
      time = Benchmark.realtime do
        DB[:users]
          .where(id: user_id)
          .first
      end
      
      expect(time).to be < 0.030, "Query time: #{(time * 1000).round}ms (target: <30ms)"
      puts "  ✓ Profile query: #{(time * 1000).round(2)}ms"
    end

    it 'leaderboard query completes in under 20ms (materialized view)' do
      time = Benchmark.realtime do
        DB[:leaderboard_hourly]
          .limit(100)
          .all
      end
      
      expect(time).to be < 0.020, "Query time: #{(time * 1000).round}ms (target: <20ms)"
      puts "  ✓ Leaderboard query: #{(time * 1000).round(2)}ms"
    end
  end

  describe 'Concurrent Load Testing' do
    it 'handles 50 concurrent requests without degradation' do
      threads = []
      response_times = []
      mutex = Mutex.new
      
      50.times do
        threads << Thread.new do
          time = Benchmark.realtime { get '/random' }
          mutex.synchronize { response_times << time }
        end
      end
      
      threads.each(&:join)
      
      avg_time = response_times.sum / response_times.size
      max_time = response_times.max
      
      expect(avg_time).to be < 0.200, "Avg: #{(avg_time * 1000).round}ms"
      expect(max_time).to be < 0.500, "Max: #{(max_time * 1000).round}ms"
      
      puts "  ✓ 50 concurrent requests - Avg: #{(avg_time * 1000).round(2)}ms, Max: #{(max_time * 1000).round(2)}ms"
    end

    it 'maintains performance under 100 sequential requests' do
      times = []
      
      100.times do
        times << Benchmark.realtime { get '/random' }
      end
      
      first_10_avg = times[0..9].sum / 10
      last_10_avg = times[90..99].sum / 10
      degradation = ((last_10_avg - first_10_avg) / first_10_avg) * 100
      
      expect(degradation).to be < 20, "Performance degraded by #{degradation.round(1)}%"
      puts "  ✓ Performance degradation: #{degradation.round(1)}%"
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

    it 'closes database connections properly' do
      initial_connections = DB.pool.size
      
      10.times do
        DB[:memes].limit(10).all
      end
      
      final_connections = DB.pool.size
      
      expect(final_connections).to eq(initial_connections)
      puts "  ✓ Connection pool stable: #{final_connections} connections"
    end
  end

  describe 'Cache Performance' do
    it 'cache hits are significantly faster than cache misses' do
      cache_key = 'performance_test_key'
      
      # Clear cache
      CacheManager.delete(cache_key)
      
      # Measure cache miss
      miss_time = Benchmark.realtime do
        CacheManager.fetch(cache_key, ttl: 300) { sleep 0.01; 'test_value' }
      end
      
      # Measure cache hit
      hit_time = Benchmark.realtime do
        CacheManager.fetch(cache_key, ttl: 300) { 'test_value' }
      end
      
      speedup = miss_time / hit_time
      
      expect(speedup).to be > 5, "Cache only #{speedup.round(1)}x faster"
      puts "  ✓ Cache speedup: #{speedup.round(1)}x"
    end

    it 'handles cache failures gracefully' do
      # Simulate cache failure
      allow(CacheManager).to receive(:get).and_return(nil)
      
      time = Benchmark.realtime do
        get '/random'
      end
      
      # Should fall back to database, still reasonable performance
      expect(time).to be < 0.300
      expect(last_response).to be_ok
      puts "  ✓ Cache failure handled: #{(time * 1000).round(2)}ms"
    end
  end

  describe 'API Endpoint Performance' do
    it 'API meme fetch completes in under 100ms' do
      time = Benchmark.realtime do
        get '/api/memes/random'
      end
      
      expect(time).to be < 0.100
      expect(last_response).to be_ok
      puts "  ✓ API meme fetch: #{(time * 1000).round(2)}ms"
    end

    it 'API trending endpoint completes in under 150ms' do
      time = Benchmark.realtime do
        get '/api/trending'
      end
      
      expect(time).to be < 0.150
      expect(last_response).to be_ok
      puts "  ✓ API trending: #{(time * 1000).round(2)}ms"
    end
  end

  # Helper methods
  def login_test_user
    user = {
      username: "perf_test_#{Time.now.to_i}",
      email: "perf#{Time.now.to_i}@test.com",
      password: 'TestPass123!'
    }
    
    DB[:users].insert(
      username: user[:username],
      email: user[:email],
      password_hash: BCrypt::Password.create(user[:password]),
      created_at: Time.now
    )
    
    post '/login', { username: user[:username], password: user[:password] }
    user
  end
end
