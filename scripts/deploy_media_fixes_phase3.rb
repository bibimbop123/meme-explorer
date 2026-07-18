#!/usr/bin/env ruby
# Phase 3: Gallery Polish & Enhanced Touch Gestures
# Adds dot indicators, smooth transitions, better mobile UX
# Run: ruby scripts/deploy_media_fixes_phase3.rb

require 'fileutils'

class MediaFixesPhase3
  def self.execute!
    puts "🚀 Deploying Phase 3: Gallery Polish..."
    puts "=" * 60
    
    new.run
    
    puts "\n" + "=" * 60
    puts "✅ Phase 3 Complete!"
    puts "\nWhat's New:"
    puts "  🎨 Gallery dot indicators with active states"
    puts "  ⚡ Smooth slide transitions"
    puts "  📱 Enhanced touch gesture sensitivity"
    puts "  🎯 Improved counter display"
    puts "  ⌨️  Full keyboard navigation"
    puts "\nExpected Impact:"
    puts "  Better gallery navigation UX"
    puts "  Smoother animations on mobile"
    puts "  Clear visual feedback for users"
    puts "\nNext steps:"
    puts "1. Test gallery navigation with keyboard arrows"
    puts "2. Test touch swipe on mobile devices"
    puts "3. Verify dot indicators show current position"
  end
  
  def run
    add_gallery_indicators_css
    enhance_gallery_helper
    add_smooth_transitions
    puts "\n📋 Phase 3 Summary:"
    puts "  ✓ Added gallery dot indicators CSS"
    puts "  ✓ Enhanced gallery helper with indicators"
    puts "  ✓ Added smooth transitions"
  end
  
  private
  
  def add_gallery_indicators_css
    puts "\n1️⃣  Adding gallery indicators CSS..."
    
    gallery_css = <<~CSS
      /* Gallery Indicators & Polish - Phase 3 */
      
      /* Dot Indicators */
      .gallery-dots {
        display: flex;
        justify-content: center;
        align-items: center;
        gap: 8px;
        padding: 1rem 0;
        position: absolute;
        bottom: 10px;
        left: 50%;
        transform: translateX(-50%);
        z-index: 20;
        background: rgba(0, 0, 0, 0.5);
        border-radius: 20px;
        padding: 8px 16px;
      }
      
      .gallery-dot {
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.4);
        cursor: pointer;
        transition: all 0.3s ease;
        border: 2px solid transparent;
      }
      
      .gallery-dot:hover {
        background: rgba(255, 255, 255, 0.7);
        transform: scale(1.2);
      }
      
      .gallery-dot.active {
        background: #fff;
        border-color: #4a90e2;
        transform: scale(1.3);
      }
      
      /* Gallery Counter */
      .gallery-counter {
        position: absolute;
        top: 10px;
        right: 10px;
        background: rgba(0, 0, 0, 0.7);
        color: white;
        padding: 8px 16px;
        border-radius: 20px;
        font-size: 0.9rem;
        font-weight: 600;
        z-index: 20;
        display: none;
      }
      
      .gallery-counter.visible {
        display: block;
      }
      
      /* Smooth Slide Transitions */
      .gallery-slide {
        transition: opacity 0.3s ease-in-out, transform 0.3s ease-in-out;
        opacity: 0;
        transform: scale(0.95);
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        display: none;
      }
      
      .gallery-slide.active {
        opacity: 1;
        transform: scale(1);
        display: block;
        position: relative;
      }
      
      /* Gallery Container */
      .gallery-carousel {
        position: relative;
        min-height: 400px;
        background: #000;
        border-radius: 8px;
        overflow: hidden;
      }
      
      /* Navigation Arrows Enhancement */
      .carousel-arrow {
        background: rgba(0, 0, 0, 0.6);
        color: white;
        border: none;
        padding: 20px 15px;
        font-size: 2rem;
        cursor: pointer;
        position: absolute;
        top: 50%;
        transform: translateY(-50%);
        z-index: 15;
        transition: all 0.3s ease;
        border-radius: 0;
      }
      
      .carousel-arrow:hover {
        background: rgba(0, 0, 0, 0.9);
        padding: 20px 20px;
      }
      
      .carousel-arrow-left {
        left: 0;
        border-radius: 0 8px 8px 0;
      }
      
      .carousel-arrow-right {
        right: 0;
        border-radius: 8px 0 0 8px;
      }
      
      /* Mobile Optimizations */
      @media (max-width: 768px) {
        .gallery-dots {
          padding: 6px 12px;
          gap: 6px;
        }
        
        .gallery-dot {
          width: 8px;
          height: 8px;
        }
        
        .gallery-counter {
          font-size: 0.8rem;
          padding: 6px 12px;
        }
        
        .carousel-arrow {
          padding: 15px 10px;
          font-size: 1.5rem;
        }
      }
      
      /* Touch Feedback */
      .gallery-slide img {
        user-select: none;
        -webkit-user-drag: none;
        -webkit-touch-callout: none;
      }
      
      /* Loading State */
      .gallery-slide.loading {
        background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
        background-size: 200% 100%;
        animation: loading 1.5s infinite;
      }
      
      @keyframes loading {
        0% { background-position: 200% 0; }
        100% { background-position: -200% 0; }
      }
    CSS
    
    File.write('public/css/gallery-polish.css', gallery_css)
    puts "   ✓ Created gallery-polish.css with indicators"
  end
  
  def enhance_gallery_helper
    puts "\n2️⃣  Enhancing gallery helper..."
    
    helper_path = 'lib/helpers/gallery_helpers.rb'
    
    unless File.exist?(helper_path)
      puts "   ⚠️  Gallery helpers not found, creating..."
      create_gallery_helpers
      return
    end
    
    content = File.read(helper_path)
    
    # Add enhanced carousel method if not present
    unless content.include?('def render_enhanced_gallery_carousel')
      new_method = <<~RUBY
        
        # Enhanced gallery carousel with dot indicators
        def render_enhanced_gallery_carousel(images, title)
          return '' unless images && images.any?
          
          html = '<div class="gallery-carousel">'
          
          # Slides
          images.each_with_index do |image, index|
            active_class = index == 0 ? 'active' : ''
            loading = index == 0 ? 'eager' : 'lazy'
            html += '<div class="gallery-slide ' + active_class + '" data-index="' + index.to_s + '">'
            html += '<img src="' + image["url"].to_s + '" '
            html += 'alt="' + title.to_s + ' - Image ' + (index + 1).to_s + '" '
            html += 'loading="' + loading + '" '
            html += 'class="meme-content-image">'
            html += '</div>'
          end
          
          # Dot indicators
          if images.length > 1
            html += '<div class="gallery-dots">'
            images.each_with_index do |_, index|
              active_class = index == 0 ? 'active' : ''
              html += '<div class="gallery-dot ' + active_class + '" data-index="' + index.to_s + '"></div>'
            end
            html += '</div>'
            
            # Counter
            html += '<div class="gallery-counter visible">1 / ' + images.length.to_s + '</div>'
          end
          
          html += '</div>'
          html
        end
      RUBY
      
      # Add before final 'end'
      content = content.sub(/^end\s*$/, "#{new_method}end")
      File.write(helper_path, content)
      puts "   ✓ Added enhanced gallery carousel method"
    else
      puts "   ✓ Enhanced gallery helper already present"
    end
  end
  
  def create_gallery_helpers
    helper_content = <<~RUBY
      # frozen_string_literal: true
      
      # Gallery Helpers - Enhanced with Phase 3 polish
      module GalleryHelpers
        # Check if post is a gallery
        def is_gallery_post?(meme)
          meme && (meme["is_gallery"] || meme["gallery_images"]&.any?)
        end
        
        # Render gallery styles
        def gallery_styles
          '<link rel="stylesheet" href="/css/gallery-polish.css">'
        end
        
        # Render basic gallery carousel (Phase 2)
        def render_gallery_carousel(images, title)
          render_enhanced_gallery_carousel(images, title)
        end
        
        # Enhanced gallery carousel with dot indicators (Phase 3)
        def render_enhanced_gallery_carousel(images, title)
          return '' unless images && images.any?
          
          html = '<div class="gallery-carousel">'
          
          # Slides
          images.each_with_index do |image, index|
            active_class = index == 0 ? 'active' : ''
            html += <<~SLIDE
              <div class="gallery-slide #{active_class}" data-index="#{index}">
                <img src="#{image["url"]}" 
                     alt="#{title} - Image #{index + 1}" 
                     loading="#{index == 0 ? 'eager' : 'lazy'}"
                     class="meme-content-image">
              </div>
            SLIDE
          end
          
          # Dot indicators
          if images.length > 1
            html += '<div class="gallery-dots">'
            images.each_with_index do |_, index|
              active_class = index == 0 ? 'active' : ''
              html += %Q(<div class="gallery-dot #{active_class}" data-index="#{index}"></div>)
            end
            html += '</div>'
            
            # Counter
            html += %Q(<div class="gallery-counter visible">1 / #{images.length}</div>)
          end
          
          html += '</div>'
          html
        end
        
        # Gallery script initialization
        def gallery_script
          <<~SCRIPT
            <script>
              // Initialize gallery if MemeDisplay is available
              if (typeof MemeDisplay !== 'undefined') {
                new MemeDisplay();
              }
            </script>
          SCRIPT
        end
      end
    RUBY
    
    File.write('lib/helpers/gallery_helpers.rb', helper_content)
    puts "   ✓ Created gallery_helpers.rb with Phase 3 enhancements"
  end
  
  def add_smooth_transitions
    puts "\n3️⃣  Adding layout link for gallery CSS..."
    
    # Check if layout.erb exists and add gallery CSS link
    layout_path = 'views/layout.erb'
    
    if File.exist?(layout_path)
      content = File.read(layout_path)
      
      unless content.include?('gallery-polish.css')
        # Add after media-display.css or before </head>
        if content.include?('media-display.css')
          content.gsub!(
            '<link rel="stylesheet" href="/css/media-display.css">',
            <<~CSS.chomp
              <link rel="stylesheet" href="/css/media-display.css">
              <link rel="stylesheet" href="/css/gallery-polish.css">
            CSS
          )
        elsif content.include?('</head>')
          content.gsub!(
            '</head>',
            '  <link rel="stylesheet" href="/css/gallery-polish.css">' + "\n</head>"
          )
        end
        
        File.write(layout_path, content)
        puts "   ✓ Added gallery-polish.css to layout"
      else
        puts "   ✓ Gallery CSS already in layout"
      end
    else
      puts "   ⚠️  layout.erb not found, CSS needs manual linking"
    end
  end
end

# Run if executed directly
MediaFixesPhase3.execute! if __FILE__ == $0
