# frozen_string_literal: true
# Rakefile — Meme Explorer database tasks
require 'dotenv/load'
require 'pg'

# SQLite-only migration files — skip when running against PostgreSQL
SQLITE_ONLY_MIGRATIONS = %w[
  add_meme_activity_log_sqlite
  add_push_subscriptions_sqlite
].freeze

namespace :db do
  desc "Run all pending migrations in db/migrations/ (sorted by filename)"
  task :migrate do
    conn = PG.connect(ENV.fetch('DATABASE_URL') { abort "DATABASE_URL not set" })

    # Create version tracking table
    conn.exec(<<~SQL)
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version     VARCHAR(255) PRIMARY KEY,
        applied_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      )
    SQL

    applied = conn.exec("SELECT version FROM schema_migrations ORDER BY version")
                  .map { |r| r['version'] }

    migration_files = Dir['db/migrations/*.sql'].sort

    if migration_files.empty?
      puts "No migration files found in db/migrations/"
      next
    end

    pending = migration_files.reject do |f|
      version = File.basename(f, '.sql')
      applied.include?(version) || SQLITE_ONLY_MIGRATIONS.include?(version)
    end

    if pending.empty?
      puts "All migrations already applied (or skipped)."
      next
    end

    puts "Applying #{pending.size} pending migration(s)..."
    applied_count  = 0
    skipped_count  = 0
    failed         = []

    pending.each do |file|
      version = File.basename(file, '.sql')
      print "  -> #{version} ... "
      begin
        sql = File.read(file)

        # Run each migration in a savepoint so one failure does not
        # poison the connection for subsequent migrations.
        conn.exec('BEGIN')
        conn.exec(sql)
        conn.exec_params(
          "INSERT INTO schema_migrations (version) VALUES ($1)",
          [version]
        )
        conn.exec('COMMIT')
        puts 'OK'
        applied_count += 1
      rescue PG::Error => e
        conn.exec('ROLLBACK') rescue nil
        short = e.message.lines.first.strip
        puts "FAILED: #{short}"
        failed << { version: version, error: e.message }
      end
    end

    puts
    puts "Results: #{applied_count} applied, #{skipped_count} skipped, #{failed.size} failed"

    if failed.any?
      puts
      puts "Failed migrations:"
      failed.each { |f| puts "  #{f[:version]}: #{f[:error].lines.first.strip}" }
      exit 1
    else
      puts "All migrations applied successfully."
    end
  ensure
    conn&.close
  end

  desc "Show applied and pending migration status"
  task :status do
    conn = PG.connect(ENV.fetch('DATABASE_URL') { abort "DATABASE_URL not set" })

    applied = begin
      conn.exec("SELECT version FROM schema_migrations ORDER BY version")
          .map { |r| r['version'] }
    rescue PG::UndefinedTable
      []
    end

    files = Dir['db/migrations/*.sql'].sort

    if files.empty?
      puts "No migration files found in db/migrations/"
      next
    end

    puts "\nMigration Status:"
    puts "-" * 65
    files.each do |f|
      version = File.basename(f, '.sql')
      if SQLITE_ONLY_MIGRATIONS.include?(version)
        status = "-- skipped (SQLite only)"
      elsif applied.include?(version)
        status = "OK applied"
      else
        status = ".. pending"
      end
      puts "  #{status.ljust(24)}  #{version}"
    end
    puts "-" * 65
    non_sqlite = files.reject { |f| SQLITE_ONLY_MIGRATIONS.include?(File.basename(f, '.sql')) }
    puts "  #{applied.size} applied, #{non_sqlite.size - applied.size} pending, #{SQLITE_ONLY_MIGRATIONS.size} skipped"
  ensure
    conn&.close
  end

  desc "Rollback is not supported — use a new forward migration instead"
  task :rollback do
    abort "Rollback not supported. Write a new forward migration in db/migrations/."
  end
end

desc "Alias: run db:migrate"
task migrate: 'db:migrate'
