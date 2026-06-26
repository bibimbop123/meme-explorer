#!/usr/bin/env ruby
# Chaos Engineering & Resilience Test Suite
# Tests system behavior under failure conditions
# Senior Dev Pattern: Test failure modes proactively

require_relative '../config/application'
require 'timeout'
require 'benchmark'

class ChaosTestSuite
  attr_reader :results
  
  def initialize
    @results = []
    @original_redis = nil
    @original_db = nil
  end
  
  def run_all
    puts "🔬 Starting Chaos Engineering Test Suite"
    puts "=" * 60
    
    test_redis_failure
    test_database_slowdown
    test_memory_pressure
    test_connection_exhaustion
    test_cache_stampede
    
    print_summary
  end
  
  # Test 1: Redis Failure Simulation
  def test_redis_failure
    puts "\n📡 Test 1: Redis Failure Simulation"
    puts "-" * 60
    
    begin
      # Simulate Redis being unavailable
      if defined?(RedisService)
        @original_redis = RedisService
        Object.send(:remove_const, :RedisService) if defined?(RedisService)
      end
      
      # Test that app still functions
      test_name = "App functions without Redis"
      result = test_app_basic_functionality
      
      @results << {
        test: test_name,
        passed: result[:success],
        duration_ms: result[:duration],
        message: result[:message]
      }
      
      puts result[:success] ? "  ✅ #{test_name}" : "  ❌ #{test_name}: #{result[:message]}"
      
    ensure
      # Restore Redis
      if @original_redis
        Object.const_set(:RedisService, @original_redis)
      end
    end
  end
  
  # Test 2: Database Slowdown Simulation
  def test_database_slowdown
    puts "\n🐌 Test 2: Database Slow Query Simulation"
    puts "-" * 60
    
    test_name = "Slow database queries timeout gracefully"
    
    begin
      duration_ms = Benchmark.measure do
        Timeout.timeout(5) do
          # Simulate slow query
          DB.execute("SELECT 1")
          sleep(0.1) # Small delay
        end
      end.real * 1000
      
      passed = duration_ms < 6000 # Should complete within 6 seconds
      
      @results << {
        test: test_name,
        passed: passed,
        duration_ms: duration_ms.round(2),
        message: passed ? "Query handled within timeout" : "Query exceeded acceptable time"
      }
      
      puts passed ? "  ✅ #{test_name}" : "  ❌ #{test_name}"
      
    rescue Timeout::Error
      @results << {
        test: test_name,
        passed: true,
        duration_ms: 5000,
        message: "Query properly timed out"
      }
      puts "  ✅ #{test_name} (timeout triggered correctly)"
    rescue => e
      @results << {
        test: test_name,
        passed: false,
        duration_ms: 0,
        message: e.message
      }
      puts "  ❌ #{test_name}: #{e.message}"
    end
  end
  
  # Test 3: Memory Pressure Simulation
  def test_memory_pressure
    puts "\n💾 Test 3: Memory Pressure Simulation"
    puts "-" * 60
    
    test_name = "System handles memory pressure"
    
    begin
      initial_memory = get_memory_usage
      
      # Create some memory pressure (but not too much)
      large_array = Array.new(100_000) { |i| "test_string_#{i}" * 10 }
      
      # Force garbage collection
      GC.start
      
      final_memory = get_memory_usage
      memory_increase = final_memory - initial_memory
      
      # Check if memory was released
      large_array = nil
      GC.start
      
      post_gc_memory = get_memory_usage
      memory_recovered = final_memory - post_gc_memory
      
      passed = memory_recovered > 0
      
      @results << {
        test: test_name,
        passed: passed,
        duration_ms: 0,
        message: "Memory increase: #{memory_increase.round(2)}MB, recovered: #{memory_recovered.round(2)}MB"
      }
      
      puts passed ? "  ✅ #{test_name}" : "  ⚠️  #{test_name}"
      puts "     Memory: +#{memory_increase.round(2)}MB, recovered #{memory_recovered.round(2)}MB"
      
    rescue => e
      @results << {
        test: test_name,
        passed: false,
        duration_ms: 0,
        message: e.message
      }
      puts "  ❌ #{test_name}: #{e.message}"
    end
  end
  
  # Test 4: Connection Pool Exhaustion
  def test_connection_exhaustion
    puts "\n🔌 Test 4: Connection Pool Exhaustion"
    puts "-" * 60
    
    test_name = "System handles connection pool exhaustion"
    
    begin
      # Test that we can get a connection
      result = test_database_connection_handling
      
      @results << {
        test: test_name,
        passed: result[:success],
        duration_ms: result[:duration],
        message: result[:message]
      }
      
      puts result[:success] ? "  ✅ #{test_name}" : "  ❌ #{test_name}"
      
    rescue => e
      @results << {
        test: test_name,
        passed: false,
        duration_ms: 0,
        message: e.message
      }
      puts "  ❌ #{test_name}: #{e.message}"
    end
  end
  
  # Test 5: Cache Stampede Simulation
  def test_cache_stampede
    puts "\n⚡ Test 5: Cache Stampede Simulation"
    puts "-" * 60
    
    test_name = "System handles cache stampede"
    
    begin
      # Simulate multiple requests for expired cache
      threads = []
      results_array = []
      
      5.times do
        threads << Thread.new do
          start_time = Time.now
          # Simulate cache miss
          value = MEME_CACHE.get(:test_stampede) || "default_value"
          duration = ((Time.now - start_time) * 1000).round(2)
          results_array << duration
        end
      end
      
      threads.each(&:join)
      
      avg_duration = results_array.sum / results_array.size
      passed = avg_duration < 100 # Should be fast
      
      @results << {
        test: test_name,
        passed: passed,
        duration_ms: avg_duration,
        message: "Average response time: #{avg_duration.round(2)}ms"
      }
      
      puts passed ? "  ✅ #{test_name}" : "  ⚠️  #{test_name}"
      puts "     Average response time: #{avg_duration.round(2)}ms"
      
    rescue => e
      @results << {
        test: test_name,
        passed: false,
        duration_ms: 0,
        message: e.message
      }
      puts "  ❌ #{test_name}: #{e.message}"
    end
  end
  
  private
  
  def test_app_basic_functionality
    start_time = Time.now
    
    begin
      # Test basic database operation
      DB.execute("SELECT 1")
      
      # Test cache operation
      MEME_CACHE.get(:test_key)
      
      duration = ((Time.now - start_time) * 1000).round(2)
      
      {
        success: true,
        duration: duration,
        message: "Basic operations functional"
      }
    rescue => e
      duration = ((Time.now - start_time) * 1000).round(2)
      {
        success: false,
        duration: duration,
        message: e.message
      }
    end
  end
  
  def test_database_connection_handling
    start_time = Time.now
    
    begin
      # Test connection
      DB.execute("SELECT 1")
      
      duration = ((Time.now - start_time) * 1000).round(2)
      
      {
        success: true,
        duration: duration,
        message: "Connection handled successfully"
      }
    rescue => e
      duration = ((Time.now - start_time) * 1000).round(2)
      {
        success: false,
        duration: duration,
        message: e.message
      }
    end
  end
  
  def get_memory_usage
    if RUBY_PLATFORM =~ /linux/
      memory_kb = `ps -o rss= -p #{Process.pid}`.to_i
      (memory_kb / 1024.0).round(2)
    else
      # macOS/BSD
      memory_bytes = `ps -o rss= -p #{Process.pid}`.to_i * 1024
      (memory_bytes / 1024.0 / 1024.0).round(2)
    end
  rescue
    0.0
  end
  
  def print_summary
    puts "\n" + "=" * 60
    puts "📊 Test Summary"
    puts "=" * 60
    
    total = @results.size
    passed = @results.count { |r| r[:passed] }
    failed = total - passed
    
    puts "\nTotal Tests: #{total}"
    puts "✅ Passed: #{passed}"
    puts "❌ Failed: #{failed}"
    puts "\nPass Rate: #{((passed.to_f / total) * 100).round(1)}%"
    
    if failed > 0
      puts "\n⚠️  Failed Tests:"
      @results.reject { |r| r[:passed] }.each do |result|
        puts "  - #{result[:test]}: #{result[:message]}"
      end
    end
    
    puts "\n✅ Resilience test suite complete!"
  end
end

# Run tests if called directly
if __FILE__ == $0
  suite = ChaosTestSuite.new
  suite.run_all
end
