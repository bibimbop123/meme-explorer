# frozen_string_literal: true
require 'digest'
require 'json'
require 'securerandom'
require_relative 'redis_service'
require_relative 'viewing_history_service'

module MemeExplorer
  # Unused route-integration prerequisite, separate from 120-second leases.
  class FeedAcknowledgementStore
    TTL = 1800
    LIMIT = 20
    TOTAL_LIMIT = 200 # Pending credentials plus completed retry receipts; no eviction.
    HISTORY = <<~LUA.freeze
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1000000
      redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now - tonumber(ARGV[1]))
      redis.call('ZREMRANGEBYRANK', KEYS[1], 0, -(tonumber(ARGV[2]) + 1))
      return redis.call('ZRANGE', KEYS[1], 0, tonumber(ARGV[2]) - 1, 'WITHSCORES')
    LUA

    # Snapshot only: admission still needs an atomic eligibility/lease check.
    # Reading never renews history retention; Redis failure is not empty history.
    def self.history(session_id)
      return { status: :invalid } unless valid_id?(session_id)
      key = "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(session_id)}}:history"
      reply = RedisService.with_redis do |redis|
        redis.eval(HISTORY, keys: [key], argv: [ViewingHistoryService::HISTORY_TTL, ViewingHistoryService::MAX_HISTORY_SIZE])
      end
      return { status: :unavailable } unless reply.is_a?(Array) && reply.length.even? &&
        reply.length <= ViewingHistoryService::MAX_HISTORY_SIZE * 2
      entries = reply.each_slice(2).map do |content, score|
        timestamp = Float(score)
        return { status: :unavailable } unless valid_content?(content) && timestamp.finite? && timestamp > 0
        { content: content, acknowledged_at: timestamp }
      end
      { status: :available, entries: entries }
    rescue StandardError
      { status: :unavailable }
    end
    ISSUE = <<~LUA.freeze
      local expected = {'zset', 'hash', 'zset'}
      for index, kind in ipairs(expected) do
        local actual = redis.call('TYPE', KEYS[index]).ok
        if actual ~= 'none' and actual ~= kind then return -1 end
      end
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1000000
      local expired = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', now)
      for _, token in ipairs(expired) do
        redis.call('HDEL', KEYS[2], token)
        redis.call('ZREM', KEYS[3], token)
      end
      redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', now)
      if redis.call('ZCARD', KEYS[3]) >= tonumber(ARGV[4]) then return 2 end
      if redis.call('ZCARD', KEYS[1]) >= tonumber(ARGV[5]) then return 4 end
      if redis.call('HEXISTS', KEYS[2], ARGV[1]) == 1 then return 3 end
      redis.call('ZADD', KEYS[1], now + tonumber(ARGV[3]), ARGV[1])
      redis.call('ZADD', KEYS[3], now + tonumber(ARGV[3]), ARGV[1])
      redis.call('HSET', KEYS[2], ARGV[1], ARGV[2])
      redis.call('EXPIRE', KEYS[1], ARGV[3])
      redis.call('EXPIRE', KEYS[2], ARGV[3])
      redis.call('EXPIRE', KEYS[3], ARGV[3])
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
    RECONCILE = <<~LUA.freeze
      -- Scripts do not roll back: reject predictable schema failures before writes.
      local expected = {'zset', 'hash', 'zset', 'zset', 'hash', 'zset'}
      for index, kind in ipairs(expected) do
        local actual = redis.call('TYPE', KEYS[index]).ok
        if actual ~= 'none' and actual ~= kind then return -1 end
      end
      local time = redis.call('TIME')
      local now = tonumber(time[1]) + tonumber(time[2]) / 1000000
      local expiry = redis.call('ZSCORE', KEYS[1], ARGV[1])
      if not expiry or tonumber(expiry) <= now then return 0 end
      local raw = redis.call('HGET', KEYS[2], ARGV[1])
      if not raw then return 0 end
      local ok, data = pcall(cjson.decode, raw)
      if not ok or type(data) ~= 'table' then return -1 end
      if data.impression_id ~= ARGV[2] or data.content ~= ARGV[3] then return 0 end
      local owner = data.reservation_token
      if owner == nil or owner == cjson.null then owner = '' end
      if owner ~= ARGV[5] then return 0 end
      local timestamp = tonumber(ARGV[4])
      if timestamp > now or timestamp <= now - tonumber(ARGV[6]) then return 0 end
      if data.acknowledged_at then
        timestamp = tonumber(data.acknowledged_at)
        if not timestamp or timestamp > now or timestamp <= now - tonumber(ARGV[6]) then return -1 end
      end
      redis.call('ZREMRANGEBYSCORE', KEYS[3], '-inf', now - tonumber(ARGV[6]))
      local previous = redis.call('ZSCORE', KEYS[3], ARGV[3])
      if not previous or tonumber(previous) < timestamp then
        redis.call('ZADD', KEYS[3], timestamp, ARGV[3])
      end
      redis.call('ZREMRANGEBYRANK', KEYS[3], 0, -(tonumber(ARGV[7]) + 1))
      -- Expiry derives from recorded time, never extends indefinitely on retry.
      local remaining = math.ceil(timestamp + tonumber(ARGV[6]) - now)
      local ttl = redis.call('TTL', KEYS[3])
      if ttl < remaining then redis.call('EXPIRE', KEYS[3], remaining) end
      -- Preserve the original decimal representation across cjson round trips.
      if not data.acknowledged_at then data.acknowledged_at = ARGV[4] end
      redis.call('HSET', KEYS[2], ARGV[1], cjson.encode(data))
      if ARGV[5] ~= '' and redis.call('HGET', KEYS[5], ARGV[8]) == ARGV[5] then
        redis.call('HDEL', KEYS[5], ARGV[8])
        redis.call('ZREM', KEYS[4], ARGV[8])
      end
      -- Last mutation: failed reconciliation must not admit more pending work.
      redis.call('ZREM', KEYS[6], ARGV[1])
      return 1
    LUA

    # Trusted-server primitive only: caller must first commit/verify the DB
    # impression and supply its original timestamp. No DB or route integration yet.
    def self.reconcile(session_id, token, impression_id:, acknowledged_at:, reservation_token: nil)
      return { status: :invalid } unless acknowledged_at.is_a?(Numeric) && acknowledged_at.finite? &&
        acknowledged_at > 0 && (reservation_token.nil? || valid_id?(reservation_token))
      binding = lookup(session_id, token, impression_id: impression_id)
      return binding unless binding[:status] == :valid
      return { status: :invalid } if reservation_token && reservation_token != binding[:reservation_token]
      digest = Digest::SHA256.hexdigest(session_id)
      history = "feed:acknowledged:v1:{#{digest}}:history"
      leases = "feed:reservations:v1:{#{digest}}"
      reply = RedisService.with_redis do |redis|
        redis.eval(RECONCILE, keys: [*keys(session_id), history, "#{leases}:expiry", "#{leases}:owners", pending_key(session_id)],
          argv: [Digest::SHA256.hexdigest(token), impression_id, binding[:content], acknowledged_at,
                 binding[:reservation_token] || '', ViewingHistoryService::HISTORY_TTL,
                 ViewingHistoryService::MAX_HISTORY_SIZE, Digest::SHA256.hexdigest(binding[:content])])
      end
      case reply
      when 1 then { status: :reconciled }
      when 0 then { status: :invalid }
      else { status: :unavailable }
      end
    rescue StandardError
      { status: :unavailable }
    end

    def self.issue(session_id, content, impression_id:, title: nil, subreddit: nil, user_id: nil, reservation_token: nil)
      return { status: :invalid } unless valid_id?(session_id) && valid_content?(content) && valid_id?(impression_id)
      return { status: :invalid } unless reservation_token.nil? || valid_id?(reservation_token)
      return { status: :invalid } unless valid_issuance_context?(title: title, subreddit: subreddit, user_id: user_id)
      context = { 'title' => title, 'subreddit' => subreddit, 'user_id' => user_id }
      token = SecureRandom.hex(32)
      payload = JSON.generate('content' => content, 'impression_id' => impression_id, 'context' => context,
        'reservation_token' => reservation_token)
      reply = RedisService.with_redis do |redis|
        redis.eval(ISSUE, keys: [*keys(session_id), pending_key(session_id)], argv: [Digest::SHA256.hexdigest(token), payload, TTL, LIMIT, TOTAL_LIMIT])
      end
      case reply
      when 1 then { status: :issued, token: token }
      when 2 then { status: :limit_reached }
      when 4 then { status: :receipt_limit_reached }
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
      return { status: :unavailable } unless valid_context?(data['context'])
      return { status: :unavailable } if data.key?('acknowledged_at') && !valid_timestamp?(data['acknowledged_at'])
      return { status: :unavailable } unless data['reservation_token'].nil? || valid_id?(data['reservation_token'])
      return { status: :invalid } if impression_id && impression_id != data['impression_id']
      { status: :valid, content: data['content'], impression_id: data['impression_id'], context: data['context'],
        reservation_token: data['reservation_token'] }
    rescue StandardError
      { status: :unavailable }
    end

    def self.valid_id?(value)
      value.is_a?(String) && value.match?(/\A[a-f0-9]{64}\z/)
    end

    def self.valid_content?(value)
      value.is_a?(String) && value.valid_encoding? && value.bytesize <= 4096 && !value.strip.empty?
    end

    def self.valid_context?(value)
      value.is_a?(Hash) && value.keys.sort == %w[subreddit title user_id] &&
        %w[title subreddit].all? { |key| value[key].nil? || valid_content?(value[key]) } &&
        (value['user_id'].nil? || (value['user_id'].is_a?(Integer) && value['user_id'].between?(1, 2_147_483_647)))
    end

    # Shared preflight for trusted issuance orchestration; does not access Redis.
    def self.valid_issuance_context?(title: nil, subreddit: nil, user_id: nil)
      valid_context?('title' => title, 'subreddit' => subreddit, 'user_id' => user_id)
    end

    def self.valid_timestamp?(value)
      return false unless value.is_a?(String) && value.bytesize <= 32 && value.match?(/\A\d+(?:\.\d+)?\z/)
      timestamp = Float(value)
      timestamp.finite? && timestamp > 0
    end

    def self.keys(session_id)
      prefix = "feed:ack:v1:{#{Digest::SHA256.hexdigest(session_id)}}"
      ["#{prefix}:expiry", "#{prefix}:metadata"]
    end
    def self.pending_key(session_id)
      "feed:ack:v1:{#{Digest::SHA256.hexdigest(session_id)}}:pending"
    end
    private_class_method :valid_id?, :valid_content?, :valid_context?, :valid_timestamp?, :keys, :pending_key
  end
end