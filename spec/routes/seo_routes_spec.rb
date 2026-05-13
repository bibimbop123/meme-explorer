# spec/routes/seo_routes_spec.rb
# Week 3: SEO Routes Testing
# Comprehensive tests for all SEO-related endpoints

require_relative '../spec_helper'

RSpec.describe 'SEO Routes' do
  
  describe 'GET /robots.txt' do
    it 'returns text/plain content type' do
      get '/robots.txt'
      expect(last_response.content_type).to include('text/plain')
    end
    
    it 'returns 200 OK status' do
      get '/robots.txt'
      expect(last_response).to be_ok
    end
    
    it 'includes User-agent directive' do
      get '/robots.txt'
      expect(last_response.body).to include('User-agent: *')
    end
    
    it 'allows crawling of main pages' do
      get '/robots.txt'
      expect(last_response.body).to include('Allow: /')
      expect(last_response.body).to include('Allow: /trending')
      expect(last_response.body).to include('Allow: /random')
    end
    
    it 'disallows crawling of sensitive areas' do
      get '/robots.txt'
      expect(last_response.body).to include('Disallow: /admin')
      expect(last_response.body).to include('Disallow: /api/')
      expect(last_response.body).to include('Disallow: /login')
    end
    
    it 'includes sitemap location' do
      get '/robots.txt'
      expect(last_response.body).to include('Sitemap:')
      expect(last_response.body).to include('/sitemap.xml')
    end
    
    it 'includes crawl delay directive' do
      get '/robots.txt'
      expect(last_response.body).to include('Crawl-delay')
    end
    
    it 'includes specific rules for Googlebot' do
      get '/robots.txt'
      expect(last_response.body).to include('User-agent: Googlebot')
    end
  end
  
  describe 'GET /sitemap.xml' do
    it 'returns XML content type' do
      get '/sitemap.xml'
      expect(last_response.content_type).to include('application/xml')
    end
    
    it 'returns 200 OK status' do
      get '/sitemap.xml'
      expect(last_response).to be_ok
    end
    
    it 'includes XML declaration' do
      get '/sitemap.xml'
      expect(last_response.body).to include('<?xml version="1.0" encoding="UTF-8"?>')
    end
    
    it 'includes urlset namespace' do
      get '/sitemap.xml'
      expect(last_response.body).to include('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"')
    end
    
    it 'includes homepage URL' do
      get '/sitemap.xml'
      expect(last_response.body).to include('<loc>')
      expect(last_response.body).to include('</loc>')
    end
    
    it 'includes priority tags' do
      get '/sitemap.xml'
      expect(last_response.body).to include('<priority>')
      expect(last_response.body).to include('</priority>')
    end
    
    it 'includes changefreq tags' do
      get '/sitemap.xml'
      expect(last_response.body).to include('<changefreq>')
      expect(last_response.body).to include('</changefreq>')
    end
    
    it 'includes lastmod tags' do
      get '/sitemap.xml'
      expect(last_response.body).to include('<lastmod>')
      expect(last_response.body).to include('</lastmod>')
    end
    
    it 'includes trending page' do
      get '/sitemap.xml'
      expect(last_response.body).to include('/trending')
    end
    
    it 'includes random page' do
      get '/sitemap.xml'
      expect(last_response.body).to include('/random')
    end
    
    it 'closes urlset tag' do
      get '/sitemap.xml'
      expect(last_response.body).to include('</urlset>')
    end
  end
  
  describe 'GET /humans.txt' do
    it 'returns text/plain content type' do
      get '/humans.txt'
      expect(last_response.content_type).to include('text/plain')
    end
    
    it 'returns 200 OK status' do
      get '/humans.txt'
      expect(last_response).to be_ok
    end
    
    it 'includes team section' do
      get '/humans.txt'
      expect(last_response.body).to include('/* TEAM */')
    end
    
    it 'includes thanks section' do
      get '/humans.txt'
      expect(last_response.body).to include('/* THANKS */')
    end
    
    it 'includes site section' do
      get '/humans.txt'
      expect(last_response.body).to include('/* SITE */')
    end
    
    it 'mentions Reddit API' do
      get '/humans.txt'
      expect(last_response.body).to include('Reddit API')
    end
    
    it 'includes framework information' do
      get '/humans.txt'
      expect(last_response.body).to include('Sinatra')
    end
  end
  
  describe 'GET /.well-known/security.txt' do
    it 'returns text/plain content type' do
      get '/.well-known/security.txt'
      expect(last_response.content_type).to include('text/plain')
    end
    
    it 'returns 200 OK status' do
      get '/.well-known/security.txt'
      expect(last_response).to be_ok
    end
    
    it 'includes contact information' do
      get '/.well-known/security.txt'
      expect(last_response.body).to include('Contact:')
    end
    
    it 'includes expiration date' do
      get '/.well-known/security.txt'
      expect(last_response.body).to include('Expires:')
    end
    
    it 'includes preferred languages' do
      get '/.well-known/security.txt'
      expect(last_response.body).to include('Preferred-Languages:')
    end
    
    it 'includes canonical URL' do
      get '/.well-known/security.txt'
      expect(last_response.body).to include('Canonical:')
    end
  end
  
  describe 'GET /ads.txt' do
    context 'when Google AdSense is configured' do
      before do
        ENV['GOOGLE_ADSENSE_CLIENT'] = 'ca-pub-1234567890'
      end
      
      after do
        ENV.delete('GOOGLE_ADSENSE_CLIENT')
      end
      
      it 'returns text/plain content type' do
        get '/ads.txt'
        expect(last_response.content_type).to include('text/plain')
      end
      
      it 'returns 200 OK status' do
        get '/ads.txt'
        expect(last_response).to be_ok
      end
      
      it 'includes Google AdSense declaration' do
        get '/ads.txt'
        expect(last_response.body).to include('google.com')
      end
      
      it 'includes publisher ID' do
        get '/ads.txt'
        expect(last_response.body).to include('pub-1234567890')
      end
      
      it 'includes DIRECT relationship' do
        get '/ads.txt'
        expect(last_response.body).to include('DIRECT')
      end
    end
    
    context 'when Google AdSense is not configured' do
      before do
        ENV.delete('GOOGLE_ADSENSE_CLIENT')
      end
      
      it 'returns 404 status' do
        get '/ads.txt'
        expect(last_response.status).to eq(404)
      end
      
      it 'returns message about missing configuration' do
        get '/ads.txt'
        expect(last_response.body).to include('AdSense not configured')
      end
    end
  end
  
  describe 'GET /manifest.json' do
    it 'returns JSON content type' do
      get '/manifest.json'
      expect(last_response.content_type).to include('application/json')
    end
    
    it 'returns 200 OK status' do
      get '/manifest.json'
      expect(last_response).to be_ok
    end
    
    it 'returns valid JSON' do
      get '/manifest.json'
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end
    
    it 'includes app name' do
      get '/manifest.json'
      manifest = JSON.parse(last_response.body)
      expect(manifest['name']).to eq('Meme Explorer')
    end
    
    it 'includes short name' do
      get '/manifest.json'
      manifest = JSON.parse(last_response.body)
      expect(manifest['short_name']).to eq('Memes')
    end
    
    it 'includes start URL' do
      get '/manifest.json'
      manifest = JSON.parse(last_response.body)
      expect(manifest['start_url']).to eq('/')
    end
    
    it 'includes display mode' do
      get '/manifest.json'
      manifest = JSON.parse(last_response.body)
      expect(manifest['display']).to eq('standalone')
    end
    
    it 'includes theme color' do
      get '/manifest.json'
      manifest = JSON.parse(last_response.body)
      expect(manifest['theme_color']).to be_a(String)
    end
    
    it 'includes icons array' do
      get '/manifest.json'
      manifest = JSON.parse(last_response.body)
      expect(manifest['icons']).to be_an(Array)
      expect(manifest['icons'].length).to be > 0
    end
    
    it 'includes app categories' do
      get '/manifest.json'
      manifest = JSON.parse(last_response.body)
      expect(manifest['categories']).to include('entertainment')
    end
  end
  
  describe 'GET /opensearch.xml' do
    it 'returns XML content type' do
      get '/opensearch.xml'
      expect(last_response.content_type).to include('application/opensearchdescription+xml')
    end
    
    it 'returns 200 OK status' do
      get '/opensearch.xml'
      expect(last_response).to be_ok
    end
    
    it 'includes XML declaration' do
      get '/opensearch.xml'
      expect(last_response.body).to include('<?xml version="1.0" encoding="UTF-8"?>')
    end
    
    it 'includes OpenSearchDescription root element' do
      get '/opensearch.xml'
      expect(last_response.body).to include('<OpenSearchDescription')
    end
    
    it 'includes ShortName' do
      get '/opensearch.xml'
      expect(last_response.body).to include('<ShortName>Meme Explorer</ShortName>')
    end
    
    it 'includes Description' do
      get '/opensearch.xml'
      expect(last_response.body).to include('<Description>')
    end
    
    it 'includes search URL template' do
      get '/opensearch.xml'
      expect(last_response.body).to include('template=')
      expect(last_response.body).to include('/search?q={searchTerms}')
    end
    
    it 'includes Tags' do
      get '/opensearch.xml'
      expect(last_response.body).to include('<Tags>')
      expect(last_response.body).to include('memes')
    end
  end
  
  describe 'SEO Integration Tests' do
    it 'all SEO endpoints return successfully' do
      routes = [
        '/robots.txt',
        '/sitemap.xml',
        '/humans.txt',
        '/.well-known/security.txt',
        '/manifest.json',
        '/opensearch.xml'
      ]
      
      routes.each do |route|
        get route
        expect(last_response.status).to be_between(200, 299), 
          "#{route} failed with status #{last_response.status}"
      end
    end
    
    it 'content types are appropriate for each endpoint' do
      expectations = {
        '/robots.txt' => 'text/plain',
        '/sitemap.xml' => 'application/xml',
        '/humans.txt' => 'text/plain',
        '/.well-known/security.txt' => 'text/plain',
        '/manifest.json' => 'application/json',
        '/opensearch.xml' => 'xml'
      }
      
      expectations.each do |route, content_type|
        get route
        expect(last_response.content_type).to include(content_type),
          "#{route} has wrong content type: #{last_response.content_type}"
      end
    end
  end
  
end
