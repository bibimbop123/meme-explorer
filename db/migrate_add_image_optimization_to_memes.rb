# Database Migration: Add image optimization fields to memes table
# Phase 2: Image Optimization Pipeline

class AddImageOptimizationToMemes
  def self.up
    # Add optimized image URLs
    execute <<-SQL
      ALTER TABLE memes ADD COLUMN image_urls JSONB DEFAULT '{}'::jsonb;
    SQL

    # Add optimization metadata (compression ratio, sizes, formats, etc.)
    execute <<-SQL
      ALTER TABLE memes ADD COLUMN image_metadata JSONB DEFAULT '{}'::jsonb;
    SQL

    # Add index for efficient querying
    execute <<-SQL
      CREATE INDEX idx_memes_image_urls ON memes USING gin(image_urls);
    SQL

    # Add optimization status tracking
    execute <<-SQL
      ALTER TABLE memes ADD COLUMN optimization_status VARCHAR(50) DEFAULT 'pending';
    SQL

    # Track when optimization completed
    execute <<-SQL
      ALTER TABLE memes ADD COLUMN optimized_at TIMESTAMP;
    SQL

    puts "✅ Image optimization columns added to memes table"
  end

  def self.down
    # Rollback
    execute "DROP INDEX IF EXISTS idx_memes_image_urls"
    execute "ALTER TABLE memes DROP COLUMN IF EXISTS image_urls"
    execute "ALTER TABLE memes DROP COLUMN IF EXISTS image_metadata"
    execute "ALTER TABLE memes DROP COLUMN IF EXISTS optimization_status"
    execute "ALTER TABLE memes DROP COLUMN IF EXISTS optimized_at"
    
    puts "✅ Image optimization columns removed from memes table"
  end

  private

  def self.execute(sql)
    if defined?(Sequel)
      # Sequel.js or similar
      DB.run(sql)
    elsif defined?(ActiveRecord)
      # ActiveRecord Rails
      ActiveRecord::Base.connection.execute(sql)
    else
      # Raw connection or Sinatra with PG
      conn = PG.connect(
        host: ENV['DB_HOST'] || 'localhost',
        user: ENV['DB_USER'] || 'postgres',
        password: ENV['DB_PASSWORD'],
        database: ENV['DATABASE_URL']&.split('/')&.last || 'meme_explorer'
      )
      conn.exec(sql)
      conn.close
    end
  end
end

# Usage: ruby db/migrate_add_image_optimization_to_memes.rb
if __FILE__ == $0
  AddImageOptimizationToMemes.up
end
