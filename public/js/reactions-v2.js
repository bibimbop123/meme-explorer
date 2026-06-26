// Reactions V2 - Multiple reaction types

class ReactionsV2 {
  constructor() {
    this.reactions = ['laugh', 'wow', 'cry', 'fire', 'dead'];
    this.emojis = {
      laugh: '😂',
      wow: '😮',
      cry: '😭',
      fire: '🔥',
      dead: '💀'
    };
    this.init();
  }
  
  init() {
    document.addEventListener('click', (e) => {
      if (e.target.matches('[data-reaction-btn]')) {
        this.handleReaction(e.target);
      }
    });
    
    // Load reactions for visible memes
    this.loadVisibleReactions();
    
    // Real-time updates via WebSocket
    if (window.wsClient) {
      window.wsClient.on('reaction:update', (data) => {
        this.updateReactionDisplay(data.meme_id, data.reactions);
      });
    }
  }
  
  async handleReaction(btn) {
    const memeId = btn.dataset.memeId;
    const reactionType = btn.dataset.reactionType;
    const isActive = btn.classList.contains('active');
    
    if (isActive) {
      // Remove reaction
      await this.removeReaction(memeId, reactionType);
    } else {
      // Add reaction
      await this.addReaction(memeId, reactionType);
    }
  }
  
  async addReaction(memeId, reactionType) {
    try {
      const response = await fetch(`/memes/${memeId}/reactions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ reaction_type: reactionType })
      });
      
      const data = await response.json();
      
      if (data.success) {
        this.updateReactionDisplay(memeId, data.reactions);
        this.animateReaction(memeId, reactionType);
      }
    } catch (error) {
      console.error('Reaction error:', error);
    }
  }
  
  async removeReaction(memeId, reactionType) {
    try {
      const response = await fetch(`/memes/${memeId}/reactions/${reactionType}`, {
        method: 'DELETE'
      });
      
      const data = await response.json();
      
      if (data.success) {
        this.updateReactionDisplay(memeId, data.reactions);
      }
    } catch (error) {
      console.error('Reaction removal error:', error);
    }
  }
  
  updateReactionDisplay(memeId, reactions) {
    const container = document.querySelector(`[data-reactions-for="${memeId}"]`);
    if (!container) return;
    
    this.reactions.forEach(type => {
      const btn = container.querySelector(`[data-reaction-type="${type}"]`);
      const count = reactions[type] || 0;
      
      if (btn) {
        const countEl = btn.querySelector('.reaction-count');
        if (countEl) {
          countEl.textContent = count > 0 ? this.formatCount(count) : '';
        }
      }
    });
  }
  
  animateReaction(memeId, reactionType) {
    const emoji = this.emojis[reactionType];
    const container = document.querySelector(`[data-meme-id="${memeId}"]`);
    
    if (!container) return;
    
    const particle = document.createElement('div');
    particle.className = 'reaction-particle';
    particle.textContent = emoji;
    particle.style.left = Math.random() * 100 + '%';
    
    container.appendChild(particle);
    
    setTimeout(() => particle.remove(), 1000);
  }
  
  formatCount(count) {
    if (count >= 1000000) {
      return (count / 1000000).toFixed(1) + 'M';
    }
    if (count >= 1000) {
      return (count / 1000).toFixed(1) + 'K';
    }
    return count.toString();
  }
  
  async loadVisibleReactions() {
    const memeCards = document.querySelectorAll('[data-meme-id]');
    
    memeCards.forEach(async (card) => {
      const memeId = card.dataset.memeId;
      
      try {
        const response = await fetch(`/memes/${memeId}/reactions`);
        const data = await response.json();
        
        this.updateReactionDisplay(memeId, data.reactions);
        
        // Highlight user's reaction
        if (data.user_reaction) {
          const btn = card.querySelector(`[data-reaction-type="${data.user_reaction}"]`);
          if (btn) btn.classList.add('active');
        }
      } catch (error) {
        console.error('Load reactions error:', error);
      }
    });
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  new ReactionsV2();
});
