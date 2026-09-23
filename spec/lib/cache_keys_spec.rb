require 'spec_helper'
require_relative '../../lib/cache_keys'

RSpec.describe CacheKeys do
  describe '.meme' do
    it 'generates versioned meme cache key' do
      expect(CacheKeys.meme(123)).to eq('v2:meme:123')
    end
  end

  describe '.user_profile' do
    it 'generates user profile cache key' do
      expect(CacheKeys.user_profile(456)).to eq('v2:user:456:profile')
    end
  end

  describe '.leaderboard' do
    it 'generates leaderboard cache key with default period' do
      # BUG FIX: the real signature is `leaderboard(type, period = 'weekly')`
      # (lib/cache_keys.rb) - calling `leaderboard('weekly')` passes
      # 'weekly' as the TYPE, not the period, producing
      # 'v2:leaderboard:weekly:weekly' (period still defaults to 'weekly'
      # separately). Pass a real type instead.
      expect(CacheKeys.leaderboard('all_time')).to eq('v2:leaderboard:all_time:weekly')
    end

    it 'generates leaderboard cache key with an explicit period' do
      expect(CacheKeys.leaderboard('all_time', 'monthly')).to eq('v2:leaderboard:all_time:monthly')
    end
  end

  describe '.trending_memes' do
    it 'generates trending cache key with period' do
      # BUG FIX: `CacheKeys.trending` doesn't exist - the real method is
      # `trending_memes(timeframe)`.
      expect(CacheKeys.trending_memes('day')).to eq('v2:trending:day')
    end
  end

  describe 'TTL constants' do
    it 'defines correct TTL values' do
      expect(CacheKeys::TTL_SHORT).to eq(300)
      expect(CacheKeys::TTL_MEDIUM).to eq(1800)
      expect(CacheKeys::TTL_LONG).to eq(3600)
      expect(CacheKeys::TTL_VERY_LONG).to eq(86400)
    end
  end
end
