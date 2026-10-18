# frozen_string_literal: true
require_relative '../scripts/check_tracked_artifacts'

%w[.env .env.production config/.env.staging meme_explorer.db db/local.sqlite3
   db/local.sqlite-wal db/local.db-shm dump.rdb .session_secret config/secrets.yml
   keys/id_rsa keys/id_ed25519 config/server.key cert.p12 cert.pfx].each do |path|
  raise "Private artifact allowed: #{path}" unless TrackedArtifactPolicy.forbidden?(path)
end
%w[.env.example docs/environment.md db/postgres_schema.sql Gemfile.lock
   tests/frontend/example.test.mjs public/images/example.png].each do |path|
  raise "Safe source rejected: #{path}" if TrackedArtifactPolicy.forbidden?(path)
end
puts 'PASS: tracked-artifact filename policy positive/negative cases.'