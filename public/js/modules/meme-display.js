/**
 * Meme Display Module
 * Handles image/video rendering and carousel functionality
 */

export class MemeDisplay {
  constructor() {
    this.currentIndex = 0;
    this.images = [];
    this.init();
  }
  
  init() {
    console.log('[MemeDisplay] Initializing...');
    this.bindCarouselControls();
    this.setupImageErrorHandling();
  }
  
  bindCarouselControls() {
    const prevBtn = document.getElementById('carousel-prev');
    const nextBtn = document.getElementById('carousel-next');
    
    if (prevBtn) {
      prevBtn.addEventListener('click', () => this.showPrevious());
    }
    
    if (nextBtn) {
      nextBtn.addEventListener('click', () => this.showNext());
    }
  }
  
  setupImageErrorHandling() {
    const memeImage = document.getElementById('meme-image');
    if (memeImage) {
      memeImage.addEventListener('error', () => this.handleImageError());
    }
  }
  
  showPrevious() {
    if (this.currentIndex > 0) {
      this.currentIndex--;
      this.updateDisplay();
    }
  }
  
  showNext() {
    if (this.currentIndex < this.images.length - 1) {
      this.currentIndex++;
      this.updateDisplay();
    }
  }
  
  updateDisplay() {
    // Update slide visibility
document.querySelectorAll('.gallery-slide').forEach((slide, index) => {
  slide.classList.toggle('active', index === this.currentIndex);
});

// Update dots
document.querySelectorAll('.gallery-dot').forEach((dot, index) => {
  dot.classList.toggle('active', index === this.currentIndex);
});

// Update counter
const counter = document.getElementById('carousel-counter') ||
               document.querySelector('.gallery-counter');
if (counter && this.images.length > 1) {
  counter.textContent = `${this.currentIndex + 1} / ${this.images.length}`;
  counter.style.display = 'block';
}

console.log(`[MemeDisplay] Showing image ${this.currentIndex + 1}/${this.images.length}`);
  }
  
  handleImageError() {
    console.warn('[MemeDisplay] Image failed to load');
    // TODO: Show placeholder image
    if (typeof window.showPlaceholder === 'function') {
      window.showPlaceholder();
    }
  }
}
