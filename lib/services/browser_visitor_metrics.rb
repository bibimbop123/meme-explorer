# frozen_string_literal: true
require 'digest'
require 'time'

# Last observation only; no IP, URL, user-agent or account linkage stored here.
class BrowserVisitorMetrics
  WINDOWS = { '24h' => 86_400, '7d' => 604_800, '30d' => 2_592_000 }.freeze

  def self.record(identity, now: Time.now.utc)
    raise ArgumentError unless identity.is_a?(String) && identity.match?(/\A[a-f0-9]{64}\z/)
    DB.transaction do
      DB.execute('INSERT INTO browser_visitor_collection (id, started_at) VALUES (1, ?) ON CONFLICT DO NOTHING', [now.iso8601(6)])
      DB.execute('INSERT INTO browser_visitors (visitor_key, last_seen_at) VALUES (?, ?) ON CONFLICT(visitor_key) DO UPDATE SET last_seen_at = GREATEST(browser_visitors.last_seen_at, EXCLUDED.last_seen_at)',
        [Digest::SHA256.hexdigest(identity), now.iso8601(6)])
    end
  end

  def self.snapshot(now: Time.now.utc)
    return { available: false, status: 'disabled' } unless ENV['ENABLE_VISITOR_METRICS'] == 'true'
    started = DB.get_first_value('SELECT started_at FROM browser_visitor_collection WHERE id = 1')
    counts = WINDOWS.to_h do |label, duration|
      [label, DB.get_first_value('SELECT COUNT(*) FROM browser_visitors WHERE last_seen_at >= ? AND last_seen_at <= ?',
        [(now - duration).iso8601(6), now.iso8601(6)]).to_i]
    end
    { available: true, counts: counts, collected_since: started, generated_at: now.iso8601,
      partial_windows: WINDOWS.keys.select { |label| !started || Time.parse(started.to_s) > now - WINDOWS[label] } }
  rescue StandardError
    { available: false, status: 'unavailable' }
  end
end