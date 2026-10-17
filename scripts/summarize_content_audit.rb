# frozen_string_literal: true

require 'json'

# Offline human-observation summary. Never fetches content or loads the app.
class ContentAuditSummary
  MAX_BYTES = 262_144
  MAX_ROWS = 1000
  FIELDS = %w[id session device visible available readable repeated_url repeated_artwork source_age].freeze
  FLAGS = %w[yes no unknown].freeze

  def self.summarize(rows)
    raise ArgumentError unless rows.is_a?(Array) && rows.size <= MAX_ROWS
    ids = []
    rows.each do |row|
      raise ArgumentError unless row.is_a?(Hash) && row.keys.all? { |key| key.is_a?(String) } && row.keys.sort == FIELDS.sort
      raise ArgumentError unless row['id'].is_a?(Integer) && row['id'].positive?
      ids << row['id']
      raise ArgumentError unless %w[guest returning].include?(row['session']) && %w[mobile desktop].include?(row['device'])
      raise ArgumentError unless %w[yes no].include?(row['visible'])
      raise ArgumentError unless %w[available readable repeated_url repeated_artwork].all? { |key| FLAGS.include?(row[key]) }
      raise ArgumentError unless %w[under_day one_to_seven_days over_seven_days unknown].include?(row['source_age'])
      if row['visible'] == 'no'
        raise ArgumentError unless %w[available readable repeated_url repeated_artwork source_age].all? { |key| row[key] == 'unknown' }
      end
    end
    raise ArgumentError unless ids.uniq.size == ids.size
    visible = rows.select { |row| row['visible'] == 'yes' }
    mobile = visible.select { |row| row['device'] == 'mobile' }
    metrics = {}
    %w[available readable repeated_url repeated_artwork].each do |key|
      metrics[key] = tally(visible, key)
    end
    metrics['mobile_readable'] = tally(mobile, 'readable')
    {
      rows: rows.size, visible: visible.size, not_visible: rows.size - visible.size,
      target_visible: 100, target_met: visible.size >= 100,
      metrics: metrics,
      source_age: %w[under_day one_to_seven_days over_seven_days unknown].to_h { |age| [age, visible.count { |r| r['source_age'] == age }] },
      sample_mix: %w[guest returning].to_h { |kind| [kind, visible.count { |r| r['session'] == kind }] },
      device_mix: %w[mobile desktop].to_h { |kind| [kind, visible.count { |r| r['device'] == kind }] },
      note: 'Human audit aggregates, not representative population estimates. Unknowns remain in visible denominators. No humor, artwork detection or media health is inferred.'
    }
  end

  def self.tally(rows, key)
    counts = FLAGS.to_h { |flag| [flag, rows.count { |row| row[key] == flag }] }
    counts.merge('denominator' => rows.size, 'yes_percent' => rows.empty? ? nil : (100.0 * counts['yes'] / rows.size).round(2))
  end
  private_class_method :tally
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError unless ARGV.size == 1
    raw = File.open(ARGV.first, 'rb') { |file| file.read(ContentAuditSummary::MAX_BYTES + 1) }
    raise ArgumentError if raw.bytesize > ContentAuditSummary::MAX_BYTES
    puts JSON.pretty_generate(ContentAuditSummary.summarize(JSON.parse(raw, max_nesting: 4)))
  rescue StandardError
    warn 'Audit summary failed: supply one bounded JSON audit file with valid fields. Input values and paths omitted.'
    exit 1
  end
end