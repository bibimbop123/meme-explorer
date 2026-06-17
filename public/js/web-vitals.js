/**
 * Core Web Vitals Tracking
 * Tracks LCP, FID, CLS and reports to analytics
 */

(function() {
  'use strict';

  const vitals = { lcp: null, fid: null, cls: null };
  
  // Track Largest Contentful Paint (LCP)
  if ('PerformanceObserver' in window) {
    try {
      new PerformanceObserver((list) => {
        const entries = list.getEntries();
        const lastEntry = entries[entries.length - 1];
        vitals.lcp = Math.round(lastEntry.renderTime || lastEntry.loadTime);
        
        if (vitals.lcp > 2500) {
          console.warn(`⚠️ LCP: ${vitals.lcp}ms (needs improvement)`);
        }
        
        sendMetric('lcp', vitals.lcp);
      }).observe({ type: 'largest-contentful-paint', buffered: true });
    } catch (e) {
      console.error('LCP tracking error:', e);
    }
    
    // Track First Input Delay (FID)
    try {
      new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          vitals.fid = Math.round(entry.processingStart - entry.startTime);
          
          if (vitals.fid > 100) {
            console.warn(`⚠️ FID: ${vitals.fid}ms (needs improvement)`);
          }
          
          sendMetric('fid', vitals.fid);
        });
      }).observe({ type: 'first-input', buffered: true });
    } catch (e) {
      console.error('FID tracking error:', e);
    }
    
    // Track Cumulative Layout Shift (CLS)
    try {
      let clsValue = 0;
      new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          if (!entry.hadRecentInput) {
            clsValue += entry.value;
          }
        });
        
        vitals.cls = Math.round(clsValue * 1000) / 1000;
        
        if (vitals.cls > 0.1) {
          console.warn(`⚠️ CLS: ${vitals.cls} (needs improvement)`);
        }
      }).observe({ type: 'layout-shift', buffered: true });
      
      // Send final CLS on page unload
      window.addEventListener('beforeunload', () => {
        sendMetric('cls', vitals.cls);
      });
    } catch (e) {
      console.error('CLS tracking error:', e);
    }
    
    console.log('✅ Core Web Vitals tracking initialized');
  } else {
    console.warn('⚠️ PerformanceObserver not supported');
  }
  
  function sendMetric(metric, value) {
    if (!value) return;
    
    try {
      fetch('/api/vitals', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          metric: metric,
          value: value,
          url: window.location.pathname,
          timestamp: Date.now()
        }),
        keepalive: true
      }).catch(e => console.error('Analytics error:', e));
    } catch (e) {
      console.error('Failed to send vital:', e);
    }
  }
  
  // Export for console access
  window.getWebVitals = () => vitals;
})();
