# frozen_string_literal: true
require 'digest'
require 'json'
require_relative 'redis_service'
require_relative '../security/media_url'

# Independent legacy credentials; never writes acknowledged or selection history.
class LegacyImpressionStore
  TTL = 1800
  LIMIT = 20
  MAX_BYTES = 16_384
  ISSUE = <<~LUA.freeze
    local a = redis.call('TYPE', KEYS[1]).ok
    local b = redis.call('TYPE', KEYS[2]).ok
    if (a ~= 'none' and a ~= 'zset') or (b ~= 'none' and b ~= 'hash') then return 0 end
    if redis.call('ZCARD', KEYS[1]) ~= redis.call('HLEN', KEYS[2]) then return 0 end
    local now = tonumber(redis.call('TIME')[1])
    local expired = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', now)
    for _, id in ipairs(expired) do redis.call('HDEL', KEYS[2], id) end
    redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now)
    if redis.call('HEXISTS', KEYS[2], ARGV[1]) == 1 then return 0 end
    while redis.call('ZCARD', KEYS[1]) >= tonumber(ARGV[4]) do
      local oldest = redis.call('ZRANGE', KEYS[1], 0, 0)[1]
      redis.call('ZREM', KEYS[1], oldest)
      redis.call('HDEL', KEYS[2], oldest)
    end
    redis.call('ZADD', KEYS[1], now + tonumber(ARGV[3]), ARGV[1])
    redis.call('HSET', KEYS[2], ARGV[1], ARGV[2])
    redis.call('EXPIRE', KEYS[1], ARGV[3])
    redis.call('EXPIRE', KEYS[2], ARGV[3])
    return 1
  LUA
  LOOKUP = <<~LUA.freeze
    local expiry = redis.call('ZSCORE', KEYS[1], ARGV[1])
    if not expiry or tonumber(expiry) <= tonumber(redis.call('TIME')[1]) then return false end
    return redis.call('HGET', KEYS[2], ARGV[1])
  LUA

  def self.keys(binding, user_id)
    digest = Digest::SHA256.hexdigest("#{binding}:#{user_id || 'guest'}")
    ["legacy:impressions:{#{digest}}:expiry", "legacy:impressions:{#{digest}}:items"]
  end

  def self.valid_id?(value)
    value.is_a?(String) && value.match?(/\A[a-f0-9]{64}\z/)
  end

  def self.issue(binding, user_id, id, item)
    return false unless valid_id?(binding) && valid_id?(id) && valid_item?(item, user_id)
    raw = JSON.generate(item.slice('url', 'title', 'subreddit', 'user_id'))
    return false if raw.bytesize > MAX_BYTES
    RedisService.with_redis { |redis| redis.eval(ISSUE, keys: keys(binding, user_id), argv: [id, raw, TTL, LIMIT]) } == 1
  rescue StandardError
    false
  end

  def self.lookup(binding, user_id, id)
    return { status: :missing } unless valid_id?(binding) && valid_id?(id)
    reply = RedisService.with_redis do |redis|
      [redis.eval(LOOKUP, keys: keys(binding, user_id), argv: [id])]
    end
    return { status: :unavailable } unless reply
    return { status: :missing } unless reply.first
    return { status: :unavailable } unless reply.first.is_a?(String) && reply.first.bytesize <= MAX_BYTES
    item = JSON.parse(reply.first)
    return { status: :unavailable } unless valid_item?(item, user_id)
    { status: :found, item: item }
  rescue StandardError
    { status: :unavailable }
  end

  def self.valid_item?(item, user_id)
    item.is_a?(Hash) && item.key?('user_id') && item['user_id'] == user_id &&
      item['url'].is_a?(String) && MediaUrl.safe(item['url']) &&
      %w[title subreddit].all? { |key| item[key].nil? || item[key].is_a?(String) }
  end
end