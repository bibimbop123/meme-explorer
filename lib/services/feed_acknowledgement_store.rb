# frozen_string_literal: true
require 'digest'
require 'json'
require 'securerandom'
require_relative 'redis_service'

module MemeExplorer
  # Unused route-integration prerequisite, separate from 120-second leases.
  class FeedAcknowledgementStore
    TTL = 1800
    LIMIT = 20
    ISSUE = <<~LUA.freeze
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1000000
      local expired = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', now)
      for _, token in ipairs(expired) do redis.call('HDEL', KEYS[2], token) end
      redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now)
      if redis.call('ZCARD', KEYS[1]) >= tonumber(ARGV[4]) then return 2 end
      if redis.call('HEXISTS', KEYS[2], ARGV[1]) == 1 then return 3 end
      redis.call('ZADD', KEYS[1], now + tonumber(ARGV[3]), ARGV[1])
      redis.call('HSET', KEYS[2], ARGV[1], ARGV[2])
      redis.call('EXPIRE', KEYS[1], ARGV[3])
      redis.call('EXPIRE', KEYS[2], ARGV[3])
      return 1
    LUA
    LOOKUP = <<~LUA.freeze
      local expiry = redis.call('ZSCORE', KEYS[1], ARGV[1])
      if not expiry then return false end
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1000000
      if tonumber(expiry) <= now then return false end
      return redis.call('HGET', KEYS[2], ARGV[1])
    LUA

    def self.issue(session_id, content, impression_id:)
      return { status: :invalid } unless valid_id?(session_id) && valid_content?(content) && valid_id?(impression_id)
      token = SecureRandom.hex(32)
      payload = JSON.generate('content' => content, 'impression_id' => impression_id)
      reply = RedisService.with_redis do |redis|
        redis.eval(ISSUE, keys: keys(session_id), argv: [Digest::SHA256.hexdigest(token), payload, TTL, LIMIT])
      end
      case reply
      when 1 then { status: :issued, token: token }
      when 2 then { status: :limit_reached }
      else { status: :unavailable }
      end
    rescue StandardError
      { status: :unavailable }
    end

    def self.lookup(session_id, token, impression_id: nil)
      return { status: :invalid } unless valid_id?(session_id) && valid_id?(token) &&
        (impression_id.nil? || valid_id?(impression_id))
      reply = RedisService.with_redis do |redis|
        # Wrap so a missing Redis response differs from a missing token.
        [redis.eval(LOOKUP, keys: keys(session_id), argv: [Digest::SHA256.hexdigest(token)])]
      end
      return { status: :unavailable } unless reply.is_a?(Array)
      return { status: :invalid } unless reply.first
      return { status: :unavailable } unless reply.first.is_a?(String) && reply.first.bytesize <= 32_768
      data = JSON.parse(reply.first)
      return { status: :unavailable } unless data.is_a?(Hash) && valid_content?(data['content']) && valid_id?(data['impression_id'])
      return { status: :invalid } if impression_id && impression_id != data['impression_id']
      { status: :valid, content: data['content'], impression_id: data['impression_id'] }
    rescue StandardError
      { status: :unavailable }
    end

    def self.valid_id?(value)
      value.is_a?(String) && value.match?(/\A[a-f0-9]{64}\z/)
    end

    def self.valid_content?(value)
      value.is_a?(String) && value.valid_encoding? && value.bytesize <= 4096 && !value.strip.empty?
    end

    def self.keys(session_id)
      prefix = "feed:ack:v1:{#{Digest::SHA256.hexdigest(session_id)}}"
      ["#{prefix}:expiry", "#{prefix}:metadata"]
    end
    private_class_method :valid_id?, :valid_content?, :keys
  end
end