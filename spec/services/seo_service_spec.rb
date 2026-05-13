# spec/services/seo_service_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/seo_service'

RSpec.describe SeoService do
  let(:mock_request) do
    double('Request',
      scheme: 'https',
      host_with_port: 'example.com',
      path: '/test'
    )
  end
  
  describe '.generate_meta_tags' do
    it 'generates default meta tags without request' do
      meta = SeoService.generate_meta_tags
      
      expect(meta[:title]).to include('Meme Explorer')
      expect(meta[:description]).to include('memes')
      expect(meta[:canonical]).to include('https://meme-explorer.com')
    end
    
    it 'generates meta tags with custom data' do
      custom_data = {
        title: 'Custom Title',
        description: 'Custom description'
      }
      
      meta = SeoService.generate_meta_tags(custom_data)
      
      expect(meta[:title]).to eq('Custom Title')
      expect(meta[:description]).to eq('Custom description')
    end
    
    it 'includes Open Graph tags' do
      meta = SeoService.generate_meta_tags({}, mock_request)
      
      expect(meta[:og]).to be_a(Hash)
      expect(meta[:og][:title]).not_to be_nil
      expect(meta[:og][:description]).not_to be_nil
      expect(meta[:og][:image]).not_to be_nil
      expect(meta[:og][:url]).to eq('https://example.com/test')
      expect(meta[:og][:site_name]).to eq('Meme Explorer')
    end
    
    it 'includes Twitter Card tags' do
      meta = SeoService.generate_meta_tags({}, mock_request)
      
      expect(meta[:twitter]).to be_a(Hash)
      expect(meta[:twitter][:card]).to eq('summary_large_image')
      expect(meta[:twitter][:site]).to eq('@MemeExplorer')
      expect(meta[:twitter][:creator]).to eq('@MemeExplorer')
    end
    
    it 'converts relative image URLs to absolute' do
      meta = SeoService.generate_meta_tags({ image: '/images/test.jpg' }, mock_request)
      
      expect(meta[:og][:image]).to eq('https://example.com/images/test.jpg')
    end
    
    it 'keeps absolute image URLs unchanged' do
      meta = SeoService.generate_meta_tags({ image: 'https://cdn.com/image.jpg' })
      
      expect(meta[:og][:image]).to eq('https://cdn.com/image.jpg')
    end
    
    it 'sets canonical URL from request' do
      meta = SeoService.generate_meta_tags({}, mock_request)
      
      expect(meta[:canonical]).to eq('https://example.com/test')
    end
  end
  
  describe '.generate_json_ld' do
    it 'generates website schema' do
      json_ld = SeoService.generate_json_ld(:website, {}, mock_request)
      
      expect(json_ld).to include('application/ld+json')
      expect(json_ld).to include('WebSite')
      expect(json_ld).to include('Meme Explorer')
    end
    
    it 'generates organization schema' do
      json_ld = SeoService.generate_json_ld(:organization, {}, mock_request)
      
      expect(json_ld).to include('Organization')
      expect(json_ld).to include('Meme Explorer')
    end
    
    it 'generates meme schema with meme data' do
      meme_data = {
        meme: {
          'title' => 'Funny Meme',
          'url' => 'https://example.com/meme.jpg',
          'subreddit' => 'memes'
        },
        path: '/memes/123'
      }
      
      json_ld = SeoService.generate_json_ld(:meme, meme_data, mock_request)
      
      expect(json_ld).to include('CreativeWork')
      expect(json_ld).to include('Funny Meme')
      expect(json_ld).to include('memes')
    end
    
    it 'generates breadcrumbs schema' do
      breadcrumbs_data = {
        breadcrumbs: [
          { name: 'Home', path: '/' },
          { name: 'Trending', path: '/trending' }
        ]
      }
      
      json_ld = SeoService.generate_json_ld(:breadcrumbs, breadcrumbs_data, mock_request)
      
      expect(json_ld).to include('BreadcrumbList')
      expect(json_ld).to include('Home')
      expect(json_ld).to include('Trending')
    end
    
    it 'returns nil for unknown schema type' do
      json_ld = SeoService.generate_json_ld(:unknown_type, {})
      
      expect(json_ld).to be_nil
    end
  end
  
  describe '.generate_multiple_json_ld' do
    it 'generates multiple schemas' do
      schemas = [
        [:website, {}],
        [:organization, {}]
      ]
      
      result = SeoService.generate_multiple_json_ld(schemas, mock_request)
      
      expect(result).to include('WebSite')
      expect(result).to include('Organization')
    end
    
    it 'filters out nil schemas' do
      schemas = [
        [:website, {}],
        [:unknown, {}]
      ]
      
      result = SeoService.generate_multiple_json_ld(schemas)
      
      expect(result).to include('WebSite')
      expect(result).not_to include('unknown')
    end
  end
  
  describe '.home_page_meta' do
    it 'generates home page meta tags' do
      meta = SeoService.home_page_meta(mock_request)
      
      expect(meta[:title]).to include('Best Reddit Memes')
      expect(meta[:description]).to include('Discover')
      expect(meta[:keywords]).to include('best memes')
    end
  end
  
  describe '.trending_page_meta' do
    it 'generates trending page meta tags' do
      meta = SeoService.trending_page_meta(mock_request)
      
      expect(meta[:title]).to include('Trending Memes')
      expect(meta[:description]).to include('trending')
      expect(meta[:keywords]).to include('trending memes')
    end
  end
  
  describe '.random_page_meta' do
    it 'generates random page meta tags' do
      meta = SeoService.random_page_meta(mock_request)
      
      expect(meta[:title]).to include('Random Meme')
      expect(meta[:description]).to include('random')
      expect(meta[:keywords]).to include('random meme')
    end
  end
  
  describe '.meme_detail_meta' do
    let(:meme) do
      {
        'title' => 'Hilarious Cat Meme',
        'subreddit' => 'funny',
        'url' => 'https://example.com/cat.jpg'
      }
    end
    
    it 'generates meme detail meta tags' do
      meta = SeoService.meme_detail_meta(meme, mock_request)
      
      expect(meta[:title]).to include('Hilarious Cat Meme')
      expect(meta[:description]).to include('r/funny')
      expect(meta[:og][:image]).to eq('https://example.com/cat.jpg')
      expect(meta[:og][:type]).to eq('article')
    end
    
    it 'truncates long meme titles' do
      long_title_meme = {
        'title' => 'A' * 100,
        'subreddit' => 'memes'
      }
      
      meta = SeoService.meme_detail_meta(long_title_meme, mock_request)
      
      expect(meta[:title].length).to be <= 63  # 60 + "..."
    end
    
    it 'returns default meta when meme is nil' do
      meta = SeoService.meme_detail_meta(nil, mock_request)
      
      expect(meta[:title]).to include('Meme Explorer')
    end
  end
  
  describe '.leaderboard_page_meta' do
    it 'generates leaderboard page meta tags' do
      meta = SeoService.leaderboard_page_meta(mock_request)
      
      expect(meta[:title]).to include('Leaderboard')
      expect(meta[:description]).to include('leaderboard')
      expect(meta[:keywords]).to include('meme leaderboard')
    end
  end
  
  describe '.search_page_meta' do
    context 'with search query' do
      it 'generates search results meta tags' do
        meta = SeoService.search_page_meta('funny cats', mock_request)
        
        expect(meta[:title]).to include('funny cats')
        expect(meta[:description]).to include('funny cats')
        expect(meta[:robots]).to eq('noindex, follow')
      end
    end
    
    context 'without search query' do
      it 'generates general search page meta tags' do
        meta = SeoService.search_page_meta(nil, mock_request)
        
        expect(meta[:title]).to include('Search Memes')
        expect(meta[:description]).to include('Search')
      end
      
      it 'handles empty query string' do
        meta = SeoService.search_page_meta('', mock_request)
        
        expect(meta[:title]).to include('Search Memes')
      end
    end
  end
  
  describe '.profile_page_meta' do
    context 'with username' do
      it 'generates user profile meta tags' do
        meta = SeoService.profile_page_meta('john_doe', mock_request)
        
        expect(meta[:title]).to include('john_doe')
        expect(meta[:description]).to include('john_doe')
        expect(meta[:og][:type]).to eq('profile')
        expect(meta[:robots]).to eq('noindex, follow')
      end
    end
    
    context 'without username' do
      it 'generates generic profile meta tags' do
        meta = SeoService.profile_page_meta(nil, mock_request)
        
        expect(meta[:title]).to include('Your Profile')
        expect(meta[:og][:type]).to eq('profile')
        expect(meta[:robots]).to eq('noindex, follow')
      end
    end
  end
  
  describe 'utility methods' do
    describe '.absolute_url' do
      it 'converts relative URLs to absolute' do
        url = SeoService.send(:absolute_url, '/images/test.jpg', 'https://example.com')
        expect(url).to eq('https://example.com/images/test.jpg')
      end
      
      it 'keeps absolute URLs unchanged' do
        url = SeoService.send(:absolute_url, 'https://cdn.com/image.jpg', 'https://example.com')
        expect(url).to eq('https://cdn.com/image.jpg')
      end
      
      it 'handles http URLs' do
        url = SeoService.send(:absolute_url, 'http://cdn.com/image.jpg')
        expect(url).to eq('http://cdn.com/image.jpg')
      end
    end
    
    describe '.truncate' do
      it 'truncates long text' do
        text = SeoService.send(:truncate, 'A' * 100, 50)
        expect(text.length).to eq(50)
        expect(text).to end_with('...')
      end
      
      it 'keeps short text unchanged' do
        text = SeoService.send(:truncate, 'Short text', 50)
        expect(text).to eq('Short text')
      end
      
      it 'handles text exactly at limit' do
        text = SeoService.send(:truncate, 'A' * 50, 50)
        expect(text).to eq('A' * 50)
      end
    end
    
    describe '.image_type' do
      it 'detects JPEG images' do
        expect(SeoService.send(:image_type, 'image.jpg')).to eq('image/jpeg')
        expect(SeoService.send(:image_type, 'image.jpeg')).to eq('image/jpeg')
      end
      
      it 'detects PNG images' do
        expect(SeoService.send(:image_type, 'image.png')).to eq('image/png')
      end
      
      it 'detects GIF images' do
        expect(SeoService.send(:image_type, 'image.gif')).to eq('image/gif')
      end
      
      it 'detects WebP images' do
        expect(SeoService.send(:image_type, 'image.webp')).to eq('image/webp')
      end
      
      it 'defaults to JPEG for unknown types' do
        expect(SeoService.send(:image_type, 'image.unknown')).to eq('image/jpeg')
      end
      
      it 'handles uppercase extensions' do
        expect(SeoService.send(:image_type, 'IMAGE.PNG')).to eq('image/png')
      end
    end
  end
  
end
