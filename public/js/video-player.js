// Video Player Error Handling and Enhancement
(function() {
  'use strict';
  
  // Initialize video players when page loads
  function initVideoPlayers() {
    const videos = document.querySelectorAll('.meme-content-video');
    
    videos.forEach(video => {
      // Add loading indicator
      video.addEventListener('loadstart', function() {
        this.classList.add('loading');
      });
      
      // Remove loading when ready
      video.addEventListener('loadeddata', function() {
        this.classList.remove('loading');
      });
      
      // Handle video errors
      video.addEventListener('error', function(e) {
        console.error('Video load error:', e);
        handleVideoError(this);
      });
      
      // Track video playback
      video.addEventListener('play', function() {
        if (typeof gtag !== 'undefined') {
          gtag('event', 'video_play', {
            video_src: this.src
          });
        }
      });
      
      // Enable fullscreen on double-click (desktop)
      video.addEventListener('dblclick', function() {
        if (this.requestFullscreen) {
          this.requestFullscreen();
        } else if (this.webkitRequestFullscreen) {
          this.webkitRequestFullscreen();
        }
      });
    });
  }
  
  // Handle video load errors with fallback
  function handleVideoError(videoElement) {
    const container = videoElement.parentElement;
    const videoUrl = videoElement.src;
    
    // Show error message
    const errorDiv = document.createElement('div');
    errorDiv.className = 'video-error';
    errorDiv.innerHTML = `
      <div style="padding: 2rem; text-align: center; background: #f5f5f5; border-radius: 8px;">
        <p style="margin-bottom: 1rem; font-size: 1.1rem;">⚠️ Video failed to load</p>
        <a href="${videoUrl}" target="_blank" class="btn btn-primary" style="display: inline-block; padding: 0.5rem 1rem; background: #1976d2; color: white; text-decoration: none; border-radius: 4px;">
          Open Video in New Tab
        </a>
      </div>
    `;
    
    // Replace video with error message
    videoElement.style.display = 'none';
    container.appendChild(errorDiv);
    
    // Track error
    if (typeof gtag !== 'undefined') {
      gtag('event', 'video_error', {
        video_src: videoUrl,
        error_code: videoElement.error?.code || 'unknown'
      });
    }
  }
  
  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initVideoPlayers);
  } else {
    initVideoPlayers();
  }
  
  // Re-initialize on dynamic content load
  window.addEventListener('memeLoaded', initVideoPlayers);
})();
