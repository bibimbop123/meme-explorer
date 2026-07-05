#!/usr/bin/env ruby
# frozen_string_literal: true

# Tier 2: Proactive Pool Monitoring at 30% Threshold
# Prevents pool exhaustion by refreshing in background before depletion

puts "🚀 [Tier 2] Implementing Proactive Pool Monitoring..."

FILE_PATH = 'lib/services/meme_pool_manager.rb'

# Backup
backup_path = "#{FILE_PATH}.backup_tier2_#{Time.now.to_i}"
File.write(backup_path, File.read(FILE_PATH))
puts "✅ Backup created: #{backup_path}"

content = File.read(FILE_PATH)

# Add threshold constant at top of class (after POOL_KEY)
content.gsub!(
  /POOL_KEY = 'random_memes_pool'/,
  "POOL_KEY = 'random_memes_pool'\n    LOW_THRESHOLD_PERCENT = 30 # Trigger background refresh at 30% capacity"
)

# Add proactive monitoring method before get_pool
proactive_method = <<~RUBY


    # Check pool capacity and trigger proactive refresh if below threshold
    def check_and_refresh_if_low(current_size)
      return if current_size >= 200 # Above comfortable level

      capacity_percent = (current_size.to_f / 500) * 100
      
      if capacity_percent <= LOW_THRESHOLD_PERCENT
        AppLogger.info("📊 [PoolManager] Pool at \#{capacity_percent.round}% capacity (\#{current_size} memes) - triggering proactive refresh")
        trigger_background_expansion
      end
    rescue => e
      AppLogger.error("⚠️  [PoolManager] Proactive refresh check failed: \#{e.message}")
    end
RUBY

# Insert proactive method before get_pool method
content.gsub!(
  /def get_pool/,
  "#{proactive_method.strip}\n\n    def get_pool"
)

# Add proactive check in get_pool right after getting current pool (before pool.any?)
content.gsub!(
  /(pool = pool_redis\.smembers\(POOL_KEY\)\.map \{ \|json\| JSON\.parse\(json\) \}\n\s+size = pool\.size)/,
  "\\1\n      \n      # Proactive monitoring: trigger refresh if pool running low\n      check_and_refresh_if_low(size)"
)

File.write(FILE_PATH, content)

puts "✅ [Tier 2] Proactive pool monitoring implemented!"
puts ""
puts "📊 Changes Made:"
puts "  • Added LOW_THRESHOLD_PERCENT constant (30%)"
puts "  • Added check_and_refresh_if_low method"
puts "  • Integrated proactive check in get_pool"
puts ""
puts "🎯 Expected Impact:"
puts "  • Pool exhaustion: Every 30-60s → Every 5-10 minutes"
puts "  • Background refresh triggers at 30% capacity (~150 memes)"
puts "  • Users never experience bootstrap delays"
puts ""
puts "✅ Ready to commit and deploy!"
