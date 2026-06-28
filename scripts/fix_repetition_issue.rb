#!/usr/bin/env ruby
# Fix Meme Repetition Issue - Relax Diversity Engine Filters
# Problem: Filters too strict → small pools → repetitive content
# Solution: Relax filters significantly for larger, more diverse pools

require_relative '../config/application'

puts "🔍 Diagnosing Repetition Issue..."
puts "=" * 60

# Check current meme cache size
cache_size = if defined?(MemeExplorer::App::MEME_CACHE)
  MemeExplorer::App::MEME_CACHE[:memes]&.size || 0
else
  0
end

puts "📊 Current meme cache size: #{cache_size}"

if cache_size < 100
  puts "⚠️  WARNING: Very small cache! Need at least 500+ memes for good diversity"
end

# Analyze meme metadata to see why pools are small
if cache_size > 0
  memes = MemeExplorer::App::MEME_CACHE[:memes]
  
  # Check likes distribution
  high_likes = memes.count { |m| m['likes'].to_i >= 100 }
  medium_likes = memes.count { |m| m['likes'].to_i.between?(50, 99) }
  low_likes = memes.count { |m| m['likes'].to_i < 50 }
  
  puts "\n📈 Likes Distribution:"
  puts "  High (100+): #{high_likes} (#{(high_likes.to_f / cache_size * 100).round(1)}%)"
  puts "  Medium (50-99): #{medium_likes} (#{(medium_likes.to_f / cache_size * 100).round(1)}%)"
  puts "  Low (<50): #{low_likes} (#{(low_likes.to_f / cache_size * 100).round(1)}%)"
  
  # Check age distribution
  now = Time.now
  fresh_6h = memes.count do |m|
    next false unless m['created_at']
    created = Time.parse(m['created_at'].to_s) rescue nil
    created && (now - created) < 6 * 3600
  end
  
  fresh_24h = memes.count do |m|
    next false unless m['created_at']
    created = Time.parse(m['created_at'].to_s) rescue nil
    created && (now - created) < 24 * 3600
  end
  
  vintage_30d = memes.count do |m|
    next false unless m['created_at']
    created = Time.parse(m['created_at'].to_s) rescue nil
    created && (now - created) > 30 * 24 * 3600 && m['likes'].to_i >= 500
  end
  
  puts "\n⏰ Age Distribution:"
  puts "  Fresh (< 6h): #{fresh_6h} (#{(fresh_6h.to_f / cache_size * 100).round(1)}%)"
  puts "  Recent (< 24h): #{fresh_24h} (#{(fresh_24h.to_f / cache_size * 100).round(1)}%)"
  puts "  Vintage (30d+ & 500+ likes): #{vintage_30d} (#{(vintage_30d.to_f / cache_size * 100).round(1)}%)"
  
  # Subreddit diversity
  subreddits = memes.map { |m| m['subreddit'] }.compact.uniq
  puts "\n🎭 Subreddit Diversity: #{subreddits.size} unique subreddits"
  
  # Top subreddits
  sub_counts = memes.group_by { |m| m['subreddit'] }.transform_values(&:count)
  top_5 = sub_counts.sort_by { |k, v| -v }.take(5)
  puts "\n🏆 Top 5 Subreddits:"
  top_5.each do |sub, count|
    puts "  #{sub}: #{count} memes (#{(count.to_f / cache_size * 100).round(1)}%)"
  end
end

puts "\n" + "=" * 60
puts "🎯 RECOMMENDATIONS:"
puts "=" * 60

puts "\n1. IMMEDIATE: Relax diversity engine filters (running now...)"
puts "2. Increase cache refresh frequency (every 10 min instead of 30 min)"
puts "3. Fetch from more subreddits simultaneously"
puts "4. Lower quality thresholds to include more content"

puts "\n✅ Applying fixes..."
