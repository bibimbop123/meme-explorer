/**
 * Enhanced Lazy Loading
 * Uses Intersection Observer for better performance
 */

(function() {
  'use strict';

  // Configuration
  const config = {
    rootMargin: '50px 0px', // Start loading 50px before entering viewport
    threshold: 0.01
  };

  // Track loaded images
  const loadedImages = new Set();

  // Create intersection observer
  const imageObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const img = entry.target;
        loadImage(img);
        observer.unobserve(img);
      }
    });
  }, config);

  // Load image function
  function loadImage(img) {
    const src = img.dataset.src || img.getAttribute('data-src');
    
    if (!src || loadedImages.has(src)) return;
    
    // For images with srcset
    const srcset = img.dataset.srcset || img.getAttribute('data-srcset');
    
    // Create new image to preload
    const tempImg = new Image();
    
    tempImg.onload = () => {
      img.src = src;
      if (srcset) img.srcset = srcset;
      img.classList.add('loaded');
      loadedImages.add(src);
      
      // Dispatch custom event
      img.dispatchEvent(new CustomEvent('imageLoaded', { 
        detail: { src: src, loadTime: performance.now() }
      }));
    };
    
    tempImg.onerror = () => {
      console.error('Failed to load image:', src);
      img.classList.add('error');
      
      // Use placeholder
      img.src = '/images/meme-placeholder.svg';
    };
    
    tempImg.src = src;
  }

  // Initialize lazy loading
  function initLazyLoad() {
    // Find all images with data-src attribute or loading="lazy"
    const lazyImages = document.querySelectorAll('img[data-src], img[loading="lazy"]');
    
    lazyImages.forEach(img => {
      // Add loading class for CSS transitions
      img.classList.add('lazy-loading');
      
      // Observe image
      imageObserver.observe(img);
    });
    
    if (lazyImages.length > 0) {
      console.log(`✅ Enhanced lazy loading initialized for ${lazyImages.length} images`);
    }
  }

  // Prefetch images for next meme
  function prefetchNextImage(url) {
    if (!url || loadedImages.has(url)) return;
    
    const link = document.createElement('link');
    link.rel = 'prefetch';
    link.as = 'image';
    link.href = url;
    document.head.appendChild(link);
    
    loadedImages.add(url);
  }

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initLazyLoad);
  } else {
    initLazyLoad();
  }

  // Re-initialize when new content is added (e.g., AJAX loads)
  const contentObserver = new MutationObserver((mutations) => {
    let hasNewImages = false;
    
    mutations.forEach(mutation => {
      mutation.addedNodes.forEach(node => {
        if (node.nodeType === 1) { // Element node
          if (node.tagName === 'IMG' || node.querySelector('img')) {
            hasNewImages = true;
          }
        }
      });
    });
    
    if (hasNewImages) {
      initLazyLoad();
    }
  });

  contentObserver.observe(document.body, {
    childList: true,
    subtree: true
  });

  // Export for external use
  window.LazyLoad = {
    init: initLazyLoad,
    prefetch: prefetchNextImage,
    isLoaded: (src) => loadedImages.has(src)
  };
})();
