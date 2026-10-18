# frozen_string_literal: true

require 'json'

# Independent of Rack's whole-session snapshots. No account or media data.
class DiscoveryPreferencesStore
  class Unavailable < StandardError; end
  class Revoked < Unavailable; end
  TTL = 2_592_000

  def self.delete(identity)
    return unless identity.is_a?(String) && identity.match?(/\A[a-f0-9]{64}\z/)

    REDIS_POOL.with { |redis| redis.del("discovery:preferences:v1:#{identity}") }
  rescue StandardError => e
    raise Unavailable, "Discovery preferences unavailable (#{e.class})"
  end

  def self.revoke(identity)
    return unless identity.is_a?(String) && identity.match?(/\A[a-f0-9]{64}\z/)

    # Same key as mutations: SET and Lua scripts serialize in Redis. Keep the
    # marker for the maximum session lifetime, not just a guessed request timeout.
    REDIS_POOL.with do |redis|
      redis.set("discovery:preferences:v1:#{identity}", JSON.generate(revoked: true), ex: TTL)
    end
  rescue StandardError => e
    raise Unavailable, "Discovery preferences unavailable (#{e.class})"
  end

  SCRIPT = <<~LUA.freeze
    local raw = redis.call('GET', KEYS[1])
    local state = {hidden = {}, revision = 0}
    if raw then state = cjson.decode(raw) end
    if state.revoked then return 'revoked' end
    local action, name = ARGV[1], ARGV[2]
    if action == 'read' then return cjson.encode(state) end
    local found = false
    for _, value in ipairs(state.hidden) do
      if value == name then found = true end
    end
    if action == 'hide' then
      if not found then
        if #state.hidden >= 20 then return 'cap' end
        table.insert(state.hidden, name)
        state.undo = name
      end
    elseif action == 'restore' or action == 'undo' then
      local target = name
      if action == 'undo' then target = state.undo end
      local remaining = {}
      for _, value in ipairs(state.hidden) do
        if value ~= target then table.insert(remaining, value) end
      end
      state.hidden = remaining
      if state.undo == target then state.undo = nil end
    elseif action == 'reset' then
      state.hidden = {}
      state.undo = nil
    end
    state.revision = state.revision + 1
    local ttl = redis.call('TTL', KEYS[1])
    if ttl < 1 then ttl = tonumber(ARGV[3]) end
    local encoded = cjson.encode(state)
    redis.call('SET', KEYS[1], encoded, 'EX', ttl)
    return encoded
  LUA

  def self.call(identity, action: 'read', community: '')
    raise ArgumentError, 'Invalid discovery identity' unless identity.is_a?(String) && identity.match?(/\A[a-f0-9]{64}\z/)
    raise ArgumentError, 'Invalid action' unless %w[read hide restore undo reset].include?(action)
    name = community.to_s.downcase
    if %w[hide restore].include?(action) && !name.match?(/\A[a-z0-9_]{1,32}\z/)
      raise ArgumentError, 'Invalid community'
    end
    result = begin
      REDIS_POOL.with do |redis|
        redis.eval(SCRIPT, keys: ["discovery:preferences:v1:#{identity}"], argv: [action, name, TTL])
      end
    rescue StandardError => e
      raise Unavailable, "Discovery preferences unavailable (#{e.class})"
    end
    return :cap if result == 'cap'
    raise Revoked, 'Discovery session ended. Reload to start a new session.' if result == 'revoked'

    state = JSON.parse(result)
    # Redis Lua encodes an empty table as {}, not [].
    state['hidden'] = [] if state['hidden'] == {}
    state
  end
end