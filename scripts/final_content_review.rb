#!/usr/bin/env ruby
# Final Content Review Script for AdSense Submission
# Run this to validate all guides are ready for submission

require 'pathname'

class ContentReviewValidator
  REQUIRED_GUIDES = %w[
    getting_started
    quality_system
    collections
    gamification
    personalization
    meme_formats
    best_practices
    community
    discovery
    faq
    guides_index
  ]

  MIN_WORD_COUNTS = {
    'getting_started' => 1500,
    'quality_system' => 1500,
    'collections' => 1500,
    'gamification' => 1500,
    'personalization' => 1500,
    'meme_formats' => 1500,
    'best_practices' => 1500,
    'community' => 1500,
    'discovery' => 1500,
    'faq' => 1500,
    'guides_index' => 1500
  }

  def initialize
    @base_path = Pathname.new(__dir__).parent
    @guides_path = @base_path.join('views', 'guides')
    @issues = []
    @warnings = []
    @stats = {}
  end

  def run
    puts "=" * 70
    puts "MEME EXPLORER - FINAL CONTENT REVIEW FOR ADSENSE"
    puts "=" * 70
    puts ""

    check_all_guides_exist
    check_word_counts
    check_meta_information
    check_internal_links
    check_styling_consistency
    check_mobile_responsive_hints
    
    print_summary
    generate_report
  end

  private

  def check_all_guides_exist
    puts "📋 Checking Guide Files..."
    
    REQUIRED_GUIDES.each do |guide|
      file_path = @guides_path.join("#{guide}.erb")
      
      if file_path.exist?
        puts "  ✅ #{guide}.erb found"
        @stats[guide] = { exists: true, path: file_path }
      else
        @issues << "❌ CRITICAL: #{guide}.erb is missing!"
        @stats[guide] = { exists: false }
      end
    end
    
    puts ""
  end

  def check_word_counts
    puts "📝 Checking Word Counts..."
    
    total_words = 0
    
    REQUIRED_GUIDES.each do |guide|
      next unless @stats[guide][:exists]
      
      file_path = @stats[guide][:path]
      content = File.read(file_path)
      
      # Remove HTML tags and count words
      text = content.gsub(/<[^>]*>/, ' ')
      word_count = text.split.length
      
      @stats[guide][:word_count] = word_count
      total_words += word_count
      
      min_required = MIN_WORD_COUNTS[guide]
      
      if word_count >= min_required
        puts "  ✅ #{guide}: #{word_count} words (min: #{min_required})"
      elsif word_count >= (min_required * 0.9)
        @warnings << "⚠️  #{guide}: #{word_count} words (slightly below #{min_required})"
        puts "  ⚠️  #{guide}: #{word_count} words (target: #{min_required})"
      else
        @issues << "❌ #{guide}: Only #{word_count} words (need #{min_required})"
        puts "  ❌ #{guide}: #{word_count} words (BELOW minimum #{min_required})"
      end
    end
    
    @stats[:total_words] = total_words
    puts ""
    puts "  📊 TOTAL CONTENT: #{total_words} words"
    puts ""
  end

  def check_meta_information
    puts "🏷️  Checking Meta Information..."
    
    required_meta = ['Last Updated', 'Reading Time', 'By:']
    
    REQUIRED_GUIDES.each do |guide|
      next unless @stats[guide][:exists]
      
      content = File.read(@stats[guide][:path])
      
      missing_meta = required_meta.reject { |meta| content.include?(meta) }
      
      if missing_meta.empty?
        puts "  ✅ #{guide}: All meta tags present"
      else
        @warnings << "⚠️  #{guide}: Missing meta - #{missing_meta.join(', ')}"
        puts "  ⚠️  #{guide}: Missing #{missing_meta.join(', ')}"
      end
    end
    
    puts ""
  end

  def check_internal_links
    puts "🔗 Checking Internal Links..."
    
    link_count = 0
    
    REQUIRED_GUIDES.each do |guide|
      next unless @stats[guide][:exists]
      
      content = File.read(@stats[guide][:path])
      
      # Count internal guide links
      internal_links = content.scan(/href=["']\/guides\/\w+["']/).length
      link_count += internal_links
      
      if internal_links >= 2
        puts "  ✅ #{guide}: #{internal_links} internal links"
      elsif internal_links == 1
        @warnings << "⚠️  #{guide}: Only 1 internal link (recommend 2-3)"
        puts "  ⚠️  #{guide}: #{internal_links} internal link (add more)"
      else
        @warnings << "⚠️  #{guide}: No internal links found"
        puts "  ⚠️  #{guide}: No internal links"
      end
    end
    
    puts ""
    puts "  📊 TOTAL INTERNAL LINKS: #{link_count}"
    puts ""
  end

  def check_styling_consistency
    puts "🎨 Checking Styling Consistency..."
    
    required_classes = ['.legal-page', '.guide-page', 'hero-section']
    
    REQUIRED_GUIDES.each do |guide|
      next unless @stats[guide][:exists]
      
      content = File.read(@stats[guide][:path])
      
      has_styling = required_classes.any? { |css_class| content.include?(css_class) }
      
      if has_styling
        puts "  ✅ #{guide}: Professional styling present"
      else
        @warnings << "⚠️  #{guide}: May need styling review"
        puts "  ⚠️  #{guide}: Check styling"
      end
    end
    
    puts ""
  end

  def check_mobile_responsive_hints
    puts "📱 Mobile Responsiveness Checks..."
    puts "  ℹ️  Manual testing required:"
    puts "     1. Test each guide on mobile device"
    puts "     2. Verify images scale properly"
    puts "     3. Check navigation works"
    puts "     4. Verify no horizontal scrolling"
    puts ""
  end

  def print_summary
    puts "=" * 70
    puts "REVIEW SUMMARY"
    puts "=" * 70
    puts ""
    
    if @issues.empty? && @warnings.empty?
      puts "🎉 EXCELLENT! All guides pass review!"
      puts ""
      puts "✅ All 11 guides present"
      puts "✅ Total words: #{@stats[:total_words]}"
      puts "✅ All meta information complete"
      puts "✅ Internal linking present"
      puts "✅ Professional styling applied"
      puts ""
      puts "🚀 READY FOR ADSENSE SUBMISSION!"
    else
      if @issues.any?
        puts "❌ CRITICAL ISSUES (#{@issues.length}):"
        @issues.each { |issue| puts "   #{issue}" }
        puts ""
      end
      
      if @warnings.any?
        puts "⚠️  WARNINGS (#{@warnings.length}):"
        @warnings.each { |warning| puts "   #{warning}" }
        puts ""
      end
      
      if @issues.empty?
        puts "✅ No critical issues - can proceed with warnings"
        puts "🟡 REVIEW WARNINGS BEFORE SUBMISSION"
      else
        puts "❌ FIX CRITICAL ISSUES BEFORE SUBMISSION"
      end
    end
    
    puts ""
    puts "=" * 70
  end

  def generate_report
    report_path = @base_path.join('FINAL_CONTENT_REVIEW_REPORT.md')
    
    File.open(report_path, 'w') do |f|
      f.puts "# Final Content Review Report"
      f.puts ""
      f.puts "**Date**: #{Time.now.strftime('%B %d, %Y at %I:%M %p')}"
      f.puts "**Total Words**: #{@stats[:total_words]}"
      f.puts "**Guides Reviewed**: #{REQUIRED_GUIDES.length}"
      f.puts ""
      
      f.puts "## Guide Inventory"
      f.puts ""
      REQUIRED_GUIDES.each do |guide|
        status = @stats[guide][:exists] ? "✅" : "❌"
        words = @stats[guide][:word_count] || 0
        f.puts "- #{status} **#{guide}.erb**: #{words} words"
      end
      f.puts ""
      
      f.puts "## Issues Found"
      f.puts ""
      if @issues.empty?
        f.puts "✅ No critical issues"
      else
        @issues.each { |issue| f.puts "- #{issue}" }
      end
      f.puts ""
      
      f.puts "## Warnings"
      f.puts ""
      if @warnings.empty?
        f.puts "✅ No warnings"
      else
        @warnings.each { |warning| f.puts "- #{warning}" }
      end
      f.puts ""
      
      f.puts "## Next Steps"
      f.puts ""
      if @issues.empty?
        f.puts "1. ✅ Review this report"
        f.puts "2. 📱 Test guides on mobile devices"
        f.puts "3. 🔍 Manual proofreading"
        f.puts "4. 🗺️ Update sitemap (run sitemap generator)"
        f.puts "5. 🌐 Submit to Google Search Console"
        f.puts "6. ⏳ Wait 1-2 weeks for indexing"
        f.puts "7. 💰 Apply to AdSense"
      else
        f.puts "1. ❌ Fix critical issues listed above"
        f.puts "2. 🔄 Run this script again"
        f.puts "3. ✅ Proceed when all issues resolved"
      end
    end
    
    puts "📄 Full report saved to: FINAL_CONTENT_REVIEW_REPORT.md"
    puts ""
  end
end

# Run the validator
validator = ContentReviewValidator.new
validator.run
