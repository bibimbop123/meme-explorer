#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================
# SET REDIS TTLs ON ALL KEYS
# ============================================
# Week 1 Day 6-7: Prevent Redis memory bloat
# Sets 24-hour TTL on all keys without expiry

require_relative '../lib/services/redis_service'
require_relative '../lib/app_logger'

DEFAULT_TTL = 24 * 60 * 60 # 24 hours

puts "=" * 60
puts "REDIS TTL MANAGEMENT"
puts "=" * 60

begin
  RedisService.redis_pool.with do |redis|
    # Get all keys
    all_keys = redis.keys('*')
    puts "Found #{all_keys.length} Redis keys"
    
    keys_without_ttl = []
    keys_updated = 0
    
    all_keys.each do |key|
      ttl = redis.ttl(key)
      
      if ttl == -1 # No expiry set
        keys_without_ttl << key
        redis.expire(key, DEFAULT_TTL)
        keys_updated += 1
      end
    end
    
    puts ""
    puts "Results:"
    puts "  Total keys: #{all_keys.length}"
    puts "  Keys without TTL: #{keys_without_ttl.length}"
    puts "  Keys updated: #{keys_updated}"
    puts ""
    
    if keys_without_ttl.any?
      puts "Keys that were updated (first 10):"
      keys_without_ttl.first(10).each do |key|
        puts "  - #{key}"
      end
    end
    
    puts ""
    puts "✅ All keys now have 24-hour TTL"
  end
rescue => e
  puts "❌ Error: #{e.message}"
  exit 1
end
