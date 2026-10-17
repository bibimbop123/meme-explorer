# frozen_string_literal: true
require 'date'
require_relative 'redis_service'

# Fixed-cardinality daily handler outcomes, not a complete HTTP outage monitor.
# Never accepts credential, media, session or account labels.
class LegacyImpressionMetrics
  PREFIX = 'legacy:impression_metrics'
  TTL = 172_800
  EVENTS = %w[issue_legacy issue_external issue_unavailable ack_recorded ack_duplicate ack_invalid ack_unavailable ack_bad_json].freeze

  def self.record(event)
    return false unless EVENTS.include?(event)

    day = Time.now.utc.to_date
    result = RedisService.with_redis do |redis|
      redis.multi do |transaction|
        transaction.hincrby(key(day), event, 1)
        transaction.expire(key(day), TTL)
      end
    end
    !result.nil?
  rescue StandardError
    false
  end

  def self.snapshot
    day = Time.now.utc.to_date
    values = RedisService.with_redis { |redis| redis.hgetall(key(day)) }
    return { available: false, counts: nil } unless values

    { available: true, date: day.iso8601, counts: EVENTS.to_h { |event| [event, Integer(values.fetch(event, '0'))] } }
  rescue StandardError
    { available: false, counts: nil }
  end

  def self.key(day)
    "#{PREFIX}:#{day.iso8601}"
  end
end