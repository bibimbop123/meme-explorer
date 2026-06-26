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
    it 'generates leaderboard cache key' do
      expect(CacheKeys.leaderboard('weekly')).to eq('v2:leaderboard:weekly')
    end
  end

  describe '.trending' do
    it 'generates trending cache key with period' do
      expect(CacheKeys.trending('day')).to eq('v2:trending:day')
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
