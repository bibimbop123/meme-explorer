// Ad Manager - Client-side ad insertion for dynamic content
// Handles ad placement in infinite scroll, AJAX-loaded content
// Default: Every 12 memes (configurable)

class AdManager {
  constructor(options = {}) {
    this.frequency = options.frequency || parseInt(window.AD_FREQUENCY || '12', 10);
    this.adSenseClient = options.adSenseClient || window.GOOGLE_ADSENSE_CLIENT || null;
    this.adSlots = {
      square: options.squareSlot || window.GOOGLE_AD_SLOT_SQUARE || null,
      banner: options.bannerSlot || window.GOOGLE_AD_SLOT_BANNER || null,
      native: options.nativeSlot || window.GOOGLE_AD_SLOT_NATIVE || null
    };
    this.userIsPremium = options.isPremium || false;
    this.adsDisabled = options.disabled || false;
    this.adCount = 0;
    this.impressions = [];
    
    console.log('📢 [AD MANAGER] Initialized:', {
      frequency: this.frequency,
      enabled: this.shouldShowAds(),
      client: this.adSenseClient ? '✓' : '✗'
    });
  }
  
  // Check if ads should be shown
  shouldShowAds() {
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
    
    // Create ad unit
    if (this.adSenseClient && this.adSlots[format]) {
      const adUnit = this.createAdSenseUnit(format);
      container.appendChild(adUnit);
      
      // Track for lazy loading
      this.impressions.push({
        element: adUnit,
        index: adIndex,
        format: format,
        loaded: false
      });
    } else {
      const placeholder = this.createPlaceholder(format);
      container.appendChild(placeholder);
    }
    
    return container;
  }
  
  // Create Google AdSense unit
  createAdSenseUnit(format) {
    const ins = document.createElement('ins');
    ins.className = 'adsbygoogle';
    ins.setAttribute('data-ad-client', this.adSenseClient);
    ins.setAttribute('data-ad-slot', this.adSlots[format]);
    
    const dimensions = this.getAdDimensions(format);
    ins.style.display = 'inline-block';
    ins.style.width = dimensions.width;
    ins.style.height = dimensions.height;
    
    if (format === 'native') {
      ins.setAttribute('data-ad-format', 'auto');
      ins.setAttribute('data-full-width-responsive', 'true');
    } else {
      ins.setAttribute('data-ad-format', 'rectangle');
    }
    
    return ins;
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
        <small>Configure ads in .env</small><br>
        <span style="font-size: 11px; opacity: 0.7;">${dimensions.width} × ${dimensions.height}</span>
      </div>
    `;
    
    return placeholder;
  }
  
  // Insert ads into a container at appropriate positions
  insertAdsIntoContainer(container, itemSelector) {
    if (!this.shouldShowAds()) return;
    
    const items = Array.from(container.querySelectorAll(itemSelector));
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
    
    // Load AdSense ads if configured
    if (this.adSenseClient && insertedCount > 0) {
      this.loadAdSenseAds();
    }
  }
  
  // Insert a single ad at specific position
  insertAdAtPosition(container, beforeElement, format = 'square') {
    if (!this.shouldShowAds()) return null;
    
    const ad = this.createAdElement(this.adCount, format);
    container.insertBefore(ad, beforeElement);
    this.adCount++;
    
    // Load AdSense ads if configured
    if (this.adSenseClient) {
      this.loadAdSenseAds();
    }
    
    return ad;
  }
  
  // Load AdSense ads (call after inserting ad units)
  loadAdSenseAds() {
    if (!window.adsbygoogle) {
      console.warn('⚠️ [AD MANAGER] AdSense script not loaded');
      return;
    }
    
    // Debounce ad loading to prevent multiple rapid calls
    if (this.loadTimeout) {
      clearTimeout(this.loadTimeout);
    }
    
    this.loadTimeout = setTimeout(() => {
      // Push new ads to AdSense (only unloaded ones)
      const unloadedAds = this.impressions.filter(imp => !imp.loaded);
      
      if (unloadedAds.length === 0) {
        return; // No new ads to load
      }
      
      console.log(`📢 [AD MANAGER] Loading ${unloadedAds.length} new ad(s)...`);
      
      unloadedAds.forEach(impression => {
        try {
          // Verify the ad element still exists in DOM
          if (!impression.element.isConnected) {
            console.warn(`⚠️ [AD MANAGER] Ad #${impression.index} element removed from DOM, skipping`);
            return;
          }
          
          (window.adsbygoogle = window.adsbygoogle || []).push({});
          impression.loaded = true;
          console.log(`✅ [AD MANAGER] Loaded ad #${impression.index}`);
          
          // Track impression
          this.trackAdImpression(impression);
        } catch (e) {
          console.error(`❌ [AD MANAGER] Error loading ad #${impression.index}:`, e.message);
        }
      });
    }, 100); // 100ms debounce
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
