// Ad Manager - Client-side ad insertion for dynamic content
// Handles ad placement in infinite scroll, AJAX-loaded content
// Default: Every 12 memes (configurable)

class AdManager {
  constructor(options = {}) {
    this.frequency = options.frequency || parseInt(window.AD_FREQUENCY || '12', 10);
    this.userIsPremium = options.isPremium || false;
    this.adsDisabled = options.disabled || false;
    this.adCount = 0;
    this.impressions = [];
    this.minItemsForAds = 6; // minimum content threshold before showing ads

    // NETWORK SWITCH (2026-09-29): this app's real ad revenue is Monetag,
    // loaded site-wide and independently via public/js/cookie-consent.js
    // (not per-slot). These feed-position containers only ever render
    // createPlaceholder() below - the old adSenseClient/adSlots options
    // and createAdSenseUnit()/loadAdSenseAds() methods are gone since
    // window.GOOGLE_ADSENSE_CLIENT/GOOGLE_AD_SLOT_* are no longer set
    // anywhere (removed from views/layout.erb), so they were permanently
    // dead code paths that always fell through to the placeholder anyway.
    console.log('📢 [AD MANAGER] Initialized:', {
      frequency: this.frequency,
      enabled: this.shouldShowAds(),
      minItems: this.minItemsForAds
    });
  }
  
  // Check if ads should be shown
  shouldShowAds() {
    // ADSENSE COMPLIANCE: No ads on auth/API pages
    const currentPath = window.location.pathname;
    const excludedPaths = ['/login', '/signup', '/auth/', '/api/', '/logout'];
    
    if (excludedPaths.some(path => currentPath.includes(path))) {
      console.log('📢 [AD MANAGER] Ads disabled for this page:', currentPath);
      return false;
    }

    if (window.AD_PLACEHOLDER_PREVIEW !== true) return false;
    
    return !this.userIsPremium && !this.adsDisabled;
  }
  
  // Determine if ad should be shown at this index
  shouldShowAdAtPosition(index) {
    if (index === 0) return false; // Never first position
    if (!this.shouldShowAds()) return false;
    return ((index + 1) % this.frequency) === 0;
  }
  
  // Create ad HTML element
  createAdElement(adIndex, format = 'square') {
    const container = document.createElement('div');
    container.className = 'ad-container';
    container.setAttribute('data-ad-index', adIndex);
    container.setAttribute('data-ad-format', format);
    
    // Add label
    const label = document.createElement('div');
    label.className = 'ad-label';
    label.textContent = 'Advertisement';
    container.appendChild(label);
    
    // Real ad revenue comes from Monetag's site-wide tag
    // (public/js/cookie-consent.js), loaded independently of these
    // feed-position slots - always render the placeholder.
    const placeholder = this.createPlaceholder(format);
    container.appendChild(placeholder);
    
    return container;
  }
  
  // Get ad dimensions by format
  getAdDimensions(format) {
    switch(format) {
      case 'banner':
        return { width: '728px', height: '90px' };
      case 'native':
        return { width: '100%', height: 'auto' };
      default: // square
        return { width: '300px', height: '250px' };
    }
  }
  
  // Create placeholder (development/testing)
  createPlaceholder(format) {
    const dimensions = this.getAdDimensions(format);
    const placeholder = document.createElement('div');
    placeholder.className = 'ad-demo-content ad-placeholder';
    placeholder.style.width = dimensions.width;
    placeholder.style.height = dimensions.height;
    
    placeholder.innerHTML = `
      <div class="ad-demo-text">
        <strong>Ad Placeholder</strong><br>
        <small>Reserved layout space - Monetag runs site-wide, not per-slot</small><br>
        <span style="font-size: 11px; opacity: 0.7;">${dimensions.width} × ${dimensions.height}</span>
      </div>
    `;
    
    return placeholder;
  }
  
  // Insert ads into a container at appropriate positions
  insertAdsIntoContainer(container, itemSelector) {
    if (!this.shouldShowAds()) return;
    
    const items = Array.from(container.querySelectorAll(itemSelector));
    
    // ADSENSE COMPLIANCE: Only insert ads if sufficient content exists
    if (items.length < this.minItemsForAds) {
      console.log(`📢 [AD MANAGER] Insufficient content (${items.length} < ${this.minItemsForAds}), no ads inserted`);
      return;
    }
    
    let insertedCount = 0;
    
    items.forEach((item, index) => {
      if (this.shouldShowAdAtPosition(index)) {
        const ad = this.createAdElement(this.adCount, 'square');
        item.parentNode.insertBefore(ad, item);
        insertedCount++;
        this.adCount++;
      }
    });
    
    console.log(`📢 [AD MANAGER] Inserted ${insertedCount} ads`);
  }
  
  // Insert a single ad at specific position
  insertAdAtPosition(container, beforeElement, format = 'square') {
    if (!this.shouldShowAds()) return null;
    
    const ad = this.createAdElement(this.adCount, format);
    container.insertBefore(ad, beforeElement);
    this.adCount++;
    
    return ad;
  }
  
  // Track ad impression for analytics
  trackAdImpression(impression) {
    if (window.activityTracker) {
      window.activityTracker.track('ad_impression', {
        ad_index: impression.index,
        ad_format: impression.format,
        ad_frequency: this.frequency
      });
    }
  }
  
  // Setup intersection observer for lazy loading ads
  setupLazyLoading() {
    if (!('IntersectionObserver' in window)) return;
    
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const adContainer = entry.target;
          const adIndex = parseInt(adContainer.getAttribute('data-ad-index'), 10);
          console.log(`👁️ [AD MANAGER] Ad #${adIndex} in viewport`);
          
          // Track viewability
          if (window.activityTracker) {
            window.activityTracker.track('ad_viewable', { ad_index: adIndex });
          }
          
          observer.unobserve(adContainer);
        }
      });
    }, {
      threshold: 0.5, // 50% visible
      rootMargin: '50px'
    });
    
    // Observe all ad containers
    document.querySelectorAll('.ad-container').forEach(ad => {
      observer.observe(ad);
    });
  }
}

// Export for use in other scripts
window.AdManager = AdManager;
