// Image Lazy Loading - Phase 2
// Lazy load meme images for better performance

(function() {
  'use strict';
  
  // Use native lazy loading if available, otherwise use Intersection Observer
  const supportsNativeLazyLoad = 'loading' in HTMLImageElement.prototype;
  
  if (supportsNativeLazyLoad) {
    console.log('[Image Lazy Load] Using native lazy loading');
    addNativeLazyLoading();
  } else if ('IntersectionObserver' in window) {
    console.log('[Image Lazy Load] Using Intersection Observer');
    addIntersectionObserver();
  } else {
    console.warn('[Image Lazy Load] No lazy loading support, loading all images');
  }
  
  // Add loading="lazy" to images
  function addNativeLazyLoading() {
    const images = document.querySelectorAll('img[data-src]');
    
    images.forEach(function(img) {
      img.src = img.dataset.src;
      img.loading = 'lazy';
      img.removeAttribute('data-src');
    });
  }
  
  // Use Intersection Observer for older browsers
  function addIntersectionObserver() {
    const config = {
      rootMargin: '50px 0px',
      threshold: 0.01
    };
    
    const imageObserver = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          const img = entry.target;
          
          if (img.dataset.src) {
            img.src = img.dataset.src;
            img.classList.add('loaded');
            img.removeAttribute('data-src');
            imageObserver.unobserve(img);
          }
        }
      });
    }, config);
    
    const images = document.querySelectorAll('img[data-src]');
    images.forEach(function(img) {
      imageObserver.observe(img);
    });
    
    console.log(`[Image Lazy Load] Observing ${images.length} images`);
  }
})();
