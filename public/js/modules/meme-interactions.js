/**
 * Meme Interactions Module
 * Handles like, save, and share functionality
 */

export class MemeInteractions {
  constructor() {
    this.init();
  }
  
  init() {
    console.log('[MemeInteractions] Initializing...');
    this.bindLikeButton();
    this.bindSaveButton();
    this.bindShareButton();
  }
  
  bindLikeButton() {
    const likeBtn = document.getElementById('like-btn');
    if (likeBtn) {
      likeBtn.addEventListener('click', () => this.handleLike());
    }
  }
  
  bindSaveButton() {
    const saveBtn = document.getElementById('save-btn');
    if (saveBtn) {
      saveBtn.addEventListener('click', () => this.handleSave());
    }
  }
  
  bindShareButton() {
    const shareBtn = document.getElementById('share-btn');
    if (shareBtn) {
      shareBtn.addEventListener('click', () => this.handleShare());
    }
  }
  
  async handleLike() {
    console.log('[MemeInteractions] Like clicked');
    
    const memeUrl = this.getCurrentMemeUrl();
    if (!memeUrl) return;
    
    try {
      const response = await fetch('/api/like', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ meme_url: memeUrl })
      });
      
      if (response.ok) {
        this.updateLikeButton(true);
        this.showToast('Liked! ❤️');
      }
    } catch (error) {
      console.error('[MemeInteractions] Like failed:', error);
      this.showToast('Error liking meme');
    }
  }
  
  async handleSave() {
    console.log('[MemeInteractions] Save clicked');
    
    const memeUrl = this.getCurrentMemeUrl();
    if (!memeUrl) return;
    
    try {
      const response = await fetch('/api/save', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ meme_url: memeUrl })
      });
      
      if (response.ok) {
        this.updateSaveButton(true);
        this.showToast('Saved! 🔖');
      }
    } catch (error) {
      console.error('[MemeInteractions] Save failed:', error);
      this.showToast('Error saving meme');
    }
  }
  
  handleShare() {
    console.log('[MemeInteractions] Share clicked');
    
    if (navigator.share) {
      // Use native share API if available
      navigator.share({
        title: document.title,
        url: window.location.href
      }).catch(err => console.log('Share cancelled', err));
    } else {
      // Fallback: copy link to clipboard
      navigator.clipboard.writeText(window.location.href);
      this.showToast('Link copied! 📤');
    }
  }
  
  getCurrentMemeUrl() {
    const img = document.getElementById('meme-image');
    return img ? img.src : null;
  }
  
  updateLikeButton(liked) {
    const likeBtn = document.getElementById('like-btn');
    if (likeBtn) {
      likeBtn.classList.toggle('liked', liked);
    }
  }
  
  updateSaveButton(saved) {
    const saveBtn = document.getElementById('save-btn');
    if (saveBtn) {
      saveBtn.classList.toggle('saved', saved);
    }
  }
  
  showToast(message) {
    // Simple toast notification
    const toast = document.createElement('div');
    toast.className = 'toast-notification';
    toast.textContent = message;
    toast.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(0, 0, 0, 0.8);
      color: white;
      padding: 12px 24px;
      border-radius: 8px;
      z-index: 10000;
      animation: fadeIn 0.3s, fadeOut 0.3s 2.7s;
    `;
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
      toast.remove();
    }, 3000);
  }
}
