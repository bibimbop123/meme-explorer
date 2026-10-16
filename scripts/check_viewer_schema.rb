# frozen_string_literal: true
require 'pg'

abort 'Usage: bundle exec ruby scripts/check_viewer_schema.rb [--apply]' unless ARGV.empty? || ARGV == ['--apply']
url = ENV['DATABASE_URL'] || ENV['POSTGRES_URL']
abort 'DATABASE_URL or POSTGRES_URL must be explicitly configured.' if url.to_s.empty?
connection = nil
begin
  connection = PG.connect(url)
  if ARGV == ['--apply']
    root = File.expand_path('..', __dir__)
    connection.transaction do |db|
      db.exec("SET LOCAL lock_timeout = '5s'")
      db.exec("SET LOCAL statement_timeout = '30s'")
      %w[add_meme_catalog.sql add_meme_impressions.sql].each do |file|
        db.exec(File.read(File.join(root, 'db/migrations', file)))
      end
    end
    puts 'Viewer migrations applied. No existing catalog snapshots rewritten.'
  end
  missing = []
  %w[meme_catalog meme_impressions meme_activity_log].each do |table|
    found = connection.exec_params('SELECT to_regclass($1)::text AS relation', [table]).first['relation']
    puts "#{table}: #{found ? 'present' : 'MISSING'}"
    missing << table unless found
  end
  exit(missing.empty? ? 0 : 2)
rescue PG::Error => e
  warn "Viewer schema command failed (#{e.class}). Check database, search path and privileges; credentials are not printed."
  exit 1
ensure
  connection&.close
end