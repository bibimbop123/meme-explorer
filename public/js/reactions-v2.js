// Reactions System - Emoji-based engagement
// Matches the /api/reactions endpoints

class ReactionsSystem {
  constructor() {
    this.reactionTypes = {
      hilarious: '😂',
      fire: '🔥',
      dead: '💀',
      shocking: '😱',
      relatable: '🤔'
    };
    this.init();
  }
  
  init() {
    // Handle reaction button clicks
    document.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-reaction-btn]');
      if (btn) {
        this.handleReaction(btn);
      }
    });
    
    // Load reactions for current meme
    this.loadReactionsForCurrentMeme();
  }
  
  async handleReaction(btn) {
    const memeUrl = btn.dataset.memeUrl;
    const reactionType = btn.dataset.reactionType;
    const isActive = btn.classList.contains('active');
    
    try {
      const response = await fetch('/api/reactions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `url=${encodeURIComponent(memeUrl)}&type=${encodeURIComponent(reactionType)}`
      });
      
      const data = await response.json();
      
      if (data.success) {
        // Update UI
        this.updateReactionCounts(memeUrl, data.counts, data.user_reactions);
        
        // Animate the reaction
        if (data.toggled) {
          this.animateReaction(btn, this.reactionTypes[reactionType]);
        }
      }
    } catch (error) {
      console.error('Reaction error:', error);
    }
  }
  
  async loadReactionsForCurrentMeme() {
    const container = document.querySelector('[data-reactions-container]');
    if (!container) return;
    
    const memeUrl = container.dataset.memeUrl;
    if (!memeUrl) return;
    
    try {
      const response = await fetch(`/api/reactions?url=${encodeURIComponent(memeUrl)}`);
      const data = await response.json();
      
      this.updateReactionCounts(memeUrl, data.counts, data.user_reactions);
    } catch (error) {
      console.error('Load reactions error:', error);
    }
  }
  
  updateReactionCounts(memeUrl, counts, userReactions) {
    const container = document.querySelector(`[data-reactions-container][data-meme-url="${memeUrl}"]`);
    if (!container) return;
    
    // Update each reaction button
    Object.keys(this.reactionTypes).forEach(type => {
      const btn = container.querySelector(`[data-reaction-type="${type}"]`);
      if (!btn) return;
      
      const count = counts[type] || 0;
      const countEl = btn.querySelector('.reaction-count');
      
      if (countEl) {
        countEl.textContent = count > 0 ? this.formatCount(count) : '';
        countEl.style.display = count > 0 ? 'inline' : 'none';
      }
      
      // Update active state
      if (userReactions && userReactions.includes(type)) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });
  }
  
  animateReaction(btn, emoji) {
    // Create floating emoji animation
    const rect = btn.getBoundingClientRect();
    const particle = document.createElement('div');
    particle.className = 'reaction-particle';
    particle.textContent = emoji;
    particle.style.left = rect.left + rect.width / 2 + 'px';
    particle.style.top = rect.top + 'px';
    particle.style.position = 'fixed';
    particle.style.pointerEvents = 'none';
    particle.style.fontSize = '32px';
    particle.style.animation = 'reactionFloat 1s ease-out forwards';
    particle.style.zIndex = '10000';
    
    document.body.appendChild(particle);
    
    setTimeout(() => particle.remove(), 1000);
    
    // Add pulse animation to button
    btn.style.animation = 'none';
    setTimeout(() => {
      btn.style.animation = 'reactionPulse 0.3s ease-out';
    }, 10);
  }
  
  formatCount(count) {
    if (count >= 1000000) {
      return (count / 1000000).toFixed(1).replace(/\.0$/, '') + 'M';
    }
    if (count >= 1000) {
      return (count / 1000).toFixed(1).replace(/\.0$/, '') + 'K';
    }
    return count.toString();
  }
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
  @keyframes reactionFloat {
    0% {
      transform: translateY(0) scale(1);
      opacity: 1;
    }
    100% {
      transform: translateY(-100px) scale(1.5);
      opacity: 0;
    }
  }
  
  @keyframes reactionPulse {
    0%, 100% {
      transform: scale(1);
    }
    50% {
      transform: scale(1.2);
    }
  }
`;
document.head.appendChild(style);

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.reactionsSystem = new ReactionsSystem();
  });
} else {
  window.reactionsSystem = new ReactionsSystem();
}
