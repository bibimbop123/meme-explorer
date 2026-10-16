# frozen_string_literal: true
require 'digest'
require 'securerandom'
require_relative 'redis_service'

module MemeExplorer
  # Active-selection leases only. Not yet wired into selection or impressions.
  class FeedReservationService
    TTL = 120
    LIMIT = 20
    ACQUIRE = <<~LUA.freeze
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
    RELEASE = <<~LUA.freeze
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
      value.is_a?(String) && !value.strip.empty? && value.bytesize <= 4096
    end

    def self.keys(session_id)
      prefix = "feed:reservations:v1:{#{Digest::SHA256.hexdigest(session_id)}}"
      ["#{prefix}:expiry", "#{prefix}:owners"]
    end
    private_class_method :valid_session?, :valid_content?, :keys
  end
end