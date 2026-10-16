# frozen_string_literal: true
require 'digest'
require 'securerandom'
require_relative 'redis_service'
require_relative 'viewing_history_service'

module MemeExplorer
  # Active-selection leases only. Not yet wired into selection or impressions.
  class FeedReservationService
    TTL = 120
    LIMIT = 20
    ACQUIRE = <<~LUA.freeze
      local expected = {'zset', 'hash'}
      for index, kind in ipairs(expected) do
        local actual = redis.call('TYPE', KEYS[index]).ok
        if actual ~= 'none' and actual ~= kind then return -1 end
      end
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1000000
      local expired = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', now)
      for _, content in ipairs(expired) do
        redis.call('HDEL', KEYS[2], content)
      end
      redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now)
      if redis.call('HEXISTS', KEYS[2], ARGV[1]) == 1 then return 2 end
      if redis.call('ZCARD', KEYS[1]) >= tonumber(ARGV[4]) then return 3 end
      redis.call('HSET', KEYS[2], ARGV[1], ARGV[2])
      redis.call('ZADD', KEYS[1], now + tonumber(ARGV[3]), ARGV[1])
      redis.call('EXPIRE', KEYS[1], ARGV[3])
      redis.call('EXPIRE', KEYS[2], ARGV[3])
      return 1
    LUA
    ACQUIRE_UNSEEN = (<<~LUA + ACQUIRE).freeze
      local expected = {'zset', 'hash', 'zset'}
      for index, kind in ipairs(expected) do
        local actual = redis.call('TYPE', KEYS[index]).ok
        if actual ~= 'none' and actual ~= kind then return -1 end
      end
      local recorded = redis.call('ZSCORE', KEYS[3], ARGV[5])
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1000000
      if recorded and tonumber(recorded) > now - tonumber(ARGV[6]) then return 4 end
    LUA

    # Atomic check against acknowledged history, not legacy selection history.
    # Does not authorize exhausted replay or select a candidate from inventory.
    def self.acquire_unseen(session_id, content)
      return { status: :invalid } unless valid_session?(session_id) && valid_content?(content)
      token = SecureRandom.hex(32)
      history = "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(session_id)}}:history"
      reply = RedisService.with_redis do |redis|
        redis.eval(ACQUIRE_UNSEEN, keys: [*keys(session_id), history],
          argv: [Digest::SHA256.hexdigest(content), token, TTL, LIMIT, content, ViewingHistoryService::HISTORY_TTL])
      end
      case reply
      when 1 then { status: :reserved, token: token }
      when 2 then { status: :already_reserved }
      when 3 then { status: :limit_reached }
      when 4 then { status: :already_acknowledged }
      else { status: :unavailable }
      end
    rescue StandardError
      { status: :unavailable }
    end
    RELEASE = <<~LUA.freeze
      local expected = {'zset', 'hash'}
      for index, kind in ipairs(expected) do
        local actual = redis.call('TYPE', KEYS[index]).ok
        if actual ~= 'none' and actual ~= kind then return -1 end
      end
      if redis.call('HGET', KEYS[2], ARGV[1]) ~= ARGV[2] then return 0 end
      redis.call('HDEL', KEYS[2], ARGV[1])
      redis.call('ZREM', KEYS[1], ARGV[1])
      return 1
    LUA
    VALIDATE = <<~LUA.freeze
      local expiry = redis.call('ZSCORE', KEYS[1], ARGV[1])
      if not expiry then return 0 end
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1000000
      if tonumber(expiry) <= now then return 0 end
      if redis.call('HGET', KEYS[2], ARGV[1]) ~= ARGV[2] then return 0 end
      return 1
    LUA

    # Active lease validation only; expired leases are not valid ACK credentials.
    # Does not renew expiry or mutate state. Distinguish infrastructure failure.
    def self.validate(session_id, content, token)
      return { status: :invalid } unless valid_session?(session_id) && valid_content?(content) && valid_session?(token)
      reply = RedisService.with_redis do |redis|
        redis.eval(VALIDATE, keys: keys(session_id), argv: [Digest::SHA256.hexdigest(content), token])
      end
      case reply
      when 1 then { status: :active }
      when 0 then { status: :invalid }
      else { status: :unavailable }
      end
    rescue StandardError
      { status: :unavailable }
    end

    def self.acquire(session_id, content)
      return { status: :invalid } unless valid_session?(session_id) && valid_content?(content)
      token = SecureRandom.hex(32)
      reply = RedisService.with_redis do |redis|
        redis.eval(ACQUIRE, keys: keys(session_id), argv: [Digest::SHA256.hexdigest(content), token, TTL, LIMIT])
      end
      case reply
      when 1 then { status: :reserved, token: token }
      when 2 then { status: :already_reserved }
      when 3 then { status: :limit_reached }
      else { status: :unavailable }
      end
    rescue StandardError
      { status: :unavailable }
    end

    def self.release(session_id, content, token)
      return false unless valid_session?(session_id) && valid_content?(content) && valid_session?(token)
      RedisService.with_redis do |redis|
        redis.eval(RELEASE, keys: keys(session_id), argv: [Digest::SHA256.hexdigest(content), token])
      end == 1
    rescue StandardError
      false
    end

    def self.valid_session?(value)
      value.is_a?(String) && value.match?(/\A[a-f0-9]{64}\z/)
    end

    def self.valid_content?(value)
      value.is_a?(String) && value.valid_encoding? && value.bytesize <= 4096 && !value.strip.empty?
    end

    def self.keys(session_id)
      prefix = "feed:reservations:v1:{#{Digest::SHA256.hexdigest(session_id)}}"
      ["#{prefix}:expiry", "#{prefix}:owners"]
    end
    private_class_method :valid_session?, :valid_content?, :keys
  end
end