// Ad Lazy Loading - Phase 2
// Load ads only when they become visible using Intersection Observer

(function() {
  'use strict';
  
  // Check if Intersection Observer is supported
  if (!('IntersectionObserver' in window)) {
    console.warn('[Ad Lazy Load] Intersection Observer not supported, loading ads immediately');
    return;
  }
  
  // Configuration
  const config = {
    rootMargin: '50px 0px', // Load ads 50px before they come into view
    threshold: 0.01
  };
  
  // Create observer
  const observer = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting) {
        const adContainer = entry.target;
        
        // Load ad
        if (adContainer.dataset.adUnit && !adContainer.classList.contains('ad-loaded')) {
          loadAd(adContainer);
          observer.unobserve(adContainer); // Stop observing once loaded
        }
      }
    });
  }, config);
  
  // Find all ad containers and observe them
  function initLazyAds() {
    const adContainers = document.querySelectorAll('.ad-container[data-lazy="true"]');
    
    adContainers.forEach(function(container) {
      observer.observe(container);
    });
    
    console.log(`[Ad Lazy Load] Observing ${adContainers.length} ad containers`);
  }
  
  // Load individual ad
  function loadAd(container) {
    const adUnit = container.dataset.adUnit;
    
    // Trigger AdSense load
    try {
      (adsbygoogle = window.adsbygoogle || []).push({});
      container.classList.add('ad-loaded');
      console.log(`[Ad Lazy Load] Loaded ad: ${adUnit}`);
    } catch (e) {
      console.error('[Ad Lazy Load] Error loading ad:', e);
    }
  }
  
  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initLazyAds);
  } else {
    initLazyAds();
  }
})();
