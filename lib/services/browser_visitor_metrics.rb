# frozen_string_literal: true
require 'digest'
require 'time'

# Last observation only; no IP, URL, user-agent or account linkage stored here.
class BrowserVisitorMetrics
  WINDOWS = { '24h' => 86_400, '7d' => 604_800, '30d' => 2_592_000 }.freeze

  def self.enabled?
    ENV['ENABLE_VISITOR_METRICS'] != 'false'
  end

  def self.ensure_schema!
    return if @schema_ready
    DB_POOL.with do |conn|
      conn.exec(<<~SQL)
        CREATE TABLE IF NOT EXISTS browser_visitor_collection (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS browser_visitors (
          visitor_key VARCHAR(64) PRIMARY KEY,
          last_seen_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
          revoked_at TIMESTAMPTZ
        );
        ALTER TABLE browser_visitors ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
        ALTER TABLE browser_visitors ALTER COLUMN last_seen_at DROP NOT NULL;
        CREATE INDEX IF NOT EXISTS browser_visitors_last_seen ON browser_visitors(last_seen_at);
      SQL
    end
    @schema_ready = true
  rescue StandardError
    false
  end

  def self.record(identity, now: Time.now.utc)
    raise ArgumentError unless identity.is_a?(String) && identity.match?(/\A[a-f0-9]{64}\z/)
    recorded = false
    DB.transaction do
      DB.execute('INSERT INTO browser_visitor_collection (id, started_at) VALUES (1, ?) ON CONFLICT DO NOTHING', [now.iso8601(6)])
      rows = DB.execute('INSERT INTO browser_visitors (visitor_key, last_seen_at) VALUES (?, ?) ON CONFLICT(visitor_key) DO UPDATE SET last_seen_at = GREATEST(browser_visitors.last_seen_at, EXCLUDED.last_seen_at) WHERE browser_visitors.revoked_at IS NULL RETURNING visitor_key',
        [Digest::SHA256.hexdigest(identity), now.iso8601(6)])
      recorded = !rows.empty?
    end
    recorded
  end

  def self.withdraw(identity, now: Time.now.utc)
    raise ArgumentError unless identity.is_a?(String) && identity.match?(/\A[a-f0-9]{64}\z/)
    DB.execute('INSERT INTO browser_visitors (visitor_key, last_seen_at, revoked_at) VALUES (?, NULL, ?) ON CONFLICT(visitor_key) DO UPDATE SET last_seen_at = NULL, revoked_at = COALESCE(browser_visitors.revoked_at, EXCLUDED.revoked_at)',
      [Digest::SHA256.hexdigest(identity), now.iso8601(6)])
  end

  def self.snapshot(now: Time.now.utc)
    return { available: false, status: 'disabled' } unless enabled?
    # One statement gives all cards and coverage metadata the same MVCC snapshot.
    row = DB.execute(<<~SQL, [(now - WINDOWS['24h']).iso8601(6), (now - WINDOWS['7d']).iso8601(6), (now - WINDOWS['30d']).iso8601(6), now.iso8601(6)]).first
      SELECT COUNT(*) FILTER (WHERE last_seen_at >= ?) AS visitors_24h,
        COUNT(*) FILTER (WHERE last_seen_at >= ?) AS visitors_7d,
        COUNT(*) AS visitors_30d,
        (SELECT started_at FROM browser_visitor_collection WHERE id = 1) AS started_at
      FROM browser_visitors
      WHERE revoked_at IS NULL AND last_seen_at >= ? AND last_seen_at <= ?
    SQL
    started = row['started_at']
    counts = WINDOWS.keys.to_h { |label| [label, row.fetch("visitors_#{label}").to_i] }
    { available: true, counts: counts, collected_since: started, generated_at: now.iso8601,
      partial_windows: WINDOWS.keys.select { |label| !started || Time.parse(started.to_s) > now - WINDOWS[label] } }
  rescue StandardError
    { available: false, status: 'unavailable' }
  end

  ensure_schema! if defined?(DB_POOL)
end