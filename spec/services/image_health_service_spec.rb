# spec/services/image_health_service_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/image_health_service'

RSpec.describe ImageHealthService do
  let(:service) { described_class.new }
  let(:test_url) { 'https://i.imgur.com/test123.jpg' }
  let(:broken_url) { 'https://i.imgur.com/broken.jpg' }
  
  before(:each) do
    # Create broken_images table if needed
    DB.execute(<<-SQL) rescue nil
      CREATE TABLE IF NOT EXISTS broken_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT UNIQUE NOT NULL,
        failure_count INTEGER DEFAULT 1,
        last_checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    SQL
    DB.execute("DELETE FROM broken_images") rescue nil
  end
  
  describe '#validate_image' do
    context 'with valid image URL' do
      it 'returns true for valid image extensions' do
        valid_urls = [
          'https://i.imgur.com/abc.jpg',
          'https://i.redd.it/def.png',
          'https://preview.redd.it/ghi.gif',
          'https://i.imgur.com/jkl.webp'
        ]
        
        valid_urls.each do |url|
          expect(service.validate_image(url)).to be true
        end
      end
      
      it 'accepts URLs from trusted domains' do
        trusted_urls = [
          'https://i.imgur.com/test.jpg',
          'https://i.redd.it/test.jpg',
          'https://preview.redd.it/test.jpg',
          'https://external-preview.redd.it/test.jpg'
        ]
        
        trusted_urls.each do |url|
          expect(service.validate_image(url)).to be true
        end
      end
    end
    
    context 'with invalid image URL' do
      it 'rejects reddit post URLs' do
        invalid_urls = [
          'https://www.reddit.com/r/memes/comments/abc123',
          'https://reddit.com/gallery/def456',
          'https://v.redd.it/ghi789'
        ]
        
        invalid_urls.each do |url|
          expect(service.validate_image(url)).to be false
        end
      end
      
      it 'rejects URLs without image extensions' do
        expect(service.validate_image('https://example.com/page')).to be false
        expect(service.validate_image('https://example.com/file.txt')).to be false
      end
      
      it 'handles nil URL' do
        expect(service.validate_image(nil)).to be false
      end
      
      it 'handles empty URL' do
        expect(service.validate_image('')).to be false
      end
    end
  end
  
  describe '#mark_as_broken' do
    it 'adds URL to broken images table' do
      service.mark_as_broken(broken_url)
      
      result = DB.execute("SELECT * FROM broken_images WHERE url = ?", [broken_url]).first
      expect(result).not_to be_nil
      expect(result['failure_count']).to eq(1)
    end
    
    it 'increments failure count for existing broken image' do
      service.mark_as_broken(broken_url)
      service.mark_as_broken(broken_url)
      
      result = DB.execute("SELECT failure_count FROM broken_images WHERE url = ?", [broken_url]).first
      expect(result['failure_count']).to eq(2)
    end
    
    it 'updates last_checked_at timestamp' do
      service.mark_as_broken(broken_url)
      first_check = DB.execute("SELECT last_checked_at FROM broken_images WHERE url = ?", [broken_url]).first
      
      sleep 1
      service.mark_as_broken(broken_url)
      second_check = DB.execute("SELECT last_checked_at FROM broken_images WHERE url = ?", [broken_url]).first
      
      expect(second_check['last_checked_at']).not_to eq(first_check['last_checked_at'])
    end
  end
  
  describe '#is_broken?' do
    context 'with broken image' do
      before do
        service.mark_as_broken(broken_url)
      end
      
      it 'returns true for broken URLs' do
        expect(service.is_broken?(broken_url)).to be true
      end
      
      it 'returns true for URLs with high failure count' do
        5.times { service.mark_as_broken(broken_url) }
        expect(service.is_broken?(broken_url)).to be true
      end
    end
    
    context 'with working image' do
      it 'returns false for URLs not in blacklist' do
        expect(service.is_broken?(test_url)).to be false
      end
    end
    
    it 'handles nil URL' do
      expect(service.is_broken?(nil)).to be false
    end
  end
  
  describe '#get_broken_count' do
    it 'returns total count of broken images' do
      service.mark_as_broken('https://example.com/1.jpg')
      service.mark_as_broken('https://example.com/2.jpg')
      service.mark_as_broken('https://example.com/3.jpg')
      
      expect(service.get_broken_count).to eq(3)
    end
    
    it 'returns 0 when no broken images' do
      expect(service.get_broken_count).to eq(0)
    end
  end
  
  describe '#get_broken_images' do
    before do
      3.times { |i| service.mark_as_broken("https://example.com/#{i}.jpg") }
    end
    
    it 'returns array of broken image URLs' do
      broken = service.get_broken_images
      expect(broken).to be_an(Array)
      expect(broken.length).to eq(3)
    end
    
    it 'limits results when limit parameter provided' do
      broken = service.get_broken_images(limit: 2)
      expect(broken.length).to eq(2)
    end
    
    it 'orders by failure count descending' do
      url1 = 'https://example.com/most_broken.jpg'
      5.times { service.mark_as_broken(url1) }
      
      broken = service.get_broken_images
      expect(broken.first['url']).to eq(url1)
    end
  end
  
  describe '#remove_from_blacklist' do
    before do
      service.mark_as_broken(broken_url)
    end
    
    it 'removes URL from broken images table' do
      service.remove_from_blacklist(broken_url)
      expect(service.is_broken?(broken_url)).to be false
    end
    
    it 'handles removal of non-existent URL gracefully' do
      expect { service.remove_from_blacklist('nonexistent.jpg') }.not_to raise_error
    end
  end
  
  describe '#cleanup_old_entries' do
    it 'removes old broken image entries' do
      # Mark as broken and manually update timestamp to be old
      service.mark_as_broken(broken_url)
      DB.execute(
        "UPDATE broken_images SET last_checked_at = datetime('now', '-31 days') WHERE url = ?",
        [broken_url]
      )
      
      service.cleanup_old_entries(days: 30)
      expect(service.is_broken?(broken_url)).to be false
    end
    
    it 'keeps recent entries' do
      service.mark_as_broken(test_url)
      service.cleanup_old_entries(days: 30)
      expect(service.is_broken?(test_url)).to be true
    end
  end
  
  describe '#get_statistics' do
    before do
      3.times { |i| service.mark_as_broken("https://example.com/#{i}.jpg") }
      service.mark_as_broken('https://example.com/0.jpg') # Increment one
    end
    
    it 'returns statistics hash' do
      stats = service.get_statistics
      expect(stats).to be_a(Hash)
    end
    
    it 'includes total count' do
      stats = service.get_statistics
      expect(stats[:total_broken]).to eq(3)
    end
    
    it 'includes failure statistics' do
      stats = service.get_statistics
      expect(stats).to have_key(:avg_failures)
      expect(stats).to have_key(:max_failures)
    end
  end
  
  describe 'integration test' do
    it 'full image health tracking workflow' do
      # 1. Validate image
      expect(service.validate_image(test_url)).to be true
      
      # 2. Mark as broken
      service.mark_as_broken(test_url)
      expect(service.is_broken?(test_url)).to be true
      
      # 3. Check statistics
      stats = service.get_statistics
      expect(stats[:total_broken]).to be > 0
      
      # 4. Remove from blacklist
      service.remove_from_blacklist(test_url)
      expect(service.is_broken?(test_url)).to be false
    end
  end
end
