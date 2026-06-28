# RSpec tests for MemeSelectionService (formerly RandomSelectorService)
# RandomSelectorService was deleted in Sprint 5 service consolidation.
# MemeSelectionService is the canonical replacement — same public interface.

require 'spec_helper'
require_relative '../../lib/services/meme_selection_service'

RSpec.describe MemeExplorer::MemeSelectionService do
  describe '.select_random_meme' do
    context 'with empty meme pool' do
      it 'returns nil when no memes available' do
        result = described_class.select_random_meme([])
        expect(result).to be_nil
      end
    end
    
    context 'with valid meme pool' do
      let(:memes) { create_meme_pool(20) }
      
      it 'returns a meme hash' do
        result = described_class.select_random_meme(memes)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key('url')
        expect(result).to have_key('title')
      end
      
      it 'returns a meme from the pool' do
        result = described_class.select_random_meme(memes)
        meme_urls = memes.map { |m| m['url'] }
        
        expect(meme_urls).to include(result['url'])
      end
      
      it 'adds metadata to selected meme' do
        result = described_class.select_random_meme(memes)
        
        expect(result).to have_key('media_type')
        expect(result).to have_key('loadability_score')
      end
    end
    
    context 'with session tracking' do
      let(:memes) { create_meme_pool(10) }
      let(:session_id) { "test_session_#{SecureRandom.hex(8)}" }
      
      after(:each) do
        # Cleanup Redis test data
        if defined?(REDIS) && REDIS
          REDIS.del("recent_memes:#{session_id}")
          REDIS.del("recent_titles:#{session_id}")
          REDIS.del("recent_humor_types:#{session_id}")
        end
      end
      
      it 'tracks selected memes in session' do
        3.times do
          described_class.select_random_meme(memes, session_id: session_id)
        end
        
        # Check Redis has tracking data
        if defined?(REDIS) && REDIS
          recent = REDIS.get("recent_memes:#{session_id}")
          expect(recent).not_to be_nil
        end
      end
      
      it 'avoids recently shown memes' do
        # Select first meme
        first_meme = described_class.select_random_meme(memes, session_id: session_id)
        
        # Select 5 more memes
        subsequent_memes = 5.times.map do
          described_class.select_random_meme(memes, session_id: session_id)
        end
        
        # First meme should not appear again (with high probability)
        subsequent_urls = subsequent_memes.map { |m| m['url'] }
        expect(subsequent_urls).not_to include(first_meme['url'])
      end
    end
    
    context 'media quality filtering' do
      it 'prefers high-quality memes' do
        high_quality = create_high_quality_pool(5)
        low_quality = FactoryBot.build_list(:meme, 15, :low_quality)
        mixed_pool = (high_quality + low_quality).shuffle
        
        # Select 10 memes
        selections = 10.times.map do
          described_class.select_random_meme(mixed_pool)
        end
        
        # Count high vs low quality selections
        high_selected = selections.count { |m| m['media_quality_score'] > 0.8 }
        
        # Should select more high-quality (>50% of the time)
        expect(high_selected).to be > 5
      end
      
      it 'filters out broken URLs' do
        valid = create_meme_pool(10)
        invalid = FactoryBot.build_list(:meme, 5, :invalid)
        mixed = (valid + invalid).shuffle
        
        result = described_class.select_random_meme(mixed)
        
        expect(result['media_quality_score']).to be > 0.5
      end
    end
    
    context 'humor type variety' do
      let(:session_id) { "variety_test_#{SecureRandom.hex(8)}" }
      
      after(:each) do
        if defined?(REDIS) && REDIS
          REDIS.del("recent_humor_types:#{session_id}")
        end
      end
      
      it 'provides variety in humor types' do
        memes = []
        memes += FactoryBot.build_list(:meme, 10, humor_type: 'dank')
        memes += FactoryBot.build_list(:meme, 10, humor_type: 'wholesome')
        memes += FactoryBot.build_list(:meme, 10, humor_type: 'relatable')
        memes.shuffle!
        
        # Select 10 memes
        selections = 10.times.map do
          described_class.select_random_meme(memes, session_id: session_id)
        end
        
        humor_types = selections.map { |m| m['humor_type'] }.uniq
        
        # Should have at least 2 different humor types
        expect(humor_types.size).to be >= 2
      end
    end
    
    context 'viral boost' do
      it 'gives higher weight to viral memes' do
        normal = FactoryBot.build_list(:meme, 15)
        viral = FactoryBot.build_list(:meme, 5, :viral)
        mixed = (normal + viral).shuffle
        
        # Select 20 memes
        selections = 20.times.map do
          described_class.select_random_meme(mixed)
        end
        
        # Count viral selections
        viral_selected = selections.count { |m| m['likes'] > 50000 }
        
        # Viral memes should be overrepresented
        # 5/20 = 25% of pool, should select >25% of the time
        expect(viral_selected).to be > 5
      end
    end
    
    context 'freshness priority' do
      it 'prioritizes recent memes' do
        old = FactoryBot.build_list(:meme, 15, :old)
        fresh = FactoryBot.build_list(:meme, 5, :fresh)
        mixed = (old + fresh).shuffle
        
        selections = 20.times.map do
          described_class.select_random_meme(mixed)
        end
        
        # Count fresh selections
        fresh_selected = selections.count do |m|
          (Time.now.to_i - m['created_utc']) < 7200
        end
        
        # Fresh memes should be overrepresented
        expect(fresh_selected).to be > 5
      end
    end
    
    context 'user preferences' do
      it 'applies exclusion filters' do
        memes = create_meme_pool(20)
        preferences = { excluded_subreddits: ['memes'] }
        
        result = described_class.select_random_meme(
          memes,
          preferences: preferences
        )
        
        expect(result['subreddit']).not_to eq('memes')
      end
    end
    
    context 'fallback behavior' do
      it 'falls back gracefully when filters are too strict' do
        # All memes from same subreddit
        memes = FactoryBot.build_list(:meme, 10, subreddit: 'specific')
        preferences = { excluded_subreddits: ['specific'] }
        
        result = described_class.select_random_meme(
          memes,
          preferences: preferences
        )
        
        # Should still return a meme (fallback activated)
        expect(result).to be_a(Hash)
      end
    end
  end
  
  describe 'algorithm performance' do
    it 'selects meme in reasonable time' do
      large_pool = create_meme_pool(1000)
      
      start_time = Time.now
      result = described_class.select_random_meme(large_pool)
      duration = Time.now - start_time
      
      expect(result).not_to be_nil
      expect(duration).to be < 0.1 # Should complete in <100ms
    end
  end
  
  describe 'edge cases' do
    it 'handles memes without URLs' do
      local_memes = FactoryBot.build_list(:meme, 5, :local)
      result = described_class.select_random_meme(local_memes)
      
      expect(result).to be_a(Hash)
      expect(result['file']).to be_present
    end
    
    it 'handles memes with missing fields' do
      incomplete = [
        { 'url' => 'https://example.com/meme.jpg' },
        { 'url' => 'https://example.com/meme2.jpg', 'title' => 'Test' }
      ]
      
      result = described_class.select_random_meme(incomplete)
      expect(result).to be_a(Hash)
    end
  end
end
