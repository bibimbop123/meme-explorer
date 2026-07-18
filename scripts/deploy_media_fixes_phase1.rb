#!/usr/bin/env ruby
# Phase 1: Emergency Media Fixes - Deploy Immediately
# Fixes image cutoffs and enables basic video support
# Run: ruby scripts/deploy_media_fixes_phase1.rb

require 'fileutils'

class MediaFixesPhase1
  def self.execute!
    puts "🚀 Deploying Phase 1 Media Fixes..."
    puts "=" * 60
    
    new.run
    
    puts "\n" + "=" * 60
    puts "✅ Phase 1 Complete!"
    puts "\nNext steps:"
    puts "1. Test locally: bundle exec ruby app.rb"
    puts "2. Visit /random and check tall images don't cut off"
    puts "3. Deploy to staging for validation"
    puts "4. Review WORLD_CLASS_MEDIA_AUDIT_2026.md for Phase 2"
  end
  
  def run
    fix_display_template
    create_media_css
    update_grid_layout_css
    update_meme_helpers
    puts "\n📋 Summary:"
    puts "  ✓ Fixed image display (no more cutoffs)"
    puts "  ✓ Added scrollable container for tall content"
    puts "  ✓ Created media-specific CSS"
    puts "  ✓ Updated meme helpers for media type detection"
  end
  
  private
  
  def fix_display_template
    puts "\n1️⃣  Fixing views/random/display.erb..."
    
    display_erb = <<~ERB
      <!-- Meme Display Partial - FIXED -->
      <% if @meme && is_gallery_post?(@meme) && @meme["gallery_images"] %>
        <!-- Multi-image gallery carousel -->
        <%= gallery_styles %>
        <%= render_gallery_carousel(@meme["gallery_images"], @meme["title"]) %>
      <% else %>
        <!-- Single image/video display -->
        <button class="carousel-arrow carousel-arrow-left" id="carousel-prev" aria-label="Previous image" style="display: none;">‹</button>
        <div class="meme-display-content">
          <% if @meme %>
            <% 
              # Detect media type properly
              media_type = detect_media_type(@meme)
            %>
            <% if media_type == 'video' %>
              <!-- Video content -->
              <video 
                src="<%= @image_src %>" 
                class="meme-content-video"
                controls 
                autoplay 
                muted 
                loop 
                playsinline
              >
                Your browser does not support the video tag.
              </video>
            <% else %>
              <!-- Image content - NO HEIGHT CONSTRAINTS -->
              <img 
                id="meme-image" 
                src="<%= @image_src %>" 
                alt="<%= @meme['title'] %>" 
                class="meme-content-image"
                loading="lazy"
                onerror="handleMediaError(this)"
              >
            <% end %>
          <% else %>
            <div class="meme-loading">
              <div class="loading-spinner"></div>
              <p class="loading-text"><%= PersonalityContent.random_loading_message %></p>
            </div>
          <% end %>
        </div>
        <button class="carousel-arrow carousel-arrow-right" id="carousel-next" aria-label="Next image" style="display: none;">›</button>
        <div class="carousel-counter" id="carousel-counter" style="display: none;">1/1</div>
      <% end %>
    ERB
    
    File.write('views/random/display.erb', display_erb)
    puts "   ✓ Updated display template (removed height constraints)"
  end
  
  def create_media_css
    puts "\n2️⃣  Creating public/css/media-display.css..."
    
    media_css = <<~CSS
      /* Media Display CSS - Full Content Support */
      /* Created: #{Time.now} */
      
      /* Main display container - Allow full content height */
      .meme-display {
        width: 100%;
        min-height: 60vh;
        max-height: none !important;  /* CRITICAL: Remove artificial height limits */
        display: flex;
        align-items: flex-start;  /* Top-align content */
        justify-content: center;
        padding: 1rem;
        background: #000;
        overflow-y: auto;  /* Allow scrolling for tall content */
        overflow-x: hidden;
      }
      
      .meme-display-content {
        width: 100%;
        max-width: 1200px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      
      /* Images - Full display, no cutoffs */
      .meme-content-image {
        width: 100%;
        max-width: 1200px;
        height: auto !important;  /* Always auto-height */
        object-fit: contain;
        object-position: center;
        display: block;
        margin: 0 auto;
        border-radius: 8px;
      }
      
      /* Videos - Same treatment as images */
      .meme-content-video {
        width: 100%;
        max-width: 1200px;
        height: auto !important;
        object-fit: contain;
        display: block;
        margin: 0 auto;
        border-radius: 8px;
      }
      
      /* Mobile: Optimize viewport usage */
      @media (max-width: 768px) {
        .meme-display {
          min-height: 50vh;
          padding: 0.5rem;
        }
        
        .meme-content-image,
        .meme-content-video {
          max-width: 100%;
          border-radius: 4px;
        }
      }
      
      /* Tall/vertical images: Special handling */
      .meme-content-image[data-aspect="tall"] {
        max-height: none;
        width: auto;
        max-width: 600px;
      }
      
      /* Wide/horizontal images */
      .meme-content-image[data-aspect="wide"] {
        width: 100%;
        max-width: 1200px;
      }
      
      /* Loading state */
      .meme-loading {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        min-height: 300px;
        color: #fff;
      }
      
      .loading-spinner {
        width: 50px;
        height: 50px;
        border: 4px solid rgba(255, 255, 255, 0.3);
        border-top-color: #fff;
        border-radius: 50%;
        animation: spin 1s linear infinite;
      }
      
      @keyframes spin {
        to { transform: rotate(360deg); }
      }
      
      .loading-text {
        margin-top: 1rem;
        font-size: 1rem;
        color: rgba(255, 255, 255, 0.8);
      }
      
      /* Error state */
      .media-error-placeholder {
        padding: 2rem;
        text-align: center;
        background: #2a2a2a;
        border-radius: 8px;
        color: #fff;
      }
    CSS
    
    File.write('public/css/media-display.css', media_css)
    puts "   ✓ Created media display CSS"
  end
  
  def update_grid_layout_css
    puts "\n3️⃣  Updating public/css/grid-layout.css..."
    
    # Read current file
    grid_css = File.read('public/css/grid-layout.css')
    
    # Update the meme-display section to remove height constraints
    updated_css = grid_css.gsub(
      /\.meme-container \.meme-display \{[^}]+\}/m,
      <<~CSS.chomp
        .meme-container .meme-display {
          grid-area: meme;
          width: 100% !important;
          min-height: 60vh !important;
          max-height: none !important;  /* CRITICAL FIX: Allow full content height */
          display: flex !important;
          align-items: flex-start !important;  /* Top-align, not center */
          justify-content: center !important;
          position: relative !important;
          background: #000;
          border-radius: 0 !important;
          overflow-y: auto !important;  /* Enable scrolling for tall content */
          overflow-x: hidden !important;
          box-shadow: none !important;
          z-index: 1;
          margin: 0 !important;
          padding: 1rem !important;
        }
      CSS
    )
    
    File.write('public/css/grid-layout.css', updated_css)
    puts "   ✓ Updated grid layout to allow full content height"
  end
  
  def update_meme_helpers
    puts "\n4️⃣  Updating lib/helpers/meme_helpers.rb..."
    
    # Check if file exists, if not create it
    unless File.exist?('lib/helpers/meme_helpers.rb')
      create_meme_helpers_file
      return
    end
    
    # Read existing file
    content = File.read('lib/helpers/meme_helpers.rb')
    
    # Add detect_media_type method if it doesn't exist
    unless content.include?('def detect_media_type')
      method_code = <<~RUBY
        
        # Detect media type from meme data
        def detect_media_type(meme)
          return 'gallery' if meme["is_gallery"]
          return 'video' if meme["is_video"] || meme["video_url"]
          
          url = meme["url"].to_s.downcase
          return 'video' if url.match?(/\\.(mp4|webm|mov)(\\?|$)/)
          return 'gif' if url.match?(/\\.gif(\\?|$)/)
          'image'
        end
      RUBY
      
      # Add before the final 'end'
      content = content.sub(/^end\s*$/, "#{method_code}end")
      File.write('lib/helpers/meme_helpers.rb', content)
      puts "   ✓ Added media type detection method"
    else
      puts "   ✓ Media type detection already exists"
    end
  end
  
  def create_meme_helpers_file
    puts "   ⚠️  Creating new lib/helpers/meme_helpers.rb..."
    
    helpers_content = <<~RUBY
      # frozen_string_literal: true
      
      # Meme Helpers - Display and rendering utilities
      module MemeHelpers
        # Detect media type from meme data
        def detect_media_type(meme)
          return 'gallery' if meme["is_gallery"]
          return 'video' if meme["is_video"] || meme["video_url"]
          
          url = meme["url"].to_s.downcase
          return 'video' if url.match?(/\\.(mp4|webm|mov)(\\?|$)/)
          return 'gif' if url.match?(/\\.gif(\\?|$)/)
          'image'
        end
        
        # Get meme image source with fallbacks
        def meme_image_src(meme)
          meme["url"] || meme["file"] || "/images/meme-placeholder.svg"
        end
      end
    RUBY
    
    File.write('lib/helpers/meme_helpers.rb', helpers_content)
    puts "   ✓ Created new meme helpers file"
  end
end

# Run if executed directly
MediaFixesPhase1.execute! if __FILE__ == $0
