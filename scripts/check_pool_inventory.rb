# frozen_string_literal: true

require 'json'
require 'redis'

# Fixed-key, read-only metadata sampling. No application boot or payload reads.
class PoolInventoryDiagnostic
  POOLS = %w[random fresh trending surprise diverse].freeze

  def self.report(redis, now: Time.now.to_i)
    raw_count = redis.get('meme_pool:count')
    raw_refresh = redis.get('meme_pool:last_refresh')
    count = raw_count.to_s.match?(/\A[0-9]+\z/) ? raw_count.to_i : nil
    refreshed_at = raw_refresh.to_s.match?(/\A[0-9]+\z/) ? raw_refresh.to_i : nil
    {
      metadata_count: count,
      seconds_since_refresh: refreshed_at ? now - refreshed_at : nil,
      legacy_pool_ttl: redis.ttl('meme_pool'),
      count_ttl: redis.ttl('meme_pool:count'),
      cooldown_ttl: redis.ttl('meme_pool:bootstrap_cooldown'),
      maintenance_lease_ttl: redis.ttl('lock:meme_pool:maintenance'),
      pools: POOLS.to_h do |pool|
        [pool, { list_count: redis.llen("meme_pool:#{pool}_ids"),
                 list_ttl: redis.ttl("meme_pool:#{pool}_ids"),
                 json_ttl: redis.ttl("meme_pool:#{pool}") }]
      end,
      note: 'Non-atomic metadata sample; counts are not verified unique payload inventory. TTL -2 means missing; -1 means no expiry.'
    }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    url = ENV.fetch('REDIS_URL')
    raise ArgumentError if url.empty?
    redis = Redis.new(url: url, connect_timeout: 2, read_timeout: 2, write_timeout: 2)
    puts JSON.pretty_generate(PoolInventoryDiagnostic.report(redis))
  rescue StandardError
    # Never print exception messages: client errors can include connection secrets.
    warn 'Inventory diagnostic failed. Check REDIS_URL, Redis access and pool key types; connection details omitted.'
    exit 1
  ensure
    redis&.close
  end
end