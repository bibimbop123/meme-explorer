# frozen_string_literal: true

# Gallery Helpers - Handle multi-image Reddit posts
module GalleryHelpers
  # Extract all images from a Reddit gallery post
  def extract_gallery_images(post_data)
    return nil unless post_data
    
    images = []
    
    # Check for Reddit gallery
    if post_data["is_gallery"] && post_data["gallery_data"] && post_data["media_metadata"]
      gallery_items = post_data["gallery_data"]["items"] || []
      media_metadata = post_data["media_metadata"] || {}
      
      gallery_items.each do |item|
        media_id = item["media_id"]
        next unless media_id
        
        metadata = media_metadata[media_id]
        next unless metadata
        
        # Get highest quality image
        image_url = metadata.dig("s", "u") || metadata.dig("s", "gif") || metadata.dig("s", "mp4")
        next unless image_url
        
        # Decode HTML entities
        image_url = image_url.gsub("&amp;", "&")
        
        images << {
          "url" => image_url,
          "id" => media_id,
          "caption" => item["caption"] || "",
          "width" => metadata.dig("s", "x"),
          "height" => metadata.dig("s", "y")
        }
      end
    end
    
    images.empty? ? nil : images
  end
  
  # Check if a post has multiple images
  def is_gallery_post?(meme_data)
    return false unless meme_data.is_a?(Hash)
    meme_data["is_gallery"] == true || 
    (meme_data["gallery_images"] && meme_data["gallery_images"].size > 1)
  end
  
  # Render gallery HTML with carousel
  def render_gallery_carousel(gallery_images, meme_title = "Meme")
    return "" unless gallery_images && gallery_images.size > 0
    
    carousel_id = "gallery-#{SecureRandom.hex(4)}"
    
    html = %{
      <div class="gallery-carousel" id="#{carousel_id}">
        <div class="gallery-slides">
    }
    
    gallery_images.each_with_index do |image, index|
      active_class = index == 0 ? "active" : ""
      html += %{
        <div class="gallery-slide #{active_class}" data-index="#{index}">
          <img src="#{image['url']}" alt="#{meme_title} - Image #{index + 1}" loading="lazy">
          #{image['caption'] && image['caption'] != '' ? "<p class='gallery-caption'>#{image['caption']}</p>" : ""}
        </div>
      }
    end
    
    # Navigation buttons
    if gallery_images.size > 1
      html += %{
        </div>
        <button class="gallery-nav gallery-prev" aria-label="Previous image">‹</button>
        <button class="gallery-nav gallery-next" aria-label="Next image">›</button>
        <div class="gallery-indicators">
      }
      
      gallery_images.each_with_index do |_, index|
        active_class = index == 0 ? "active" : ""
        html += %{<span class="gallery-dot #{active_class}" data-index="#{index}"></span>}
      end
      
      html += "</div>"
    else
      html += "</div>"
    end
    
    html += %{
      <div class="gallery-counter">#{gallery_images.size > 1 ? "1 / #{gallery_images.size}" : ""}</div>
      </div>
    }
    
    html
  end
  
  # Gallery CSS styles
  def gallery_styles
    %{
      <style>
        .gallery-carousel {
          position: relative;
          width: 100%;
          max-width: 800px;
          margin: 0 auto;
          background: #000;
          border-radius: 8px;
          overflow: hidden;
          touch-action: pan-y pinch-zoom;
        }
        
        .gallery-slides {
          position: relative;
          width: 100%;
          height: auto;
          min-height: 400px;
          display: flex;
          overflow: hidden;
        }
        
        .gallery-slide {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          opacity: 0;
          transition: opacity 0.3s ease-in-out;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
        }
        
        .gallery-slide.active {
          opacity: 1;
          position: relative;
        }
        
        .gallery-slide img {
          width: 100%;
          height: auto;
          max-height: 600px;
          object-fit: contain;
        }
        
        .gallery-caption {
          padding: 0.75rem;
          background: rgba(0, 0, 0, 0.7);
          color: white;
          font-size: 0.9rem;
          text-align: center;
          width: 100%;
        }
        
        .gallery-nav {
          position: absolute;
          top: 50%;
          transform: translateY(-50%);
          background: rgba(0, 0, 0, 0.5);
          color: white;
          border: none;
          font-size: 2rem;
          padding: 1rem;
          cursor: pointer;
          z-index: 10;
          transition: background 0.2s;
          border-radius: 4px;
          width: 50px;
          height: 50px;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        
        .gallery-nav:hover {
          background: rgba(0, 0, 0, 0.8);
        }
        
        .gallery-prev {
          left: 10px;
        }
        
        .gallery-next {
          right: 10px;
        }
        
        .gallery-indicators {
          position: absolute;
          bottom: 15px;
          left: 50%;
          transform: translateX(-50%);
          display: flex;
          gap: 8px;
          z-index: 10;
        }
        
        .gallery-dot {
          width: 10px;
          height: 10px;
          border-radius: 50%;
          background: rgba(255, 255, 255, 0.5);
          cursor: pointer;
          transition: background 0.2s;
        }
        
        .gallery-dot.active {
          background: rgba(255, 255, 255, 1);
        }
        
        .gallery-counter {
          position: absolute;
          top: 15px;
          right: 15px;
          background: rgba(0, 0, 0, 0.7);
          color: white;
          padding: 0.5rem 1rem;
          border-radius: 20px;
          font-size: 0.9rem;
          z-index: 10;
        }
        
        /* Mobile optimizations */
        @media (max-width: 768px) {
          .gallery-carousel {
            border-radius: 0;
            max-width: 100%;
          }
          
          .gallery-slides {
            min-height: 300px;
          }
          
          .gallery-slide img {
            max-height: 500px;
          }
          
          .gallery-nav {
            padding: 0.75rem;
            font-size: 1.5rem;
            width: 40px;
            height: 40px;
          }
          
          .gallery-prev {
            left: 5px;
          }
          
          .gallery-next {
            right: 5px;
          }
        }
        
        /* Dark mode support */
        .dark-mode .gallery-caption {
          background: rgba(255, 255, 255, 0.1);
          color: #fff;
        }
      </style>
    }
  end
  
  # Gallery JavaScript for navigation
  def gallery_script
    %{
      <script>
        document.addEventListener('DOMContentLoaded', function() {
          const galleries = document.querySelectorAll('.gallery-carousel');
          
          galleries.forEach(gallery => {
            const slides = gallery.querySelectorAll('.gallery-slide');
            const prevBtn = gallery.querySelector('.gallery-prev');
            const nextBtn = gallery.querySelector('.gallery-next');
            const dots = gallery.querySelectorAll('.gallery-dot');
            const counter = gallery.querySelector('.gallery-counter');
            let currentSlide = 0;
            
            if (slides.length <= 1) return;
            
            function showSlide(index) {
              slides.forEach(slide => slide.classList.remove('active'));
              dots.forEach(dot => dot.classList.remove('active'));
              
              if (index >= slides.length) currentSlide = 0;
              if (index < 0) currentSlide = slides.length - 1;
              
              slides[currentSlide].classList.add('active');
              dots[currentSlide].classList.add('active');
              
              if (counter) {
                counter.textContent = `${currentSlide + 1} / ${slides.length}`;
              }
            }
            
            if (prevBtn) {
              prevBtn.addEventListener('click', () => {
                currentSlide--;
                showSlide(currentSlide);
              });
            }
            
            if (nextBtn) {
              nextBtn.addEventListener('click', () => {
                currentSlide++;
                showSlide(currentSlide);
              });
            }
            
            dots.forEach((dot, index) => {
              dot.addEventListener('click', () => {
                currentSlide = index;
                showSlide(currentSlide);
              });
            });
            
            // Touch/swipe support for mobile
            let touchStartX = 0;
            let touchEndX = 0;
            
            gallery.addEventListener('touchstart', e => {
              touchStartX = e.changedTouches[0].screenX;
            });
            
            gallery.addEventListener('touchend', e => {
              touchEndX = e.changedTouches[0].screenX;
              handleSwipe();
            });
            
            function handleSwipe() {
              if (touchEndX < touchStartX - 50) {
                // Swipe left - next
                currentSlide++;
                showSlide(currentSlide);
              }
              if (touchEndX > touchStartX + 50) {
                // Swipe right - prev
                currentSlide--;
                showSlide(currentSlide);
              }
            }
            
            // Keyboard navigation
            document.addEventListener('keydown', e => {
              if (e.key === 'ArrowLeft') {
                currentSlide--;
                showSlide(currentSlide);
              }
              if (e.key === 'ArrowRight') {
                currentSlide++;
                showSlide(currentSlide);
              }
            });
          });
        });
      </script>
    }
  end
end
