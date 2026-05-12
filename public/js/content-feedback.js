// Content Feedback System
// Allows users to report broken images/placeholders

(function() {
  'use strict';
  
  // Add feedback button to placeholder images
  function initContentFeedback() {
    // Find all meme images
    const memeImages = document.querySelectorAll('.meme-image, img[data-meme-url]');
    
    memeImages.forEach(img => {
      // Listen for image load errors
      img.addEventListener('error', function() {
        showFeedbackButton(this);
      });
      
      // Check if image is already broken (immediate)
      if (img.complete && img.naturalHeight === 0) {
        showFeedbackButton(img);
      }
    });
  }
  
  // Show feedback button on broken image
  function showFeedbackButton(img) {
    // Don't add button twice
    if (img.dataset.feedbackAdded) return;
    img.dataset.feedbackAdded = 'true';
    
    // Create feedback button
    const button = document.createElement('button');
    button.className = 'content-feedback-btn';
    button.innerHTML = '🚫 Report Issue';
    button.title = 'Help us improve by reporting this broken content';
    
    // Style button
    Object.assign(button.style, {
      position: 'absolute',
      bottom: '10px',
      right: '10px',
      padding: '8px 16px',
      background: 'rgba(255, 59, 48, 0.9)',
      color: 'white',
      border: 'none',
      borderRadius: '6px',
      cursor: 'pointer',
      fontSize: '14px',
      fontWeight: '600',
      zIndex: '1000',
      boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
      transition: 'all 0.2s ease'
    });
    
    // Hover effect
    button.addEventListener('mouseenter', () => {
      button.style.background = 'rgba(255, 59, 48, 1)';
      button.style.transform = 'scale(1.05)';
    });
    
    button.addEventListener('mouseleave', () => {
      button.style.background = 'rgba(255, 59, 48, 0.9)';
      button.style.transform = 'scale(1)';
    });
    
    // Handle report
    button.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      reportBrokenContent(img, button);
    });
    
    // Position relative to image
    const container = img.parentElement;
    if (container) {
      container.style.position = 'relative';
      container.appendChild(button);
    }
  }
  
  // Report broken content to server
  function reportBrokenContent(img, button) {
    const url = img.src || img.dataset.memeUrl;
    
    if (!url) {
      showFeedback(button, '⚠️ No URL found', 'warning');
      return;
    }
    
    // Show loading state
    button.disabled = true;
    button.innerHTML = '⏳ Reporting...';
    
    // Send report to server
    fetch('/api/report-broken-content', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': getCsrfToken()
      },
      body: JSON.stringify({
        url: url,
        page: window.location.pathname,
        user_agent: navigator.userAgent
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        showFeedback(button, '✅ Reported', 'success');
        
        // Auto-hide after 2 seconds
        setTimeout(() => {
          button.style.opacity = '0';
          setTimeout(() => button.remove(), 300);
        }, 2000);
      } else {
        showFeedback(button, '❌ Failed', 'error');
      }
    })
    .catch(error => {
      console.error('Report error:', error);
      showFeedback(button, '❌ Error', 'error');
    });
  }
  
  // Show feedback message
  function showFeedback(button, message, type) {
    button.innerHTML = message;
    
    if (type === 'success') {
      button.style.background = 'rgba(52, 199, 89, 0.9)';
    } else if (type === 'error' || type === 'warning') {
      button.style.background = 'rgba(255, 149, 0, 0.9)';
    }
    
    // Re-enable after delay
    if (type !== 'success') {
      setTimeout(() => {
        button.disabled = false;
        button.innerHTML = '🚫 Report Issue';
        button.style.background = 'rgba(255, 59, 48, 0.9)';
      }, 3000);
    }
  }
  
  // Get CSRF token from meta tag or cookie
  function getCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    if (meta) return meta.content;
    
    // Fallback: try to get from cookie
    const match = document.cookie.match(/csrf_token=([^;]+)/);
    return match ? match[1] : '';
  }
  
  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initContentFeedback);
  } else {
    initContentFeedback();
  }
  
  // Re-check on dynamic content load
  window.addEventListener('load', initContentFeedback);
  
})();
