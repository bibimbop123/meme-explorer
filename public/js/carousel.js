# Migration: Add meme_images table for multi-image gallery support

require "fileutils"
require "sqlite3"

def migrate_add_meme_images_table
  puts "🔄 [MIGRATION] Starting: Add meme_images table for gallery support..."
  
  begin
    db = SQLite3::Database.new("db/memes.db")
    db.results_as_hash = true
    
    # Create meme_images table
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS meme_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meme_url TEXT NOT NULL,
        image_index INTEGER NOT NULL DEFAULT 0,
        image_url TEXT NOT NULL,
        image_type TEXT DEFAULT 'image',
        width INTEGER,
        height INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(meme_url, image_index),
        FOREIGN KEY (meme_url) REFERENCES meme_stats(url)
      );
    SQL
    puts "✅ [MIGRATION] Created meme_images table"
    
    # Add columns to meme_stats if they don't exist
    columns = db.execute("PRAGMA table_info(meme_stats)")
    column_names = columns.map { |c| c["name"] }
    
    unless column_names.include?("image_count")
      db.execute("ALTER TABLE meme_stats ADD COLUMN image_count INTEGER DEFAULT 1")
      puts "✅ [MIGRATION] Added image_count column to meme_stats"
    else
      puts "ℹ️  [MIGRATION] image_count column already exists"
    end
    
    unless column_names.include?("is_gallery")
      db.execute("ALTER TABLE meme_stats ADD COLUMN is_gallery BOOLEAN DEFAULT 0")
      puts "✅ [MIGRATION] Added is_gallery column to meme_stats"
    else
      puts "ℹ️  [MIGRATION] is_gallery column already exists"
    end
    
    unless column_names.include?("primary_image_url")
      db.execute("ALTER TABLE meme_stats ADD COLUMN primary_image_url TEXT")
      puts "✅ [MIGRATION] Added primary_image_url column to meme_stats"
    else
      puts "ℹ️  [MIGRATION] primary_image_url column already exists"
    end
    
    # Create indexes
    db.execute("CREATE INDEX IF NOT EXISTS idx_meme_images_meme_url ON meme_images(meme_url)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_meme_images_composite ON meme_images(meme_url, image_index)")
    puts "✅ [MIGRATION] Created indexes for meme_images table"
    
    # Backfill existing memes
    existing_memes = db.execute("SELECT url FROM meme_stats WHERE primary_image_url IS NULL")
    existing_memes.each do |row|
      db.execute("UPDATE meme_stats SET primary_image_url = url WHERE url = ?", [row["url"]])
    end
    puts "✅ [MIGRATION] Backfilled primary_image_url for #{existing_memes.size} existing memes"
    
    puts "✅ [MIGRATION] Migration completed successfully!"
    
  rescue SQLite3::SQLException => e
    puts "❌ [MIGRATION] Database error: #{e.message}"
    raise
  rescue => e
    puts "❌ [MIGRATION] Unexpected error: #{e.class} - #{e.message}"
    raise
  end
end

# Run migration if called directly
migrate_add_meme_images_table if __FILE__ == $0
