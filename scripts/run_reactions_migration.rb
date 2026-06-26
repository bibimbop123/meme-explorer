#!/usr/bin/env ruby
# frozen_string_literal: true

# Reactions System Migration Script
# Safe migration that checks existing schema

require 'sequel'
require 'fileutils'

class ReactionsMigration
  def initialize
    @db_path = 'data/meme_explorer.db'
    @backup_path = "data/backups/meme_explorer_pre_reactions_#{Time.now.strftime('%Y%m%d_%H%M%S')}.db"
  end
  
  def run
    puts "🚀 Reactions System Migration"
    puts "=" * 60
    puts
    
    unless File.exist?(@db_path)
      puts "❌ Database not found: #{@db_path}"
      puts "Creating new database..."
      # Database will be created on connection
    end
    
    # Backup database
    backup_database
    
    # Connect to database
    @db = Sequel.sqlite(@db_path)
    
    # Run migrations
    create_reactions_table
    add_reaction_columns_to_memes
    
    puts
    puts "=" * 60
    puts "✅ Reactions System Migration Complete!"
    puts "=" * 60
    puts
    puts "📊 Next Steps:"
    puts "  1. Test reactions in the UI"
    puts "  2. Monitor reaction counts"
    puts "  3. Deploy to production"
    puts
    puts "📁 Backup: #{@backup_path}" if File.exist?(@backup_path)
  end
  
  private
  
  def backup_database
    if File.exist?(@db_path)
      puts "📦 Backing up database..."
      FileUtils.mkdir_p(File.dirname(@backup_path))
      FileUtils.cp(@db_path, @backup_path)
      puts "✅ Backup created: #{@backup_path}\n\n"
    end
  end
  
  def create_reactions_table
    puts "🔨 Creating meme_reactions table..."
    
    @db.create_table? :meme_reactions do
      primary_key :id
      Integer :meme_id, null: false
      Integer :user_id, null: false
      String :reaction_type, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      
      index [:meme_id]
      index [:user_id]
      index [:reaction_type]
      index [:created_at]
      index [:meme_id, :user_id, :reaction_type], unique: true
    end
    
    puts "✅ meme_reactions table ready"
  end
  
  def add_reaction_columns_to_memes
    puts "🔨 Adding reaction columns to memes table..."
    
    # Check if memes table exists
    unless @db.table_exists?(:memes)
      puts "⚠️  memes table doesn't exist yet - skipping column additions"
      puts "   (Columns will be added when memes table is created)"
      return
    end
    
    # Get existing columns
    existing_columns = @db.schema(:memes).map { |col| col[0] }
    
    # Add reaction columns if they don't exist
    reaction_columns = %i[reaction_laugh reaction_wow reaction_cry reaction_fire reaction_dead]
    
    reaction_columns.each do |column|
      if existing_columns.include?(column)
        puts "  ✓ #{column} already exists"
      else
        @db.alter_table :memes do
          add_column column, Integer, default: 0
        end
        puts "  ✓ Added #{column}"
      end
    end
    
    puts "✅ Reaction columns ready"
  end
end

# Run migration
ReactionsMigration.new.run
