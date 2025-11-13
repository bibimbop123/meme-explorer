// Gallery Carousel - Multi-image post navigation
// Handles: touch gestures, arrow navigation, keyboard shortcuts, lazy loading

class ImageCarousel {
  constructor(containerSelector = '.meme-display', options = {}) {
    this.container = document.querySelector(containerSelector);
    this.currentIndex = 0;
    this.isAnimating = false;
    this.images = [];
    this.memeUrl = null;
    this.postUrl = null;
    
    // Options
    this.autoPreload = options.autoPreload !== false;
    this.slideSpeed = options.slideSpeed || 400;
    this.onIndexChange = options.onIndexChange || (() => {});
    
    // Touch handling
    this.touchStartX = 0;
    this.touchEndX = 0;
    this.touchStartTime = 0;
    
    this.init();
  }
  
  // Initialize carousel
  init() {
    console.log('🎬 [CAROUSEL] Initializing...');
    this.setupDOM();
    this.attachEventListeners();
    this.createDots();
    console.log('✅ [CAROUSEL] Ready');
  }
  
  // Setup carousel DOM structure
  setupDOM() {
    if (!this.container) return;
    
    const wrapper = document.createElement('div');
    wrapper.className = 'image-carousel-wrapper';
    wrapper.innerHTML = `
      <div class="carousel-track"></div>
    `;
    this.container.innerHTML = '';
    this.container.appendChild(wrapper);
    
    this.track = wrapper.querySelector('.carousel-track');
  }
  
  // Create indicator dots
  createDots() {
    if (this.images.length <= 1) return;
    
    // Remove existing indicators
    document.querySelectorAll('.gallery-indicator-container').forEach(el => el.remove());
    document.querySelectorAll('.gallery-counter').forEach(el => el.remove());
    
    const container = document.createElement('div');
    container.className = 'gallery-indicator-container';
    
    this.images.forEach((_, idx) => {
      const dot = document.createElement('button');
      dot.className = `gallery-dot ${idx === 0 ? 'active' : ''}`;
      dot.addEventListener('click', () => this.goToSlide(idx));
      container.appendChild(dot);
    });
    
    document.body.appendChild(container);
    
    // Counter
    const counter = document.createElement('div');
    counter.className = 'gallery-counter';
    counter.hidden = true;
    counter.id = 'gallery-counter';
    counter.textContent = `1/${this.images.length}`;
    document.body.appendChild(counter);
  }
  
  // Create navigation arrows
  createArrows() {
    if (this.images.length <= 1) return;
    
    // Remove existing arrows
    document.querySelectorAll('.gallery-nav-btn').forEach(el => el.remove());
    
    const prevBtn = document.createElement('button');
    prevBtn.className = 'gallery-nav-btn prev';
    prevBtn.innerHTML = '←';
    prevBtn.addEventListener('click', () => this.prev());
    
    const nextBtn = document.createElement('button');
    nextBtn.className = 'gallery-nav-btn next';
    nextBtn.innerHTML = '→';
    nextBtn.addEventListener('click', () => this.next());
    
    document.body.appendChild(prevBtn);
    document.body.appendChild(nextBtn);
    
    this.prevBtn = prevBtn;
    this.nextBtn = nextBtn;
    this.updateArrowState();
  }
  
  // Load gallery images
  async loadGallery(memeUrl, postUrl) {
    this.memeUrl = memeUrl;
    this.postUrl = postUrl;
    
    try {
      console.log(`🔄 [CAROUSEL] Loading gallery for: ${memeUrl}`);
      
      const encodedUrl = encodeURIComponent(memeUrl);
      const response = await fetch(`/api/meme/${encodedUrl}/gallery`);
      
      if (!response.ok) {
        console.warn('⚠️ [CAROUSEL] Gallery not found, single image mode');
        return false;
      }
      
      const data = await response.json();
      
      if (!data.images || data.images.length === 0) {
        console.log('ℹ️ [CAROUSEL] No gallery images');
        return false;
      }
      
      this.images = data.images;
      this.isGallery = data.is_gallery;
      this.totalImages = data.total_images;
      
      console.log(`✅ [CAROUSEL] Loaded ${this.images.length} images`);
      
      this.renderSlides();
      this.createArrows();
      this.createDots();
      this.attachGestureHandlers();
      
      return true;
    } catch (e) {
      console.error('❌ [CAROUSEL] Error loading gallery:', e);
      return false;
    }
  }
  
  // Render carousel slides
  renderSlides() {
    this.track.innerHTML = '';
    
    this.images.forEach((img, idx) => {
      const slide = document.createElement('div');
      slide.className = 'carousel-slide';
      slide.dataset.index = idx;
      
      const isVideo = img.type === 'video';
      const media = document.createElement(isVideo ? 'video' : 'img');
      
      if (isVideo) {
        media.src = img.url;
        media.controls = false;
        media.autoplay = idx === 0;
        media.muted = true;
        media.loop = true;
      } else {
        media.src = img.url;
        media.alt = `Image ${idx + 1}`;
        media.onerror = () => this.handleImageError(idx);
      }
      
      slide.appendChild(media);
      this.track.appendChild(slide);
    });
    
    console.log(`✅ [CAROUSEL] Rendered ${this.images.length} slides`);
  }
  
  // Attach event listeners
  attachEventListeners() {
    if (!this.container) return;
    
    // Keyboard navigation
    document.addEventListener('keydown', (e) => {
      if (this.images.length <= 1) return;
      
      if (e.key === 'ArrowLeft' && document.activeElement.tagName !== 'INPUT') {
        e.preventDefault();
        this.prev();
      } else if (e.key === 'ArrowRight' && document.activeElement.tagName !== 'INPUT') {
        e.preventDefault();
        this.next();
      }
    });
  }
  
  // Gesture handling for touch/swipe
  attachGestureHandlers() {
    if (!this.track) return;
    
    this.track.addEventListener('touchstart', (e) => {
      this.touchStartX = e.touches[0].clientX;
      this.touchStartTime = Date.now();
    }, { passive: true });
    
    this.track.addEventListener('touchend', (e) => {
      this.touchEndX = e.changedTouches[0].clientX;
      const duration = Date.now() - this.touchStartTime;
      const distance = Math.abs(this.touchStartX - this.touchEndX);
      
      // Minimum swipe distance and max duration
      if (distance > 30 && duration < 500) {
        if (this.touchStartX - this.touchEndX > 0) {
          // Swiped left = next image
          this.next();
        } else {
          // Swiped right = prev image
          this.prev();
        }
      }
    }, { passive: true });
  }
  
  // Go to specific slide
  goToSlide(index, direction = 'auto') {
    if (this.isAnimating || index === this.currentIndex) return;
    if (index < 0 || index >= this.images.length) return;
    
    this.isAnimating = true;
    
    const distance = index - this.currentIndex;
    const isForward = distance > 0;
    
    const offset = -index * 100;
    this.track.style.transform = `translateX(${offset}%)`;
    
    setTimeout(() => {
      this.currentIndex = index;
      this.isAnimating = false;
      this.updateDots();
      this.updateArrowState();
      this.updateCounter();
      this.onIndexChange(index, this.images[index]);
      
      if (this.autoPreload && index < this.images.length - 1) {
        this.preloadImage(index + 1);
      }
    }, this.slideSpeed);
  }
  
  // Next slide
  next() {
    if (this.currentIndex < this.images.length - 1) {
      this.goToSlide(this.currentIndex + 1, 'forward');
    }
  }
  
  // Previous slide
  prev() {
    if (this.currentIndex > 0) {
      this.goToSlide(this.currentIndex - 1, 'backward');
    }
  }
  
  // Update dot indicators
  updateDots() {
    document.querySelectorAll('.gallery-dot').forEach((dot, idx) => {
      dot.classList.toggle('active', idx === this.currentIndex);
    });
  }
  
  // Update arrow button states
  updateArrowState() {
    if (!this.prevBtn || !this.nextBtn) return;
    
    this.prevBtn.classList.toggle('disabled', this.currentIndex === 0);
    this.nextBtn.classList.toggle('disabled', this.currentIndex === this.images.length - 1);
  }
  
  // Update counter text
  updateCounter() {
    const counter = document.getElementById('gallery-counter');
    if (counter) {
      counter.textContent = `${this.currentIndex + 1}/${this.images.length}`;
    }
  }
  
  // Preload image
  preloadImage(index) {
    if (index < 0 || index >= this.images.length) return;
    
    const img = new Image();
    img.src = this.images[index].url;
  }
  
  // Handle image error
  handleImageError(index) {
    console.warn(`⚠️ [CAROUSEL] Image ${index} failed to load`);
    // Fallback: try to load next image
    if (index < this.images.length - 1) {
      setTimeout(() => this.next(), 500);
    }
  }
  
  // Get current image
  getCurrentImage() {
    return this.images[this.currentIndex];
  }
  
  // Get total slide count
  getTotalSlides() {
    return this.images.length;
  }
  
  // Destroy carousel
  destroy() {
    console.log('🧹 [CAROUSEL] Destroying...');
    this.track = null;
    this.images = [];
    document.querySelectorAll('.gallery-indicator-container').forEach(el => el.remove());
    document.querySelectorAll('.gallery-nav-btn').forEach(el => el.remove());
    document.querySelectorAll('.gallery-counter').forEach(el => el.remove());
  }
}

// Export for use in global scope
window.ImageCarousel = ImageCarousel;
