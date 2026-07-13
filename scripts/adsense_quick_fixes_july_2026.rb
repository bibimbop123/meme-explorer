#!/usr/bin/env ruby
# frozen_string_literal: true

# AdSense Quick Fixes - Critical Path to Approval
# Run this to check current content status and create necessary infrastructure

require 'yaml'
require 'fileutils'

class AdsenseQuickFixes
  def run
    puts "\n🔍 ADSENSE AUDIT - CRITICAL ISSUES CHECK\n"
    puts "=" * 60
    
    check_guide_content
    check_blog_infrastructure
    check_meme_page_enhancements
    check_navigation_links
    
    puts "\n" + "=" * 60
    puts "📊 SUMMARY & NEXT STEPS\n"
    show_summary
  end
  
  private
  
  def check_guide_content
    puts "\n1️⃣  CHECKING GUIDE CONTENT (P0 - CRITICAL)"
    puts "-" * 60
    
    guide_files = Dir.glob('views/guides/*.erb')
    insufficient_guides = []
    
    guide_files.each do |file|
      content = File.read(file)
      # Remove HTML tags and count words
      text_only = content.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ')
      word_count = text_only.split.length
      
      filename = File.basename(file)
      status = word_count >= 1500 ? "✅" : "❌"
      
      puts "#{status} #{filename}: #{word_count} words"
      
      if word_count < 1500
        insufficient_guides << {
          file: filename,
          current: word_count,
          needed: 1500 - word_count
        }
      end
    end
    
    if insufficient_guides.empty?
      puts "\n✅ All guides meet minimum word count!"
    else
      puts "\n⚠️  WARNING: #{insufficient_guides.length} guides need more content"
      insufficient_guides.each do |guide|
        puts "   - #{guide[:file]}: Need #{guide[:needed]} more words"
      end
    end
  end
  
  def check_blog_infrastructure
    puts "\n2️⃣  CHECKING BLOG SYSTEM (P1 - HIGH PRIORITY)"
    puts "-" * 60
    
    blog_route = File.exist?('routes/blog_routes.rb')
    blog_views = Dir.exist?('views/blog')
    blog_data = Dir.exist?('data/blog_posts')
    
    puts "#{blog_route ? '✅' : '❌'} Blog routes file (routes/blog_routes.rb)"
    puts "#{blog_views ? '✅' : '❌'} Blog views directory (views/blog/)"
    puts "#{blog_data ? '✅' : '❌'} Blog data directory (data/blog_posts/)"
    
    unless blog_route && blog_views && blog_data
      puts "\n⚠️  Blog system not complete. Creating infrastructure..."
      create_blog_infrastructure
    end
  end
  
  def check_meme_page_enhancements
    puts "\n3️⃣  CHECKING MEME PAGE ENHANCEMENTS (P0 - CRITICAL)"
    puts "-" * 60
    
    meme_page = File.read('views/meme_page.erb')
    
    has_commentary = meme_page.include?('curator-analysis') || 
                     meme_page.include?('curator_commentary')
    has_context = meme_page.include?('cultural_context') || 
                  meme_page.include?('Cultural Context')
    has_attribution = meme_page.include?('Original Source') || 
                      meme_page.include?('permalink')
    
    puts "#{has_commentary ? '✅' : '❌'} Curator commentary section"
    puts "#{has_context ? '✅' : '❌'} Cultural context section"
    puts "#{has_attribution ? '✅' : '❌'} Proper attribution to Reddit"
    
    unless has_commentary && has_context && has_attribution
      puts "\n⚠️  Meme pages need value-add content sections"
    end
  end
  
  def check_navigation_links
    puts "\n4️⃣  CHECKING NAVIGATION (P1 - IMPORTANT)"
    puts "-" * 60
    
    layout = File.read('views/layout.erb')
    
    has_blog_link = layout.include?('href="/blog"')
    has_guides_link = layout.include?('href="/guides"')
    has_about_visible = layout.include?('href="/about"')
    
    puts "#{has_blog_link ? '✅' : '❌'} Blog link in navigation"
    puts "#{has_guides_link ? '✅' : '❌'} Guides link in navigation"
    puts "#{has_about_visible ? '✅' : '❌'} About link visible in navigation"
    
    unless has_blog_link
      puts "\n⚠️  Add blog link to navigation for visibility"
    end
  end
  
  def create_blog_infrastructure
    puts "\n   Creating blog infrastructure..."
    
    # Create directories
    FileUtils.mkdir_p('views/blog')
    FileUtils.mkdir_p('data/blog_posts')
    
    # Create blog routes file
    unless File.exist?('routes/blog_routes.rb')
      File.write('routes/blog_routes.rb', <<~RUBY)
        # frozen_string_literal: true
        
        # Blog Routes - Original Content for AdSense
        module Routes
          module Blog
            def self.registered(app)
              app.get '/blog' do
                @posts = Dir.glob('data/blog_posts/*.yml').map do |file|
                  YAML.load_file(file)
                end.sort_by { |p| p['published_at'] }.reverse
                
                erb :'blog/index'
              end
              
              app.get '/blog/:slug' do
                @post = YAML.load_file("data/blog_posts/\#{params[:slug]}.yml")
                erb :'blog/post'
              rescue Errno::ENOENT
                halt 404, "Blog post not found"
              end
            end
          end
        end
      RUBY
      puts "   ✅ Created routes/blog_routes.rb"
    end
    
    # Create blog index view
    unless File.exist?('views/blog/index.erb')
      File.write('views/blog/index.erb', <<~ERB)
        <div class="blog-index">
          <h1>📝 Meme Culture Blog</h1>
          <p class="tagline">Expert insights on internet culture, meme formats, and digital humor</p>
          
          <div class="blog-posts">
            <% @posts.each do |post| %>
              <article class="blog-card">
                <h2><a href="/blog/<%= post['slug'] %>"><%= post['title'] %></a></h2>
                <div class="meta">
                  <span>📅 <%= post['published_at'] %></span>
                  <span>📖 <%= post['word_count'] %> words</span>
                  <span>⏱️ <%= (post['word_count'] / 200.0).ceil %> min read</span>
                </div>
                <p><%= post['excerpt'] %></p>
                <a href="/blog/<%= post['slug'] %>" class="read-more">Read More →</a>
              </article>
            <% end %>
          </div>
        </div>
        
        <style>
          .blog-index { max-width: 900px; margin: 2rem auto; padding: 2rem; }
          .blog-card { 
            background: white; 
            padding: 2rem; 
            margin: 2rem 0; 
            border-radius: 8px; 
            box-shadow: 0 2px 8px rgba(0,0,0,0.1); 
          }
          .blog-card h2 a { color: #667eea; text-decoration: none; }
          .blog-card h2 a:hover { text-decoration: underline; }
          .meta { color: #666; font-size: 0.9rem; margin: 1rem 0; }
          .meta span { margin-right: 1rem; }
          .read-more { 
            color: #667eea; 
            font-weight: 600; 
            text-decoration: none; 
          }
        </style>
      ERB
      puts "   ✅ Created views/blog/index.erb"
    end
    
    # Create blog post view
    unless File.exist?('views/blog/post.erb')
      File.write('views/blog/post.erb', <<~ERB)
        <article class="blog-post">
          <header>
            <h1><%= @post['title'] %></h1>
            <div class="meta">
              <span>📅 <%= @post['published_at'] %></span>
              <span>✍️ <%= @post['author'] %></span>
              <span>📖 <%= @post['word_count'] %> words</span>
            </div>
          </header>
          
          <div class="content">
            <%= @post['content'] %>
          </div>
          
          <footer>
            <a href="/blog">← Back to Blog</a>
          </footer>
        </article>
        
        <style>
          .blog-post { max-width: 800px; margin: 2rem auto; padding: 2rem; }
          .blog-post header { margin-bottom: 3rem; }
          .blog-post h1 { font-size: 2.5rem; margin-bottom: 1rem; }
          .blog-post .meta { color: #666; }
          .blog-post .content { line-height: 1.8; font-size: 1.1rem; }
          .blog-post .content h2 { margin-top: 2rem; color: #667eea; }
          .blog-post .content p { margin: 1.5rem 0; }
        </style>
      ERB
      puts "   ✅ Created views/blog/post.erb"
    end
    
    # Create sample blog post
    create_sample_blog_post
    
    puts "   ✅ Blog infrastructure created!"
    puts "   📝 NEXT: Write 3-4 blog posts (2000+ words each)"
  end
  
  def create_sample_blog_post
    sample_post = {
      'slug' => 'quality-meme-curation-system',
      'title' => 'How We Built a Quality Meme Curation System',
      'author' => 'Meme Explorer Editorial Team',
      'published_at' => Date.today.to_s,
      'updated_at' => Date.today.to_s,
      'word_count' => 2100,
      'excerpt' => 'An in-depth look at our 6-stage quality pipeline that ensures only the best memes reach our users. Learn about algorithmic filtering, community signals, and expert curation.',
      'content' => <<~CONTENT
        <h2>Introduction</h2>
        <p>At Meme Explorer, quality isn't an accident—it's a carefully engineered outcome of our sophisticated curation pipeline...</p>
        
        <h2>The Challenge of Meme Aggregation</h2>
        <p>Reddit produces millions of posts daily across thousands of communities...</p>
        
        <h2>Our 6-Stage Quality Pipeline</h2>
        
        <h3>Stage 1: Source Selection</h3>
        <p>We carefully curate which subreddits we pull from...</p>
        
        <h3>Stage 2: Initial Filtering</h3>
        <p>Automated systems filter out NSFW content, spam, and low-quality submissions...</p>
        
        <h3>Stage 3: Engagement Analysis</h3>
        <p>We analyze community engagement signals including upvotes, comments, and awards...</p>
        
        <h3>Stage 4: Format Recognition</h3>
        <p>Our AI identifies meme formats and templates to ensure variety...</p>
        
        <h3>Stage 5: Quality Scoring</h3>
        <p>Each meme receives a composite quality score based on multiple factors...</p>
        
        <h3>Stage 6: Human Curation</h3>
        <p>Our team of curators reviews high-scoring memes for final approval...</p>
        
        <h2>Results and Impact</h2>
        <p>Since implementing this system, user engagement has increased by 300%...</p>
        
        <h2>Conclusion</h2>
        <p>Quality curation is what separates a great meme platform from mere aggregation...</p>
        
        <p><em>This is a SAMPLE post. Replace with actual 2000+ word content.</em></p>
      CONTENT
    }
    
    File.write('data/blog_posts/quality-meme-curation-system.yml', YAML.dump(sample_post))
    puts "   ✅ Created sample blog post"
  end
  
  def show_summary
    puts <<~SUMMARY
    
    📋 IMMEDIATE ACTION ITEMS:
    
    🔴 CRITICAL (Do These First):
    1. Review all guide pages - ensure each has 1500+ words
    2. Add curator commentary system to meme pages
    3. Add proper Reddit attribution to all meme pages
    
    🟡 HIGH PRIORITY (Do This Week):
    4. Write 4 blog posts (2000+ words each)
    5. Add blog link to main navigation
    6. Create "How We Curate" page
    
    📈 ADSENSE TIMELINE:
    - Content Creation: 2-3 weeks
    - Google Indexing: 1-2 weeks
    - Review Process: 1-2 weeks
    - TOTAL: 4-7 weeks to approval
    
    💡 TIP: Focus on demonstrating EXPERTISE, not just aggregation.
    Position as "meme culture educator" not "meme aggregator."
    
    📖 Read COMPREHENSIVE_ADSENSE_AUDIT_JULY_2026.md for full details.
    
    SUMMARY
  end
end

# Run the audit
AdsenseQuickFixes.new.run
