/**
 * PROGRESSIVE DISCLOSURE - WEEK 2
 * Gradually reveal features as user engages
 * Reduces upfront complexity
 */

(function() {
  'use strict';
  
  const ProgressiveDisclosure = {
    init() {
      this.memeCount = parseInt(localStorage.getItem('memes-viewed') || '0');
      this.checkMilestones();
      this.trackMemeViews();
    },
    
    trackMemeViews() {
      // Listen for meme navigation
      const observer = new MutationObserver(() => {
        this.incrementMemeCount();
      });
      
      const memeContainer = document.querySelector('.meme-display, .meme-container, #meme-image');
      if (memeContainer) {
        observer.observe(memeContainer, {
          attributes: true,
          attributeFilter: ['src', 'data-meme-id']
        });
      }
      
      // Also listen for URL changes (SPA navigation)
      let lastUrl = location.href;
      new MutationObserver(() => {
        if (location.href !== lastUrl) {
          lastUrl = location.href;
          this.incrementMemeCount();
        }
      }).observe(document, {subtree: true, childList: true});
    },
    
    incrementMemeCount() {
      this.memeCount++;
      localStorage.setItem('memes-viewed', this.memeCount);
      this.checkMilestones();
    },
    
    checkMilestones() {
      // Milestone 1: After 5 memes, introduce keyboard shortcuts
      if (this.memeCount === 5 && !this.hasSeenMilestone('keyboard-shortcuts')) {
        this.showFeatureUnlock({
          title: '⌨️ Keyboard Shortcuts Unlocked!',
          description: "You've viewed 5 memes! Press Space for next, L to like, S to save.",
          cta: 'Try it now',
          milestone: 'keyboard-shortcuts'
        });
      }
      
      // Milestone 2: After 10 memes, introduce gamification
      if (this.memeCount === 10 && !this.hasSeenMilestone('gamification')) {
        this.showFeatureUnlock({
          title: '🎮 Stats Tracking Unlocked!',
          description: 'Check your stats in the top-right corner. Build streaks, earn achievements!',
          cta: 'View Stats',
          milestone: 'gamification',
          callback: () => this.openGamificationPanel()
        });
      }
      
      // Milestone 3: After 25 memes, introduce saved collections
      if (this.memeCount === 25 && !this.hasSeenMilestone('collections')) {
        this.showFeatureUnlock({
          title: '⭐ Collections Available!',
          description: 'Create custom meme collections. Save your favorites and share them!',
          cta: 'Create Collection',
          milestone: 'collections'
        });
      }
    },
    
    hasSeenMilestone(name) {
      return localStorage.getItem(`milestone-${name}`) === '1';
    },
    
    markMilestoneSeen(name) {
      localStorage.setItem(`milestone-${name}`, '1');
    },
    
    showFeatureUnlock(options) {
      const {title, description, cta, milestone, callback} = options;
      
      const unlock = document.createElement('div');
      unlock.className = 'feature-unlock';
      unlock.innerHTML = `
        <div style="font-size: 48px; margin-bottom: 16px;">🎉</div>
        <h3>${title}</h3>
        <p>${description}</p>
        <button class="unlock-cta">${cta}</button>
      `;
      
      document.body.appendChild(unlock);
      
      // Handle CTA click
      const ctaBtn = unlock.querySelector('.unlock-cta');
      ctaBtn.addEventListener('click', () => {
        this.markMilestoneSeen(milestone);
        unlock.remove();
        if (callback) callback();
      });
      
      // Auto-dismiss after 10 seconds
      setTimeout(() => {
        if (document.body.contains(unlock)) {
          this.markMilestoneSeen(milestone);
          unlock.remove();
        }
      }, 10000);
    },
    
    openGamificationPanel() {
      const panel = document.querySelector('.gamification-collapsed');
      if (panel) {
        panel.classList.remove('gamification-collapsed');
        panel.classList.add('gamification-expanded');
      }
    }
  };
  
  // Initialize
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => ProgressiveDisclosure.init());
  } else {
    ProgressiveDisclosure.init();
  }
})();
