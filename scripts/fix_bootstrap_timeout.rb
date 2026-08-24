#!/usr/bin/env ruby
# Fix bootstrap timeout causing 502 errors
# Problem: Bootstrap tries 80 subreddits even when ALL are 429ing
# Solution: Fail fast after 3 consecutive 429s

puts "🔧 Fixing MemePoolManager bootstrap timeout..."

file_path = 'lib/services/meme_pool_manager.rb'
content = File.read(file_path)

# Add fast-fail logic to bootstrap_pool
updated = content.gsub(
  /def bootstrap_pool\n\s+AppLogger\.info\("🚀 \[Bootstrap\] AGGRESSIVE fetch from ALL 5 tiers for variety\.\.\."\)/,
  <<~RUBY.chomp
def bootstrap_pool
    AppLogger.info("🚀 [Bootstrap] Attempting bootstrap (will fail fast if rate-limited)...")
    
    # CRITICAL: Fail fast if Reddit is completely rate-limited
    # Try just 3 subreddits first to check if we're getting 429s
    test_subs = load_tier_subreddits(:tier_1).first(3)
    fetcher = create_fetcher
    test_memes = fetcher.fetch_memes(test_subs, limit: 5)
    
    # If we got ZERO memes from 3 attempts, Reddit is rate-limited
    # Don't waste 25 seconds trying 80 more subreddits
    if test_memes.empty?
      AppLogger.warn("⚠️  [Bootstrap] Reddit rate-limited - skipping full bootstrap, using local fallback")
      return { success: false, size: 0, memes: [], error: "Reddit rate limited (429)" }
    end
    
    AppLogger.info("🚀 [Bootstrap] Reddit responsive - proceeding with full fetch...")
  RUBY
)

if updated == content
  puts "❌ Pattern not found - file may have changed"
  exit 1
end

File.write(file_path, updated)
puts "✅ Fixed: Bootstrap now fails fast when Reddit is rate-limited"
puts "   - Tests 3 subreddits first (< 3 seconds)"
puts "   - Skips full 80-subreddit fetch if all fail"
puts "   - Falls back to local memes immediately"
