# frozen_string_literal: true

# Filename-only guard. Never opens sensitive files or prints their contents.
require 'open3'

module TrackedArtifactPolicy
  def self.forbidden?(path)
    basename = File.basename(path)
    environment = basename == '.env' || (basename.start_with?('.env.') && basename != '.env.example')
    database = basename.match?(/\.(?:db|sqlite|sqlite3)(?:-(?:wal|shm|journal))?\z/i) || basename == 'dump.rdb'
    secret = %w[.session_secret secrets.yml id_rsa id_ed25519].include?(basename) || basename.end_with?('.key', '.p12', '.pfx')
    environment || database || secret
  end
end

if $PROGRAM_NAME == __FILE__
  root = File.expand_path('..', __dir__)
  output, status = Open3.capture2('git', '-C', root, 'ls-files', '-z')
  abort 'Unable to inspect tracked file names.' unless status.success?
  count = output.split("\0").count { |path| TrackedArtifactPolicy.forbidden?(path) }
  abort "Tracked private-artifact guard failed: #{count} prohibited file(s). Review filenames locally; contents omitted." if count.positive?
  puts 'PASS: no prohibited private artifact filenames tracked (not a secret-content/history scan).'
end