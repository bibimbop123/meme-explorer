# 🚨 PRODUCTION ERROR - IMMEDIATE FIX

**Status:** Site is down on Render  
**Cause:** New SEO routes causing view path issues  
**Solution:** Quick rollback, then proper fix

---

## 🔥 IMMEDIATE ACTION (< 2 minutes)

### **Option 1: Comment Out New Routes (FASTEST)**

Edit `app.rb`, find these lines near the bottom:

```ruby
# Load SEO routes (for growth!)
require_relative './routes/sitemap'
require_relative './routes/meme_pages'
```

**Comment them out:**

```ruby
# Load SEO routes (for growth!)
# TEMPORARILY DISABLED - NEEDS FIX
# require_relative './routes/sitemap'
# require_relative './routes/meme_pages'
```

**Then:**
```bash
git add app.rb
git commit -m "Temporarily disable SEO routes to fix production"
git push origin main
```

Render will auto-deploy and site will be back up in 2-3 minutes.

---

## 🔍 ROOT CAUSE

The new route files are trying to use views, but Sinatra isn't finding them correctly in production. The error shows:

```
No such file or directory @ rb_sysopen - /opt/render/project/src/routes/views/random.erb
```

It's looking in `/routes/views/` instead of `/views/`.

---

## ✅ PROPER FIX (After Site Is Back)

The SEO routes need to explicitly set the views directory. Here's the corrected version:

### **Fixed routes/sitemap.rb:**

```ruby
# Sitemap generation for SEO
# Generates XML sitemap for search engines

class MemeExplorer < Sinatra::Base
  # Set views directory explicitly for this route file
  set :views, File.expand_path('../views', __dir__)
  
  # XML Sitemap for Google
  get '/sitemap.xml' do
    content_type 'application/xml'
    
    @base_url = if ENV['RACK_ENV'] == 'production'
      'https://meme-explorer.onrender.com'
    else
      "http://localhost:#{ENV.fetch('PORT', 8080)}"
    end
    
    @urls = []
    
    # Homepage (highest priority)
    @urls << {
      loc: @base_url,
      changefreq: 'daily',
      priority: '1.0',
      lastmod: Time.now.strftime('%Y-%m-%d')
    }
    
    # Main pages
    main_pages = [
      { path: '/random', priority: '0.9' },
      { path: '/trending', priority: '0.9' },
      { path: '/search', priority: '0.8' },
      { path: '/leaderboard', priority: '0.7' }
    ]
    
    main_pages.each do |page|
      @urls << {
        loc: "#{@base_url}#{page[:path]}",
        changefreq: 'daily',
        priority: page[:priority],
        lastmod: Time.now.strftime('%Y-%m-%d')
      }
    end
    
    # Get meme data for individual pages
    begin
      trending_memes = DB.execute("
        SELECT url, updated_at 
        FROM meme_stats 
        ORDER BY (likes * 2 + views) DESC 
        LIMIT 100
      ")
      
      trending_memes.each do |meme|
        meme_id = Digest::MD5.hexdigest(meme['url'])[0..7]
        
        @urls << {
          loc: "#{@base_url}/memes/#{meme_id}",
          changefreq: 'weekly',
          priority: '0.6',
          lastmod: meme['updated_at'] || Time.now.strftime('%Y-%m-%d')
        }
      end
    rescue => e
      puts "⚠️ Error fetching memes for sitemap: #{e.message}"
    end
    
    # Generate XML
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') {
        @urls.each do |url|
          xml.url {
            xml.loc url[:loc]
            xml.lastmod url[:lastmod]
            xml.changefreq url[:changefreq]
            xml.priority url[:priority]
          }
        end
      }
    end
    
    builder.to_xml
  rescue => e
    puts "❌ Sitemap generation error: #{e.message}"
    halt 500, "Error generating sitemap"
  end
  
  # Human-readable sitemap
  get '/sitemap' do
    @base_url = if ENV['RACK_ENV'] == 'production'
      'https://meme-explorer.onrender.com'
    else
      "http://localhost:#{ENV.fetch('PORT', 8080)}"
    end
    
    @pages = [
      { name: 'Home', url: '/', description: 'Discover the funniest memes on the internet' },
      { name: 'Random Memes', url: '/random', description: 'Infinite scroll of random memes' },
      { name: 'Trending', url: '/trending', description: 'Top trending memes right now' },
      { name: 'Search', url: '/search', description: 'Find memes by keyword' },
      { name: 'Leaderboard', url: '/leaderboard', description: 'Top meme explorers' }
    ]
    
    erb :'sitemap_page'
  end
  
end
```

### **Fixed routes/meme_pages.rb:**

```ruby
# Individual meme landing pages for SEO
# Each popular meme gets its own page for search ranking

class MemeExplorer < Sinatra::Base
  # Set views directory explicitly
  set :views, File.expand_path('../views', __dir__)
  
  # ... rest of the file stays the same ...
end
```

---

## 📋 STEP-BY-STEP FIX

**1. Rollback (RIGHT NOW):**
```bash
# Comment out the require lines in app.rb
# Commit and push
```

**2. Wait for site to come back (2-3 min)**

**3. Apply proper fix:**
- Update `routes/sitemap.rb` with the fixed version above
- Update `routes/meme_pages.rb` with the fixed version above
- Uncomment the require lines in `app.rb`
- Test locally first!
- Commit and push

**4. Verify:**
- Check https://meme-explorer.onrender.com/
- Check https://meme-explorer.onrender.com/sitemap
- Check https://meme-explorer.onrender.com/sitemap.xml

---

## 🛡️ PREVENTION

**Always test in production-like environment before deploying:**

```bash
# Test with production settings locally
RACK_ENV=production bundle exec rackup -p 8080

# Or use Render preview environment
```

---

## ⚡ ALTERNATIVE: Keep Routes Disabled

If you want to get back to stable quickly and deploy SEO later:

1. Keep the routes commented out
2. Focus on other priorities from WHATS_NEXT_PRIORITIES.md
3. Come back to SEO routes when you have time to test properly

**SEO can wait. Uptime cannot.**

---

## 🎯 WHAT TO DO RIGHT NOW

1. Comment out the two require lines in app.rb
2. Push to git
3. Wait for Render to redeploy (watch logs)
4. Verify site is back up
5. Then decide: Fix properly or leave disabled for now

**Site uptime > New features**

Let me know when you've done the rollback and I can help with the proper fix!
