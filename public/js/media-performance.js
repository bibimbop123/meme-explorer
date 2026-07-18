// Media Performance Monitoring - Phase 4
// Tracks load times, errors, and user experience metrics

class MediaPerformanceMonitor {
  constructor() {
    this.metrics = {
      images: [],
      videos: [],
      galleries: [],
      errors: []
    };
    
    this.initializeMonitoring();
  }
  
  initializeMonitoring() {
    // Monitor image loads
    this.monitorImages();
    
    // Monitor video loads
    this.monitorVideos();
    
    // Monitor gallery interactions
    this.monitorGalleries();
    
    // Send metrics periodically
    setInterval(() => this.sendMetrics(), 30000); // Every 30 seconds
  }
  
  monitorImages() {
    const images = document.querySelectorAll('.meme-content-image');
    
    images.forEach(img => {
      const startTime = performance.now();
      
      img.addEventListener('load', () => {
        const loadTime = performance.now() - startTime;
        this.trackMetric('images', {
          url: img.src,
          loadTime: loadTime,
          size: img.naturalWidth + 'x' + img.naturalHeight,
          timestamp: Date.now()
        });
      });
      
      img.addEventListener('error', (e) => {
        this.trackError('image_load_failed', {
          url: img.src,
          error: e.message || 'Unknown error',
          timestamp: Date.now()
        });
      });
    });
  }
  
  monitorVideos() {
    const videos = document.querySelectorAll('.meme-video');
    
    videos.forEach(video => {
      const startTime = performance.now();
      let firstFrameTime = null;
      
      video.addEventListener('loadedmetadata', () => {
        const metadataTime = performance.now() - startTime;
        this.trackMetric('videos', {
          url: video.src,
          metadataLoadTime: metadataTime,
          duration: video.duration,
          timestamp: Date.now()
        });
      });
      
      video.addEventListener('canplay', () => {
        firstFrameTime = performance.now() - startTime;
      });
      
      video.addEventListener('error', (e) => {
        this.trackError('video_load_failed', {
          url: video.src,
          error: video.error?.message || 'Unknown error',
          code: video.error?.code,
          timestamp: Date.now()
        });
      });
    });
  }
  
  monitorGalleries() {
    const galleries = document.querySelectorAll('.gallery-carousel');
    
    galleries.forEach(gallery => {
      const slideCount = gallery.querySelectorAll('.gallery-slide').length;
      let interactionCount = 0;
      
      gallery.addEventListener('click', () => {
        interactionCount++;
      });
      
      // Track engagement after 5 seconds
      setTimeout(() => {
        if (interactionCount > 0) {
          this.trackMetric('galleries', {
            slideCount: slideCount,
            interactions: interactionCount,
            engagementRate: (interactionCount / slideCount).toFixed(2),
            timestamp: Date.now()
          });
        }
      }, 5000);
    });
  }
  
  trackMetric(type, data) {
    this.metrics[type].push(data);
    
    // Keep last 100 metrics per type
    if (this.metrics[type].length > 100) {
      this.metrics[type].shift();
    }
  }
  
  trackError(errorType, data) {
    this.metrics.errors.push({
      type: errorType,
      ...data
    });
    
    console.error(`[Media Monitor] ${errorType}:`, data);
  }
  
  async sendMetrics() {
    if (this.hasMetrics()) {
      try {
        await fetch('/api/metrics/media', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            metrics: this.getAggregatedMetrics(),
            userAgent: navigator.userAgent,
            timestamp: Date.now()
          })
        });
        
        // Clear sent metrics
        this.clearMetrics();
      } catch (e) {
        console.error('[Media Monitor] Failed to send metrics:', e);
      }
    }
  }
  
  hasMetrics() {
    return Object.values(this.metrics).some(arr => arr.length > 0);
  }
  
  getAggregatedMetrics() {
    return {
      images: {
        count: this.metrics.images.length,
        avgLoadTime: this.average(this.metrics.images, 'loadTime'),
        errors: this.metrics.errors.filter(e => e.type === 'image_load_failed').length
      },
      videos: {
        count: this.metrics.videos.length,
        avgLoadTime: this.average(this.metrics.videos, 'metadataLoadTime'),
        errors: this.metrics.errors.filter(e => e.type === 'video_load_failed').length
      },
      galleries: {
        count: this.metrics.galleries.length,
        avgEngagementRate: this.average(this.metrics.galleries, 'engagementRate')
      },
      totalErrors: this.metrics.errors.length
    };
  }
  
  average(arr, key) {
    if (!arr.length) return 0;
    const sum = arr.reduce((acc, item) => acc + (parseFloat(item[key]) || 0), 0);
    return (sum / arr.length).toFixed(2);
  }
  
  clearMetrics() {
    this.metrics = {
      images: [],
      videos: [],
      galleries: [],
      errors: []
    };
  }
}

// Initialize on page load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.mediaMonitor = new MediaPerformanceMonitor();
  });
} else {
  window.mediaMonitor = new MediaPerformanceMonitor();
}
