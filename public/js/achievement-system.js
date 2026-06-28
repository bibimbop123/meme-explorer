/**
 * Achievement & Milestone System
 * Creates delightful moments of recognition for users
 * Triggers at key milestones to boost engagement and retention
 */

class AchievementSystem {
  constructor() {
    this.sessionMemes = 0;
    this.totalViewed = this.loadTotalViewed();
    this.achievements = this.loadAchievements();
    this.init();
  }

  init() {
    // Track each meme view
    this.trackMemeView();
    
    // Check for milestones
    this.checkMilestones();
  }

  trackMemeView() {
    this.sessionMemes++;
    this.totalViewed++;
    this.saveTotalViewed();
    this.checkMilestones();
  }

  checkMilestones() {
    const milestones = [
      // Session milestones
      { key: 'session_5', count: 5, type: 'session', title: '🔥 On Fire!', message: "5 memes in this session" },
      { key: 'session_10', count: 10, type: 'session', title: '⚡ Power User!', message: "10 memes in one session!" },
      { key: 'session_25', count: 25, type: 'session', title: '🚀 Unstoppable!', message: "25 memes! You're on a roll!" },
      { key: 'session_50', count: 50, type: 'session', title: '🏆 Legend Status!', message: "50 memes in one session!" },
      
      // Total milestones
      { key: 'total_10', count: 10, type: 'total', title: '👀 Getting Started!', message: "10 total memes viewed" },
      { key: 'total_50', count: 50, type: 'total', title: '🎯 Meme Explorer!', message: "50 memes explored" },
      { key: 'total_100', count: 100, type: 'total', title: '💯 Century Club!', message: "100 memes discovered!" },
      { key: 'total_250', count: 250, type: 'total', title: '⭐ Meme Connoisseur!', message: "250 memes enjoyed" },
      { key: 'total_500', count: 500, type: 'total', title: '👑 Meme Royalty!', message: "500 memes and counting!" },
      { key: 'total_1000', count: 1000, type: 'total', title: '🌟 Meme Master!', message: "1,000 memes! Legendary!" },
    ];

    milestones.forEach(milestone => {
      const count = milestone.type === 'session' ? this.sessionMemes : this.totalViewed;
      
      if (count === milestone.count && !this.achievements[milestone.key]) {
        this.unlockAchievement(milestone);
      }
    });
  }

  unlockAchievement(milestone) {
    // Mark as achieved
    this.achievements[milestone.key] = true;
    this.saveAchievements();
    
    // Show achievement popup
    this.showAchievementPopup(milestone);
    
    // Optional: Play sound
    this.playAchievementSound();
  }

  showAchievementPopup(milestone) {
    const popup = document.createElement('div');
    popup.className = 'achievement-popup';
    popup.innerHTML = `
      <div class="achievement-content">
        <div class="achievement-icon">🎉</div>
        <div class="achievement-title">${milestone.title}</div>
        <div class="achievement-message">${milestone.message}</div>
      </div>
    `;
    
    document.body.appendChild(popup);
    
    // Animate in
    setTimeout(() => popup.classList.add('show'), 10);
    
    // Auto-remove after 4 seconds
    setTimeout(() => {
      popup.classList.remove('show');
      setTimeout(() => popup.remove(), 300);
    }, 4000);
  }

  playAchievementSound() {
    // Optional: Add a subtle sound effect
    // For now, just use browser's default behavior
    if (navigator.vibrate) {
      navigator.vibrate([50, 30, 50]); // Subtle haptic feedback on mobile
    }
  }

  // LocalStorage helpers
  loadTotalViewed() {
    return parseInt(localStorage.getItem('meme_total_viewed') || '0', 10);
  }

  saveTotalViewed() {
    localStorage.setItem('meme_total_viewed', this.totalViewed.toString());
  }

  loadAchievements() {
    const stored = localStorage.getItem('meme_achievements');
    return stored ? JSON.parse(stored) : {};
  }

  saveAchievements() {
    localStorage.setItem('meme_achievements', JSON.stringify(this.achievements));
  }

  // Public method to trigger milestone check (call when viewing a meme)
  static trackView() {
    if (!window.achievementSystem) {
      window.achievementSystem = new AchievementSystem();
    } else {
      window.achievementSystem.trackMemeView();
    }
  }

  // Get stats for display
  static getStats() {
    if (!window.achievementSystem) {
      window.achievementSystem = new AchievementSystem();
    }
    return {
      sessionMemes: window.achievementSystem.sessionMemes,
      totalViewed: window.achievementSystem.totalViewed,
      achievements: Object.keys(window.achievementSystem.achievements).length
    };
  }
}

// Auto-initialize on load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.achievementSystem = new AchievementSystem();
  });
} else {
  window.achievementSystem = new AchievementSystem();
}

// Expose globally
window.AchievementSystem = AchievementSystem;
