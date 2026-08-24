#!/usr/bin/env ruby
# frozen_string_literal: true

# ELON MUSK WEEK 3: GET TO 72/100
# Phase 1: Security + Speed + Services
# Target: 65/100 → 72/100 (+7 points)

require 'fileutils'
require 'json'

class ElonWeek3To72
  def initialize(dry_run: false)
    @dry_run = dry_run
    @issues_found = []
    @services_to_remove = []
    @optimizations = []
  end

  def execute
    print_header
    
    # Phase 1: Security Audit (Days 1-2) → +3 points
    audit_security
    
    # Phase 2: Speed Analysis (Days 3-5) → +4 points
    audit_speed
    
    # Phase 3: Service Reduction (Days 6-7) → +3 points
    audit_services
    
    print_summary
    print_action_plan
  end

  private

  def print_header
    puts "=" * 80
    puts "🎯 ELON MUSK WEEK 3: GET TO 72/100 🎯"
    puts "=" * 80
    puts
    puts "Current Rating: 65/100"
    puts "Target Rating:  72/100 (+7 points)"
    puts
    puts "Mode: #{@dry_run ? 'DIAGNOSTIC' : 'DIAGNOSTIC'} (analysis only)"
    puts
    puts "Phase 1: Security (Days 1-2) → +3 points"
    puts "Phase 2: Speed (Days 3-5) → +4 points"
    puts "Phase 3: Services (Days 6-7) → +3 points"
    puts
    puts "=" * 80
    puts
  end

  def audit_security
    puts "🔒 PHASE 1: SECURITY AUDIT (Days 1-2) → +3 points"
    puts
    
    # Check CSRF protection
    csrf_file = 'lib/concerns/csrf_protection.rb'
    if File.exist?(csrf_file)
      content = File.read(csrf_file)
      
      puts "  1. CSRF Protection (lib/concerns/csrf_protection.rb)"
      
      if content.include?('verify_authenticity_token') || content.include?('csrf_token')
        puts "     ✓ CSRF concern exists"
        
        # Check for common vulnerabilities
        if !content.include?('session') || !content.include?('token')
          @issues_found << {
            severity: 'CRITICAL',
            category: 'Security',
            file: csrf_file,
            issue: 'CSRF protection may not be validating tokens correctly',
            fix: 'Add session-based token generation and validation'
          }
          puts "     ❌ CRITICAL: Token validation may be incomplete"
        else
          puts "     ⚠️  REVIEW NEEDED: Manual verification required"
        end
      else
        @issues_found << {
          severity: 'CRITICAL',
          category: 'Security',
          file: csrf_file,
          issue: 'CSRF protection not implemented',
          fix: 'Implement verify_authenticity_token method'
        }
        puts "     ❌ CRITICAL: CSRF protection missing"
      end
    else
      @issues_found << {
        severity: 'CRITICAL',
        category: 'Security',
        file: csrf_file,
        issue: 'CSRF protection file missing',
        fix: 'Create CSRF protection concern'
      }
      puts "  1. CSRF Protection"
      puts "     ❌ CRITICAL: File missing (#{csrf_file})"
    end
    puts
    
    # Check session management
    auth_file = 'lib/services/auth_service.rb'
    if File.exist?(auth_file)
      content = File.read(auth_file)
      
      puts "  2. Session Management (lib/services/auth_service.rb)"
      
      if content.include?('session.regenerate') || content.include?('regenerate_sid')
        puts "     ✓ Session regeneration found"
      else
        @issues_found << {
          severity: 'HIGH',
          category: 'Security',
          file: auth_file,
          issue: 'Session fixation vulnerability - no session regeneration after login',
          fix: 'Add session.regenerate after successful authentication'
        }
        puts "     ❌ HIGH: Session not regenerated after login (fixation vulnerability)"
      end
      
      if content.include?('bcrypt') || content.include?('password_hash')
        puts "     ✓ Password hashing found"
      else
        puts "     ⚠️  WARNING: Verify password hashing is secure"
      end
    else
      puts "  2. Session Management"
      puts "     ⚠️  File not found (#{auth_file})"
    end
    puts
    
    # Check OAuth security
    oauth_file = 'routes/auth.rb'
    if File.exist?(oauth_file)
      content = File.read(oauth_file)
      
      puts "  3. OAuth Security (routes/auth.rb)"
      
      if content.include?('state') && content.include?('session')
        puts "     ✓ OAuth state parameter found"
        
        if !content.include?('verify') && !content.include?('validate')
          @issues_found << {
            severity: 'HIGH',
            category: 'Security',
            file: oauth_file,
            issue: 'OAuth state parameter not validated (CSRF vulnerability)',
            fix: 'Add state parameter validation in OAuth callback'
          }
          puts "     ❌ HIGH: State parameter not validated"
        else
          puts "     ⚠️  REVIEW NEEDED: Verify state validation is correct"
        end
      else
        @issues_found << {
          severity: 'HIGH',
          category: 'Security',
          file: oauth_file,
          issue: 'OAuth missing state parameter (CSRF vulnerability)',
          fix: 'Add state parameter to OAuth flow'
        }
        puts "     ❌ HIGH: OAuth state parameter missing"
      end
    else
      puts "  3. OAuth Security"
      puts "     ⚠️  File not found (#{oauth_file})"
    end
    puts
    
    security_count = @issues_found.select { |i| i[:category] == 'Security' }.count
    if security_count > 0
      puts "  📋 Security Issues Found: #{security_count}"
      puts "     Fix these to earn +3 points → 68/100"
    else
      puts "  ✅ No critical security issues found!"
      puts "     (Manual security review still recommended)"
    end
    puts
  end

  def audit_speed
    puts "⚡ PHASE 2: SPEED AUDIT (Days 3-5) → +4 points"
    puts
    
    # Count JavaScript files
    js_files = Dir.glob('public/js/**/*.js')
    js_size = js_files.sum { |f| File.size(f) }
    js_size_kb = (js_size / 1024.0).round(1)
    
    puts "  1. JavaScript Bundle Analysis"
    puts "     📁 Current: #{js_files.count} separate files"
    puts "     💾 Current: #{js_size_kb}KB total"
    puts
    
    if js_files.count > 10
      @optimizations << {
        category: 'Speed',
        task: 'Bundle JavaScript files',
        current: "#{js_files.count} files, #{js_size_kb}KB",
        target: "1 file, <100KB",
        tool: 'Vite bundler',
        impact: '+2 points'
      }
      puts "     ❌ TOO MANY FILES: #{js_files.count} JS files (should be 1)"
      puts "     🎯 Target: Bundle into 1 file, <100KB total"
      puts "     🔧 Tool: Vite (npm install -D vite)"
    end
    
    if js_size_kb > 100
      @optimizations << {
        category: 'Speed',
        task: 'Minify JavaScript',
        current: "#{js_size_kb}KB",
        target: "<100KB",
        tool: 'Vite minification',
        impact: '+1 point'
      }
      puts "     ❌ TOO LARGE: #{js_size_kb}KB (should be <100KB)"
      puts "     🎯 Target: Minify and tree-shake to <100KB"
    end
    puts
    
    # Check for Vite
    puts "  2. Build Tool Analysis"
    if File.exist?('vite.config.js') || File.exist?('vite.config.ts')
      puts "     ✓ Vite already installed"
    else
      @optimizations << {
        category: 'Speed',
        task: 'Install Vite bundler',
        current: "No bundler",
        target: "Vite with minification",
        tool: 'npm install -D vite',
        impact: '+2 points'
      }
      puts "     ❌ No bundler found"
      puts "     🎯 Install: npm install -D vite"
      puts "     📝 Create: vite.config.js"
    end
    puts
    
    # Check CSS files
    css_files = Dir.glob('public/css/**/*.css')
    css_size = css_files.sum { |f| File.size(f) }
    css_size_kb = (css_size / 1024.0).round(1)
    
    puts "  3. CSS Analysis"
    puts "     📁 Files: #{css_files.count}"
    puts "     💾 Size: #{css_size_kb}KB"
    
    # Check for duplicate grid layouts
    grid_files = css_files.select { |f| f.include?('grid-layout') }
    if grid_files.count > 1
      @optimizations << {
        category: 'Speed',
        task: 'Remove duplicate CSS files',
        current: "#{grid_files.count} grid-layout files",
        target: "1 grid-layout file",
        tool: 'Manual deletion',
        impact: '+1 point'
      }
      puts "     ❌ DUPLICATES: #{grid_files.count} grid-layout files:"
      grid_files.each { |f| puts "        - #{f}" }
      puts "     🎯 Keep only: public/css/grid-layout.css"
    end
    puts
    
    speed_count = @optimizations.select { |o| o[:category] == 'Speed' }.count
    if speed_count > 0
      puts "  📋 Speed Optimizations Found: #{speed_count}"
      puts "     Complete these to earn +4 points → 72/100"
    else
      puts "  ✅ Speed optimizations look good!"
    end
    puts
  end

  def audit_services
    puts "🔧 PHASE 3: SERVICE REDUCTION (Days 6-7) → +3 points"
    puts
    puts "  Goal: 42 services → 30 services (12 to remove/merge)"
    puts
    
    # Services to remove (based on PATH_TO_99_ELON_RATING.md)
    removable_services = [
      {
        file: 'lib/services/subreddit_discovery_service.rb',
        reason: 'Move to static config/subreddits.yml',
        replacement: 'data/subreddits.yml',
        impact: 'Simplifies architecture'
      },
      {
        file: 'lib/services/alert_service.rb',
        reason: 'Use Sentry instead',
        replacement: 'config/sentry.rb',
        impact: 'Removes redundant service'
      },
      {
        file: 'lib/services/push_notification_service.rb',
        reason: 'Premature feature (no users yet)',
        replacement: 'Delete (add back when you have 1K DAU)',
        impact: 'Removes unused feature'
      },
      {
        file: 'lib/services/quality_pipeline_service.rb',
        reason: 'Merge into MemeService',
        replacement: 'lib/services/meme_service.rb',
        impact: 'Consolidates related logic'
      },
      {
        file: 'lib/services/collaborative_filtering_service.rb',
        reason: 'Over-engineered (SimpleMemeSelector is enough)',
        replacement: 'Already deleted ✓',
        impact: 'N/A'
      }
    ]
    
    removable_services.each_with_index do |service, index|
      if File.exist?(service[:file])
        @services_to_remove << service
        puts "  #{index + 1}. ❌ REMOVE: #{service[:file]}"
        puts "     Reason: #{service[:reason]}"
        puts "     Replace with: #{service[:replacement]}"
        puts
      elsif service[:replacement] == 'Already deleted ✓'
        puts "  #{index + 1}. ✓ DONE: #{service[:file]}"
        puts "     #{service[:replacement]}"
        puts
      else
        puts "  #{index + 1}. ⚠️  NOT FOUND: #{service[:file]}"
        puts "     (May already be deleted)"
        puts
      end
    end
    
    # Additional services to check
    additional_checks = [
      'lib/services/retention_service.rb',
      'lib/services/daily_digest_service.rb',
      'lib/services/user_collections_service.rb'
    ]
    
    additional_checks.each do |service_file|
      if File.exist?(service_file)
        puts "  ⚠️  REVIEW: #{service_file}"
        puts "     Ask: 'Would the app work without this?'"
        puts "     If yes: Delete it"
        puts
      end
    end
    
    if @services_to_remove.count > 0
      puts "  📋 Services to Remove: #{@services_to_remove.count}"
      puts "     Remove these to earn +3 points → 72/100"
    else
      puts "  ✅ Service reduction already complete!"
    end
    puts
  end

  def print_summary
    puts "=" * 80
    puts "📊 WEEK 3 AUDIT SUMMARY"
    puts "=" * 80
    puts
    
    total_issues = @issues_found.count + @optimizations.count + @services_to_remove.count
    
    puts "  🔒 Security Issues: #{@issues_found.count}"
    @issues_found.each do |issue|
      puts "     #{issue[:severity]}: #{issue[:issue]}"
      puts "     File: #{issue[:file]}"
      puts "     Fix: #{issue[:fix]}"
      puts
    end
    
    puts "  ⚡ Speed Optimizations: #{@optimizations.count}"
    @optimizations.each do |opt|
      puts "     #{opt[:task]}"
      puts "     Current: #{opt[:current]}"
      puts "     Target: #{opt[:target]}"
      puts "     Tool: #{opt[:tool]}"
      puts "     Impact: #{opt[:impact]}"
      puts
    end
    
    puts "  🔧 Services to Remove: #{@services_to_remove.count}"
    @services_to_remove.each do |service|
      puts "     #{File.basename(service[:file])}"
      puts "     Reason: #{service[:reason]}"
      puts
    end
    
    puts "=" * 80
    puts
  end

  def print_action_plan
    puts "=" * 80
    puts "🚀 YOUR WEEK 3 ACTION PLAN (65 → 72)"
    puts "=" * 80
    puts
    
    puts "📅 DAYS 1-2: FIX SECURITY (+3 points → 68/100)"
    puts
    
    if @issues_found.any?
      @issues_found.each_with_index do |issue, index|
        puts "  #{index + 1}. #{issue[:file]}"
        puts "     Problem: #{issue[:issue]}"
        puts "     Fix: #{issue[:fix]}"
        puts
        puts "     Test with:"
        puts "     bundle exec rspec spec/#{File.basename(issue[:file], '.rb')}_spec.rb"
        puts
      end
    else
      puts "  ✅ No critical security issues found"
      puts "     But still run: bundle exec rspec spec/concerns/"
      puts
    end
    
    puts "📅 DAYS 3-5: OPTIMIZE SPEED (+4 points → 72/100)"
    puts
    
    if @optimizations.any?
      puts "  1. Install Vite:"
      puts "     npm install -D vite"
      puts
      puts "  2. Create vite.config.js:"
      puts "     // Bundle all 75 JS files → 1 file"
      puts "     // Minify to <100KB"
      puts "     // See PATH_TO_99_ELON_RATING.md for config"
      puts
      puts "  3. Build and test:"
      puts "     npm run build"
      puts "     ls -lh dist/*.js  # Should be <100KB"
      puts
      puts "  4. Remove duplicate CSS:"
      css_duplicates = Dir.glob('public/css/*grid-layout*.css')
      if css_duplicates.count > 1
        puts "     Keep: public/css/grid-layout.css"
        css_duplicates.each do |f|
          next if f == 'public/css/grid-layout.css'
          puts "     Delete: #{f}"
        end
      end
      puts
    else
      puts "  ✅ Speed optimizations already complete"
      puts
    end
    
    puts "📅 DAYS 6-7: REDUCE SERVICES (+3 points → 72/100)"
    puts
    
    if @services_to_remove.any?
      @services_to_remove.each_with_index do |service, index|
        puts "  #{index + 1}. #{service[:file]}"
        puts "     Action: #{service[:reason]}"
        puts "     Replace: #{service[:replacement]}"
        puts
      end
      puts "  Result: 42 services → #{42 - @services_to_remove.count} services"
      puts
    else
      puts "  ✅ Service reduction complete"
      puts
    end
    
    puts "=" * 80
    puts
    puts "✅ AFTER WEEK 3: 72/100"
    puts
    puts "WHAT YOU'LL HAVE:"
    puts "  ✓ Zero critical security vulnerabilities"
    puts "  ✓ <100KB JavaScript bundle (vs #{Dir.glob('public/js/**/*.js').count} files now)"
    puts "  ✓ ~30 services (vs 42 now)"
    puts "  ✓ Sub-1-second page load time"
    puts
    puts "NEXT STEPS:"
    puts "  → Month 1: Get to 85/100 (revenue + production)"
    puts "  → Month 2: Get to 95/100 (viral growth + mobile)"
    puts "  → Month 4: Get to 99/100 (15 services + perfect core loop)"
    puts
    puts "📖 See PATH_TO_99_ELON_RATING.md for full roadmap"
    puts
    puts "=" * 80
  end
end

# Run the audit
ElonWeek3To72.new(dry_run: true).execute
