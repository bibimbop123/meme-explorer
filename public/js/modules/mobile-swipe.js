/**
 * Mobile Swipe Gestures for Meme Navigation
 * Week 2 UX Enhancement
 * 
 * Features:
 * - Swipe left/right to navigate memes
 * - Visual feedback during swipe
 * - Configurable thresholds
 * - Works alongside keyboard shortcuts
 */

(function() {
  'use strict';

  // Configuration
  const CONFIG = {
    swipeThreshold: 50,      // Minimum distance for swipe (px)
    velocityThreshold: 0.3,  // Minimum velocity for swipe
    maxVerticalDrift: 75,    // Max vertical movement allowed (px)
    feedbackOpacity: 0.3,    // Visual feedback opacity
  };

  // State
  let touchStartX = null;
  let touchStartY = 0;
  let touchStartTime = 0;
  let isSwiping = false;
  let swipeOverlay = null;
  let initialized = false;

  /**
   * Initialize swipe gestures
   */
  function init() {
    if (initialized || !document.getElementById('meme-display')) return;
    // Only enable on touch devices
    if (!('ontouchstart' in window)) {
      console.log('📱 Swipe gestures: Not a touch device, skipping');
      return;
    }

    console.log('📱 Swipe gestures: Initializing...');
    
    // Create swipe feedback overlay
    createSwipeOverlay();
    initialized = true;
    
    // Add touch event listeners
    document.addEventListener('touchstart', handleTouchStart, { passive: false });
    document.addEventListener('touchmove', handleTouchMove, { passive: false });
    document.addEventListener('touchend', handleTouchEnd, { passive: false });
    document.addEventListener('touchcancel', resetGesture, { passive: true });
    
    console.log('✅ Swipe gestures: Ready');
  }

  /**
   * Create visual feedback overlay
   */
  function createSwipeOverlay() {
    swipeOverlay = document.createElement('div');
    swipeOverlay.id = 'swipe-overlay';
    swipeOverlay.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 9999;
      display: none;
      background: linear-gradient(90deg, 
        transparent 0%, 
        rgba(103, 126, 234, ${CONFIG.feedbackOpacity}) 50%, 
        transparent 100%
      );
      transition: opacity 0.2s;
    `;
    document.body.appendChild(swipeOverlay);
  }

  /**
   * Handle touch start
   */
  function handleTouchStart(e) {
    resetGesture();
    // Only the viewer owns feed gestures. Preserve browser zoom, media controls,
    // galleries, editable content and gestures inside open dialogs.
    if (e.touches.length !== 1 || document.body.classList.contains('modal-open')) return;
    if (!e.target.closest('#meme-display')) return;
    if (e.target.closest('.gallery-carousel, .meme-gallery, video, audio, input, textarea, select, button, a, [contenteditable], [role="dialog"], dialog')) return;

    const touch = e.touches[0];
    touchStartX = touch.clientX;
    touchStartY = touch.clientY;
    touchStartTime = Date.now();
    isSwiping = false;
  }

  /**
   * Handle touch move
   */
  function handleTouchMove(e) {
    if (e.touches.length !== 1) { resetGesture(); return; }
    if (touchStartX === null) return;

    const touch = e.touches[0];
    const deltaX = touch.clientX - touchStartX;
    const deltaY = Math.abs(touch.clientY - touchStartY);

    // Check if this is a horizontal swipe
    if (deltaY > CONFIG.maxVerticalDrift || (deltaY > 10 && deltaY >= Math.abs(deltaX))) {
      resetGesture();
      return;
    }
    if (Math.abs(deltaX) > 10 && Math.abs(deltaX) > deltaY * 1.5) {
      isSwiping = true;
      
      // Show visual feedback
      if (swipeOverlay) {
        swipeOverlay.style.display = 'block';
        swipeOverlay.style.opacity = Math.min(Math.abs(deltaX) / CONFIG.swipeThreshold, 1);
        
        // Color based on direction
        if (deltaX > 0) {
          // Swiping right (previous)
          swipeOverlay.style.background = `linear-gradient(90deg, 
            rgba(103, 126, 234, ${CONFIG.feedbackOpacity}) 0%, 
            transparent 50%
          )`;
        } else {
          // Swiping left (next)
          swipeOverlay.style.background = `linear-gradient(90deg, 
            transparent 50%, 
            rgba(103, 126, 234, ${CONFIG.feedbackOpacity}) 100%
          )`;
        }
      }
      
      // Prevent default scroll if swiping
      if (Math.abs(deltaX) > CONFIG.swipeThreshold / 2) {
        if (e.cancelable) e.preventDefault();
      }
    }
  }

  /**
   * Handle touch end
   */
  function handleTouchEnd(e) {
    if (touchStartX === null || !isSwiping || e.touches.length || !e.changedTouches.length) {
      resetGesture();
      return;
    }

    const touch = e.changedTouches[0];
    const deltaX = touch.clientX - touchStartX;
    const deltaY = Math.abs(touch.clientY - touchStartY);
    const deltaTime = Date.now() - touchStartTime;
    const velocity = Math.abs(deltaX) / Math.max(deltaTime, 1);

    // Check if swipe meets thresholds
    const isValidSwipe = 
      Math.abs(deltaX) > CONFIG.swipeThreshold &&
      Math.abs(deltaX) > deltaY * 1.5 &&
      deltaY < CONFIG.maxVerticalDrift &&
      velocity > CONFIG.velocityThreshold;

    if (isValidSwipe) {
      if (deltaX > 0) {
        // Swipe right - previous meme
        console.log('📱 Swipe: Previous meme');
        navigatePrevious();
      } else {
        // Swipe left - next meme
        console.log('📱 Swipe: Next meme');
        navigateNext();
      }
      
      // Haptic feedback if available
      if (window.hapticSystem) {
        window.hapticSystem.trigger('light');
      }
      
      // Sound feedback if available
      if (window.soundSystem && !window.soundSystem.isMuted()) {
        window.soundSystem.play('click');
      }
    }

    // Reset
    resetGesture();
  }

  function resetGesture() {
    touchStartX = null;
    touchStartY = 0;
    isSwiping = false;
    hideSwipeOverlay();
  }

  /**
   * Hide swipe overlay with fade
   */
  function hideSwipeOverlay() {
    if (swipeOverlay) {
      swipeOverlay.style.opacity = '0';
      swipeOverlay.style.display = 'none';
    }
  }

  /**
   * Navigate to next meme
   */
  function navigateNext() {
    // Try keyboard navigation module first
    if (window.memeNavigation && window.memeNavigation.nextMeme) {
      window.memeNavigation.nextMeme();
      return;
    }

    // Fallback: Look for next button
    const nextBtn = document.getElementById('next-btn') || 
                   document.querySelector('[data-action="next"]');
    if (nextBtn) {
      nextBtn.click();
      return;
    }

    // No fallback navigation: a missing viewer control must not leave the page.
  }

  /**
   * Navigate to previous meme
   */
  function navigatePrevious() {
    // Try keyboard navigation module first
    if (window.memeNavigation && window.memeNavigation.previousMeme) {
      window.memeNavigation.previousMeme();
      return;
    }

    // Fallback: Look for previous button
    const prevBtn = document.getElementById('prev-btn') || 
                   document.querySelector('[data-action="previous"]');
    if (prevBtn) {
      prevBtn.click();
      return;
    }

    // No fallback navigation: Previous must never unexpectedly advance the feed.
  }

  /**
   * Destroy swipe gestures (cleanup)
   */
  function destroy() {
    document.removeEventListener('touchstart', handleTouchStart);
    document.removeEventListener('touchmove', handleTouchMove);
    document.removeEventListener('touchend', handleTouchEnd);
    document.removeEventListener('touchcancel', resetGesture);
    resetGesture();
    initialized = false;
    
    if (swipeOverlay && swipeOverlay.parentNode) {
      swipeOverlay.parentNode.removeChild(swipeOverlay);
    }
    swipeOverlay = null;
    
    console.log('📱 Swipe gestures: Destroyed');
  }

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Export public API
  window.mobileSwipe = {
    init,
    destroy,
    config: CONFIG
  };

  console.log('📱 Mobile swipe module loaded');
})();
