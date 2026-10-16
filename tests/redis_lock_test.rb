# Standalone real-Redis contract test. Uses random keys, never flushes a DB.
# bundle exec ruby tests/redis_lock_test.rb
require 'redis'
require 'connection_pool'
require_relative '../lib/services/redis_service'

url = ENV.fetch('LOCK_TEST_REDIS_URL', 'redis://127.0.0.1:6379/15')
REDIS_POOL = ConnectionPool.new(size: 4, timeout: 2) { Redis.new(url: url) }
key = "test:meme-explorer:lease:#{SecureRandom.hex(16)}"

def check(description)
  raise "FAIL: #{description}" unless yield
  puts "PASS: #{description}"
end

begin
  first = RedisService.acquire_lock(key, ttl: 10)
  check('acquisition returns unique ownership token') { first.is_a?(String) && first.size == 64 }
  check('another instance cannot acquire active lease') { RedisService.acquire_lock(key, ttl: 10) == false }
  check('wrong owner cannot release lease') { RedisService.release_lock(key, SecureRandom.hex(32)) == false }
  check('owner can release its lease') { RedisService.release_lock(key, first) == true }

  expired_owner = RedisService.acquire_lock(key, ttl: 10)
  # Expire immediately, deterministically simulating time passing mid-work.
  REDIS_POOL.with { |redis| redis.pexpire(key, 0) }
  successor = RedisService.acquire_lock(key, ttl: 10)
  check('successor has a different token') { successor.is_a?(String) && successor != expired_owner }
  check('expired owner cannot delete successor') { RedisService.release_lock(key, expired_owner) == false }
  check('successor remains in Redis') { REDIS_POOL.with { |redis| redis.get(key) } == successor }
  check('successor releases normally') { RedisService.release_lock(key, successor) }

  results = Queue.new
  threads = 8.times.map { Thread.new { results << RedisService.acquire_lock(key, ttl: 10) } }
  threads.each(&:join)
  tokens = 8.times.map { results.pop }.select { |result| result.is_a?(String) }
  check('concurrent instances produce exactly one owner') { tokens.size == 1 }
  check('concurrent winner releases normally') { RedisService.release_lock(key, tokens.first) }
  check('invalid token is rejected') { RedisService.release_lock(key, nil) == false }
ensure
  REDIS_POOL.with { |redis| redis.del(key) }
  REDIS_POOL.shutdown(&:close)
end