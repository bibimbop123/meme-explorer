// iFunny-Style Feature Tracking
// Tracks user interactions for collaborative filtering and session learning

(function() {
  'use strict';
  
  // Track meme view start time for duration calculation
  let currentMemeViewStart = null;
  let currentMemeData = null;
  let sessionStartTime = Date.now();
  let memesViewedThisSession = 0;
  
  // Initialize tracking
  function initTracking() {
    console.log('🎯 iFunny-style tracking initialized');
    
    // Track when meme comes into view
    observeMemeViews();
    
    // Track interactions
    setupInteractionTrackers();
    
    // Track session duration
    trackSessionMetrics();
  }
  
  // Observe when memes enter viewport
  function observeMemeViews() {
    if (!('IntersectionObserver' in window)) return;
    
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          // Meme entered viewport
          const memeElement = entry.target;
          const memeUrl = memeElement.dataset.memeUrl;
          const memeId = memeElement.dataset.memeId;
          const subreddit = memeElement.dataset.subreddit;
          const poolType = memeElement.dataset.poolType;
          
          if (memeUrl) {
            startMemeView(memeUrl, {
              memeId: memeId,
              subreddit: subreddit,
              poolType: poolType
            });
          }
        } else {
          // Meme left viewport
          if (currentMemeData) {
            endMemeView();
          }
        }
      });
    }, {
      threshold: 0.5 // 50% visibility
    });
    
    // Observe all meme containers
    document.querySelectorAll('[data-meme-url]').forEach(el => {
      observer.observe(el);
    });
  }
  
  // Start tracking meme view
  function startMemeView(memeUrl, data) {
    // End previous view if exists
    if (currentMemeData) {
      endMemeView();
    }
    
    currentMemeViewStart = Date.now();
    currentMemeData = {
      memeUrl: memeUrl,
      ...data
    };
    
    memesViewedThisSession++;
    
    // Track view event
    trackInteraction('view', memeUrl, {
      sessionPosition: memesViewedThisSession,
      poolType: data.poolType
    });
  }
  
  // End tracking meme view
  function endMemeView() {
    if (!currentMemeViewStart || !currentMemeData) return;
    
    const duration = Math.round((Date.now() - currentMemeViewStart) / 1000);
    
    // Only track if viewed for at least 1 second
    if (duration >= 1) {
      trackInteraction('view_complete', currentMemeData.memeUrl, {
        duration: duration,
        poolType: currentMemeData.poolType
      });
    }
    
    currentMemeViewStart = null;
    currentMemeData = null;
  }
  
  // Setup interaction tracking (likes, shares, etc.)
  function setupInteractionTrackers() {
    // Track like button clicks
    document.addEventListener('click', (e) => {
      const likeButton = e.target.closest('[data-action="like"]');
      if (likeButton) {
        const memeUrl = likeButton.dataset.memeUrl;
        const memeId = likeButton.dataset.memeId;
        
        if (memeUrl) {
          trackInteraction('like', memeUrl, { memeId: memeId });
          learnFromInteraction(memeUrl, 'like');
        }
      }
      
      // Track skip/next button
      const skipButton = e.target.closest('[data-action="skip"], [data-action="next"]');
      if (skipButton && currentMemeData) {
        trackInteraction('skip', currentMemeData.memeUrl, {
          poolType: currentMemeData.poolType
        });
        learnFromInteraction(currentMemeData.memeUrl, 'skip');
      }
      
      // Track share button
      const shareButton = e.target.closest('[data-action="share"]');
      if (shareButton) {
        const memeUrl = shareButton.dataset.memeUrl;
        if (memeUrl) {
          trackInteraction('share', memeUrl);
          learnFromInteraction(memeUrl, 'share');
        }
      }
    });
  }
  
  // Track session metrics
  function trackSessionMetrics() {
    // Send heartbeat every 30 seconds to indicate user is still active
    setInterval(() => {
      fetch('/api/session/heartbeat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      }).catch(err => console.warn('Session heartbeat failed:', err));
    }, 30000);
    
    // Send full session stats every 60 seconds
    setInterval(() => {
      const sessionDuration = Math.round((Date.now() - sessionStartTime) / 1000);
      
      fetch('/api/session/metrics', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          duration: sessionDuration,
          memes_viewed: memesViewedThisSession,
          avg_time_per_meme: sessionDuration / Math.max(memesViewedThisSession, 1)
        })
      }).catch(err => console.warn('Session metrics tracking failed:', err));
    }, 60000);
    
    // Track session end on page unload
    window.addEventListener('beforeunload', () => {
      if (currentMemeData) {
        endMemeView();
      }
      
      const sessionDuration = Math.round((Date.now() - sessionStartTime) / 1000);
      
      // Use sendBeacon for reliable tracking on unload
      if (navigator.sendBeacon) {
        const data = new FormData();
        data.append('duration', sessionDuration);
        data.append('memes_viewed', memesViewedThisSession);
        navigator.sendBeacon('/api/session/end', data);
      }
    });
  }
  
  // Track interaction with backend
  function trackInteraction(type, memeUrl, additionalData = {}) {
    const duration = currentMemeViewStart ? 
      Math.round((Date.now() - currentMemeViewStart) / 1000) : 0;
    
    fetch('/api/random/track', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        meme_id: memeUrl,
        type: type,
        duration: duration,
        ...additionalData,
        timestamp: Date.now()
      })
    }).catch(err => {
      console.warn('Tracking failed:', err);
    });
  }
  
  // Learn from interaction (session-based learning)
  function learnFromInteraction(memeUrl, interactionType) {
    // Store in localStorage for quick session learning
    const sessionLearning = getSessionLearning();
    
    if (interactionType === 'like') {
      sessionLearning.likes = (sessionLearning.likes || 0) + 1;
    } else if (interactionType === 'skip') {
      sessionLearning.skips = (sessionLearning.skips || 0) + 1;
    }
    
    sessionLearning.totalInteractions = (sessionLearning.totalInteractions || 0) + 1;
    sessionLearning.lastInteraction = Date.now();
    
    saveSessionLearning(sessionLearning);
  }
  
  // Get session learning data
  function getSessionLearning() {
    try {
      const data = localStorage.getItem('meme_session_learning');
      return data ? JSON.parse(data) : {};
    } catch (e) {
      return {};
    }
  }
  
  // Save session learning data
  function saveSessionLearning(data) {
    try {
      localStorage.setItem('meme_session_learning', JSON.stringify(data));
    } catch (e) {
      console.warn('Failed to save session learning:', e);
    }
  }
  
  // Get session analytics
  window.getSessionAnalytics = function() {
    const learning = getSessionLearning();
    const duration = Math.round((Date.now() - sessionStartTime) / 1000);
    
    return {
      duration: duration,
      memesViewed: memesViewedThisSession,
      likes: learning.likes || 0,
      skips: learning.skips || 0,
      engagementRate: memesViewedThisSession > 0 ? 
        ((learning.likes || 0) / memesViewedThisSession * 100).toFixed(1) + '%' : '0%',
      avgTimePerMeme: memesViewedThisSession > 0 ?
        (duration / memesViewedThisSession).toFixed(1) + 's' : '0s'
    };
  };
  
  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initTracking);
  } else {
    initTracking();
  }
  
  // Debug mode
  window.iFunnyTracking = {
    getCurrentMeme: () => currentMemeData,
    getSessionAnalytics: window.getSessionAnalytics,
    forceEndView: endMemeView,
    getMemesViewedCount: () => memesViewedThisSession
  };
  
})();
