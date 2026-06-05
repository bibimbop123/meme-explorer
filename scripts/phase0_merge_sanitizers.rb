#!/usr/bin/env ruby
# frozen_string_literal: true

# PHASE 0 - Task 1.2: Merge Duplicate Sanitization Modules
# Migrates InputSanitizer to Validators (more comprehensive)
# Generated: June 4, 2026

require 'fileutils'

class SanitizerMerger
  def self.execute!
    puts "=" * 80
    puts "PHASE 0 - Task 1.2: Merging Duplicate Sanitization Modules"
    puts "=" * 80
    puts

    merger = new
    merger.backup_files
    merger.update_app_rb
    merger.verify_changes
    
    puts
    puts "✅ Migration complete! Next steps:"
    puts "   1. Run tests: bundle exec rspec"
    puts "   2. If tests pass, delete lib/input_sanitizer.rb"
    puts "   3. Update ARCHITECTURE.md"
  end
  
  def backup_files
    puts "📦 Creating backup..."
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    backup_dir = "backups/sanitizer_merge_#{timestamp}"
    FileUtils.mkdir_p(backup_dir)
    
    FileUtils.cp("app.rb", "#{backup_dir}/app.rb.backup")
    FileUtils.cp("lib/input_sanitizer.rb", "#{backup_dir}/input_sanitizer.rb.backup") if File.exist?("lib/input_sanitizer.rb")
    
    puts "   ✓ Backed up to #{backup_dir}"
    puts
  end
  
  def update_app_rb
    puts "🔧 Updating app.rb..."
    
    content = File.read("app.rb")
    original_content = content.dup
    
    # Replace InputSanitizer.sanitize_search_query with Validators.validate_search_query
    # But handle exceptions since Validators raises, InputSanitizer returns strings
    changes_made = 0
    
    # Pattern 1: The actual usage in search_memes method
    if content.include?('sanitized_query = InputSanitizer.sanitize_search_query(query)')
      content.gsub!(
        /(\s+)# SECURITY FIX: Use InputSanitizer to prevent SQL injection\s+sanitized_query = InputSanitizer\.sanitize_search_query\(query\)\s+return \[\] if sanitized_query\.empty\?/m,
        <<~RUBY.chomp
\\1# SECURITY FIX: Use Validators to prevent SQL injection
\\1begin
\\1  sanitized_query = Validators.validate_search_query(query, min_length: 1, max_length: 200)
\\1rescue Validators::ValidationError => e
\\1  AppLogger.warn("Invalid search query", query: query, error: e.message)
\\1  return []
\\1end
        RUBY
      )
      changes_made += 1
      puts "   ✓ Updated search_memes method"
    end
    
    if content != original_content
      File.write("app.rb", content)
      puts "   ✓ Wrote #{changes_made} change(s) to app.rb"
    else
      puts "   ⚠️  No changes needed in app.rb"
    end
    
    puts
  end
  
  def verify_changes
    puts "🔍 Verifying changes..."
    
    content = File.read("app.rb")
    
    if content.include?('InputSanitizer')
      puts "   ⚠️  WARNING: InputSanitizer still referenced in app.rb"
      puts "   Check manually for remaining references"
    else
      puts "   ✓ No InputSanitizer references in app.rb"
    end
    
    if content.include?('Validators.validate_search_query')
      puts "   ✓ Using Validators.validate_search_query"
    else
      puts "   ❌ ERROR: Validators.validate_search_query not found!"
    end
    
    puts
  end
end

# Execute if run directly
if __FILE__ == $PROGRAM_NAME
  SanitizerMerger.execute!
end
