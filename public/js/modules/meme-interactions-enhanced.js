/**
 * Meme Interactions Module - Enhanced Edition
 * Professional-grade like/save functionality with smooth animations
 * Built by experienced tech lead for optimal UX
 */

export class MemeInteractionsEnhanced {
  constructor() {
    this.isProcessing = false;
    this.init();
  }
  
  init() {
    console.log('[MemeInteractions] Initializing Enhanced Edition...');
    this.bindLikeButton();
    this.bindSaveButton();
    this.bindShareButton();
    this.checkInitialStates();
    this.addAnimationStyles();
  }
  
  // Add CSS animations dynamically
  addAnimationStyles() {
    if (document.getElementById('meme-interactions-styles')) return;
    
    const styles = document.createElement('style');
    styles.id = 'meme-interactions-styles';
    styles.textContent = `
      @keyframes heartBeat {
        0%, 100% { transform: scale(1); }
        25% { transform: scale(1.3); }
        50% { transform: scale(1.1); }
        75% { transform: scale(1.2); }
      }
      
      @keyframes bookmarkSlide {
        0% { transform: translateY(0) scale(1); }
        50% { transform: translateY(-8px) scale(1.2); }
        100% { transform: translateY(0) scale(1); }
      }
      
      @keyframes ripple {
        0% {
          transform: scale(0);
          opacity: 1;
        }
        100% {
          transform: scale(4);
          opacity: 0;
        }
      }
      
      @keyframes fadeInUp {
        from {
          opacity: 0;
          transform: translate(-50%, 20px);
        }
        to {
          opacity: 1;
          transform: translate(-50%, 0);
        }
      }
      
      .btn-processing {
        opacity: 0.6;
        pointer-events: none;
      }
      
      .btn-liked {
        animation: heartBeat 0.6s ease;
      }
      
      .btn-saved {
        animation: bookmarkSlide 0.5s ease;
      }
      
      .ripple-effect {
        position: absolute;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.6);
        animation: ripple 0.6s ease-out;
        pointer-events: none;
      }
      
      .toast-notification {
        animation: fadeInUp 0.3s ease, fadeOut 0.3s ease 2.7s !important;
      }
      
      @keyframes fadeOut {
        from { opacity: 1; }
        to { opacity: 0; }
      }
    `;
    document.head.appendChild(styles);
  }
  
  bindLikeButton() {
    const likeBtn = document.getElementById('like-btn');
    if (likeBtn) {
      likeBtn.addEventListener('click', (e) => this.handleLike(e));
    }
  }
  
  bindSaveButton() {
    const saveBtn = document.getElementById('save-btn');
    if (saveBtn) {
      saveBtn.addEventListener('click', (e) => this.handleSave(e));
    }
  }
  
  bindShareButton() {
    const shareBtn = document.getElementById('share-btn');
    if (shareBtn) {
      shareBtn.addEventListener('click', () => this.handleShare());
    }
  }
  
  // Create ripple effect on button click
  createRipple(event) {
    const button = event.currentTarget;
    const ripple = document.createElement('span');
    ripple.className = 'ripple-effect';
    
    const rect = button.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height);
    const x = event.clientX - rect.left - size / 2;
    const y = event.clientY - rect.top - size / 2;
    
    ripple.style.width = ripple.style.height = `${size}px`;
    ripple.style.left = `${x}px`;
    ripple.style.top = `${y}px`;
    
    button.style.position = 'relative';
    button.style.overflow = 'hidden';
    button.appendChild(ripple);
    
    setTimeout(() => ripple.remove(), 600);
  }
  
  // Haptic feedback for mobile devices
  triggerHaptic(style = 'medium') {
    if ('vibrate' in navigator) {
      const patterns = {
        light: [10],
        medium: [20],
        heavy: [30],
        success: [10, 50, 10]
      };
      navigator.vibrate(patterns[style] || patterns.medium);
    }
  }
  
  async handleLike(event) {
    if (this.isProcessing) return;
    
    console.log('[MemeInteractions] Like clicked');
    this.createRipple(event);
    
    const memeUrl = this.getCurrentMemeUrl();
    if (!memeUrl) {
      console.error('[MemeInteractions] No meme URL found');
      return;
    }
    
    const likeBtn = document.getElementById('like-btn');
    const wasLiked = likeBtn?.classList.contains('liked');
    
    // Optimistic UI update
    this.isProcessing = true;
    likeBtn?.classList.add('btn-processing');
    
    // Immediately update UI (optimistic)
    this.updateLikeButton(!wasLiked, true);
    this.triggerHaptic(wasLiked ? 'light' : 'success');
    
    try {
      const response = await fetch('/like', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ url: memeUrl })
      });
      
      if (response.ok) {
        const data = await response.json();
        console.log('[MemeInteractions] Like success:', data);
        
        // Confirm the state matches server
        this.updateLikeButton(data.liked, false);
        this.showToast(data.liked ? '❤️ Liked!' : 'Unliked', 'success');
        
        // Update like count if available
        if (data.likes !== undefined) {
          this.updateLikeCount(data.likes);
        }
        
      } else {
        // Revert optimistic update on error
        this.updateLikeButton(wasLiked, false);
        const error = await response.json();
        console.error('[MemeInteractions] Like failed:', error);
        this.showToast(error.error || 'Error liking meme', 'error');
        this.triggerHaptic('heavy');
      }
    } catch (error) {
      // Revert optimistic update on error
      this.updateLikeButton(wasLiked, false);
      console.error('[MemeInteractions] Like request failed:', error);
      this.showToast('Network error', 'error');
      this.triggerHaptic('heavy');
    } finally {
      this.isProcessing = false;
      likeBtn?.classList.remove('btn-processing');
    }
  }
  
  async handleSave(event) {
    if (this.isProcessing) return;
    
    console.log('[MemeInteractions] Save clicked');
    this.createRipple(event);
    
    const memeUrl = this.getCurrentMemeUrl();
    if (!memeUrl) {
      console.error('[MemeInteractions] No meme URL found');
      return;
    }
    
    const saveBtn = document.getElementById('save-btn');
    const wasSaved = saveBtn?.classList.contains('saved');
    
    // Get meme metadata for saving
    const memeTitle = document.querySelector('.meme-title')?.textContent || 'Untitled Meme';
    const memeSubreddit = document.querySelector('.meme-subreddit')?.textContent || 'unknown';
    
    // Optimistic UI update
    this.isProcessing = true;
    saveBtn?.classList.add('btn-processing');
    
    // Immediately update UI (optimistic)
    this.updateSaveButton(!wasSaved, true);
    this.triggerHaptic(wasSaved ? 'light' : 'success');
    
    try {
      const endpoint = wasSaved ? '/api/unsave-meme' : '/api/save-meme';
      const body = wasSaved 
        ? { url: memeUrl }
        : { url: memeUrl, title: memeTitle, subreddit: memeSubreddit };
      
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      });
      
      if (response.ok) {
        const data = await response.json();
        console.log('[MemeInteractions] Save success:', data);
        
        // Confirm the state
        this.updateSaveButton(!wasSaved, false);
        this.showToast(wasSaved ? 'Removed from saved' : '🔖 Saved to profile!', 'success');
        
      } else {
        // Revert optimistic update on error
        this.updateSaveButton(wasSaved, false);
        const error = await response.json();
        console.error('[MemeInteractions] Save failed:', error);
        this.showToast(error.error || 'Error saving meme', 'error');
        this.triggerHaptic('heavy');
      }
    } catch (error) {
      // Revert optimistic update on error
      this.updateSaveButton(wasSaved, false);
      console.error('[MemeInteractions] Save request failed:', error);
      this.showToast('Network error', 'error');
      this.triggerHaptic('heavy');
    } finally {
      this.isProcessing = false;
      saveBtn?.classList.remove('btn-processing');
    }
  }
  
  handleShare() {
    console.log('[MemeInteractions] Share clicked');
    this.triggerHaptic('medium');
    
    if (navigator.share) {
      navigator.share({
        title: document.title,
        url: window.location.href
      }).then(() => {
        this.showToast('Shared!', 'success');
      }).catch(err => {
        if (err.name !== 'AbortError') {
          console.log('Share cancelled', err);
        }
      });
    } else {
      navigator.clipboard.writeText(window.location.href).then(() => {
        this.showToast('📤 Link copied!', 'success');
        this.triggerHaptic('success');
      });
    }
  }
  
  getCurrentMemeUrl() {
    const img = document.getElementById('meme-image');
    return img ? img.src : null;
  }
  
  updateLikeButton(liked, animate = true) {
    const likeBtn = document.getElementById('like-btn');
    if (likeBtn) {
      if (animate && liked) {
        likeBtn.classList.add('btn-liked');
        setTimeout(() => likeBtn.classList.remove('btn-liked'), 600);
      }
      likeBtn.classList.toggle('liked', liked);
      likeBtn.setAttribute('aria-pressed', liked);
      
      // Update icon if exists
      const icon = likeBtn.querySelector('i, svg');
      if (icon) {
        icon.style.color = liked ? '#e74c3c' : '';
      }
    }
  }
  
  updateSaveButton(saved, animate = true) {
    const saveBtn = document.getElementById('save-btn');
    if (saveBtn) {
      if (animate && saved) {
        saveBtn.classList.add('btn-saved');
        setTimeout(() => saveBtn.classList.remove('btn-saved'), 500);
      }
      saveBtn.classList.toggle('saved', saved);
      saveBtn.setAttribute('aria-pressed', saved);
      
      // Update icon if exists
      const icon = saveBtn.querySelector('i, svg');
      if (icon) {
        icon.style.color = saved ? '#f39c12' : '';
      }
    }
  }
  
  updateLikeCount(count) {
    const likeCountEl = document.getElementById('like-count');
    if (likeCountEl) {
      likeCountEl.textContent = count;
      // Animate count change
      likeCountEl.style.transform = 'scale(1.2)';
      setTimeout(() => {
        likeCountEl.style.transform = 'scale(1)';
      }, 200);
    }
  }
  
  checkInitialStates() {
    const likeBtn = document.getElementById('like-btn');
    const saveBtn = document.getElementById('save-btn');
    
    if (likeBtn && likeBtn.dataset.liked === 'true') {
      this.updateLikeButton(true, false);
    }
    
    if (saveBtn && saveBtn.dataset.saved === 'true') {
      this.updateSaveButton(true, false);
    }
  }
  
  showToast(message, type = 'info') {
    // Remove existing toasts
    document.querySelectorAll('.toast-notification').forEach(t => t.remove());
    
    const toast = document.createElement('div');
    toast.className = 'toast-notification';
    toast.textContent = message;
    toast.setAttribute('role', 'status');
    toast.setAttribute('aria-live', 'polite');
    
    const colors = {
      success: 'rgba(39, 174, 96, 0.95)',
      error: 'rgba(231, 76, 60, 0.95)',
      info: 'rgba(52, 73, 94, 0.95)'
    };
    
    toast.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: ${colors[type] || colors.info};
      color: white;
      padding: 12px 24px;
      border-radius: 8px;
      z-index: 10000;
      font-size: 14px;
      font-weight: 500;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      transition: transform 0.2s ease;
    `;
    
    document.body.appendChild(toast);
    
    // Hover effect
    toast.addEventListener('mouseenter', () => {
      toast.style.transform = 'translateX(-50%) translateY(-4px)';
    });
    toast.addEventListener('mouseleave', () => {
      toast.style.transform = 'translateX(-50%) translateY(0)';
    });
    
    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 300);
    }, 3000);
  }
}

// Auto-initialize if DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.memeInteractions = new MemeInteractionsEnhanced();
  });
} else {
  window.memeInteractions = new MemeInteractionsEnhanced();
}
