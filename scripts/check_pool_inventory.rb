# frozen_string_literal: true

require 'json'
require 'redis'
require 'time'
require 'set'

# Fixed-key, read-only sampling. Payload reads require explicit CLI opt-in.
class PoolInventoryDiagnostic
  POOLS = %w[random fresh trending surprise diverse].freeze
  MAX_PAYLOAD_BYTES = 8_388_608
  MAX_RECORDS = 5000

  # Opt-in payload read. Output contains aggregates only, not URLs/titles/users.
  def self.content_summary(redis, now: Time.now.to_i)
    raw = redis.getrange('meme_pool', 0, MAX_PAYLOAD_BYTES)
    return { status: 'oversized' } if raw.bytesize > MAX_PAYLOAD_BYTES
    return { status: 'missing_or_empty' } if raw.empty?
    records = JSON.parse(raw, max_nesting: 12)
    return { status: 'invalid' } unless records.is_a?(Array) && records.size <= MAX_RECORDS
    urls = Set.new
    summary = { status: 'available', records: records.size, invalid_records: 0,
                duplicate_urls: 0, source_age_under_day: 0, source_age_one_to_seven_days: 0,
                source_age_over_seven_days: 0, source_age_unknown: 0 }
    records.each do |record|
      url = record.is_a?(Hash) ? record['url'] : nil
      unless url.is_a?(String) && !url.strip.empty? && url.bytesize <= 4096
        summary[:invalid_records] += 1
        next
      end
      unless urls.add?(url)
        summary[:duplicate_urls] += 1
        next
      end
      value = record['created_at']
      created = begin
        value.is_a?(String) ? Time.parse(value).to_f : nil
      rescue ArgumentError
        nil
      end
      age = created && created > 0 && created <= now ? now - created : nil
      bucket = if age.nil? then :source_age_unknown
               elsif age < 86_400 then :source_age_under_day
               elsif age <= 604_800 then :source_age_one_to_seven_days
               else :source_age_over_seven_days
               end
      summary[bucket] += 1
    end
    summary.merge(unique_urls: urls.size,
      note: 'Age buckets count first occurrence per URL; source age unknown is not fresh. No media/visual quality validation; non-atomic sample.')
  rescue JSON::ParserError, ArgumentError
    { status: 'invalid' }
  end

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
    raise ArgumentError unless ARGV.empty? || ARGV == ['--content-summary']
    report = PoolInventoryDiagnostic.report(redis)
    report[:content_summary] = PoolInventoryDiagnostic.content_summary(redis) if ARGV == ['--content-summary']
    puts JSON.pretty_generate(report)
  rescue StandardError
    # Never print exception messages: client errors can include connection secrets.
    warn 'Inventory diagnostic failed. Check REDIS_URL, Redis access and pool key types; connection details omitted.'
    exit 1
  ensure
    redis&.close
  end
end