# frozen_string_literal: true
# Rakefile — Meme Explorer database tasks
require 'dotenv/load'
require 'pg'

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

    pending = migration_files.reject { |f| applied.include?(File.basename(f, '.sql')) }

    if pending.empty?
      puts "✅ All #{migration_files.size} migrations already applied."
      next
    end

    puts "Applying #{pending.size} pending migration(s)..."
    pending.each do |file|
      version = File.basename(file, '.sql')
      print "  → #{version} ... "
      begin
        sql = File.read(file)
        conn.exec(sql)
        conn.exec_params(
          "INSERT INTO schema_migrations (version) VALUES ($1)",
          [version]
        )
        puts "✅"
      rescue PG::Error => e
        puts "❌ FAILED"
        abort "Migration #{version} failed: #{e.message}"
      end
    end

    puts "✅ Done. #{pending.size} migration(s) applied."
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
    puts "-" * 60
    files.each do |f|
      version = File.basename(f, '.sql')
      status  = applied.include?(version) ? "✅ applied" : "⬜ pending"
      puts "  #{status}  #{version}"
    end
    puts "-" * 60
    puts "  #{applied.size} applied, #{files.size - applied.size} pending"
  ensure
    conn&.close
  end

  desc "Rollback is not supported — use a new forward migration instead"
  task :rollback do
    abort "❌ Rollback not supported. Write a new forward migration in db/migrations/."
  end
end

desc "Alias: run db:migrate"
task migrate: 'db:migrate'
