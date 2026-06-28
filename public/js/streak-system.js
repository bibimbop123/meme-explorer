/**
 * Daily Streak System
 * Massive retention boost - users come back daily to maintain their streak
 * Shows current streak, best streak, and encourages daily visits
 */

class StreakSystem {
  constructor() {
    this.today = this.getToday();
    this.streakData = this.loadStreakData();
    this.init();
  }

  init() {
    this.checkStreak();
    this.showStreakBadge();
  }

  getToday() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  }

  checkStreak() {
    const lastVisit = this.streakData.lastVisit;
    const currentStreak = this.streakData.currentStreak || 0;
    const bestStreak = this.streakData.bestStreak || 0;

    if (lastVisit === this.today) {
      // Already visited today - maintain streak
      return;
    }

    const yesterday = this.getYesterday();
    
    if (lastVisit === yesterday) {
      // Consecutive day - increment streak!
      this.streakData.currentStreak = currentStreak + 1;
      this.showStreakIncrement(this.streakData.currentStreak);
      
      // New record?
      if (this.streakData.currentStreak > bestStreak) {
        this.streakData.bestStreak = this.streakData.currentStreak;
        this.showNewRecord();
      }
    } else if (lastVisit && lastVisit !== yesterday) {
      // Streak broken 💔
      if (currentStreak > 0) {
        this.showStreakBroken(currentStreak);
      }
      this.streakData.currentStreak = 1; // Start new streak
    } else {
      // First visit
      this.streakData.currentStreak = 1;
    }

    this.streakData.lastVisit = this.today;
    this.streakData.totalVisits = (this.streakData.totalVisits || 0) + 1;
    this.saveStreakData();
  }

  getYesterday() {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    return `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;
  }

  showStreakBadge() {
    const streak = this.streakData.currentStreak || 0;
    if (streak === 0) return;

    // Create floating streak badge
    const badge = document.createElement('div');
    badge.className = 'streak-badge';
    badge.innerHTML = `
      <div class="streak-content">
        <div class="streak-icon">🔥</div>
        <div class="streak-number">${streak}</div>
        <div class="streak-label">day streak</div>
      </div>
    `;

    // Position in top-right
    badge.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 9999;
      background: linear-gradient(135deg, #FF6B6B 0%, #FF8E53 100%);
      color: white;
      padding: 12px 20px;
      border-radius: 50px;
      box-shadow: 0 4px 20px rgba(255, 107, 107, 0.4);
      cursor: pointer;
      transition: all 0.3s ease;
    `;

    badge.addEventListener('mouseenter', () => {
      badge.style.transform = 'scale(1.05)';
    });

    badge.addEventListener('mouseleave', () => {
      badge.style.transform = 'scale(1)';
    });

    badge.addEventListener('click', () => {
      this.showStreakDetails();
    });

    document.body.appendChild(badge);
  }

  showStreakIncrement(streak) {
    const messages = [
      `🔥 ${streak} day streak!`,
      `💪 ${streak} days strong!`,
      `⚡ ${streak} days in a row!`,
      `🎯 ${streak} day combo!`,
      `🚀 ${streak} days unstoppable!`
    ];

    const message = messages[Math.floor(Math.random() * messages.length)];

    const popup = document.createElement('div');
    popup.className = 'streak-popup';
    popup.innerHTML = `
      <div class="streak-popup-content">
        <div class="streak-popup-icon">🎉</div>
        <div class="streak-popup-title">${message}</div>
        <div class="streak-popup-message">Come back tomorrow to keep it going!</div>
      </div>
    `;

    document.body.appendChild(popup);

    setTimeout(() => popup.classList.add('show'), 10);
    setTimeout(() => {
      popup.classList.remove('show');
      setTimeout(() => popup.remove(), 300);
    }, 3500);
  }

  showNewRecord() {
    const popup = document.createElement('div');
    popup.className = 'streak-popup record';
    popup.innerHTML = `
      <div class="streak-popup-content">
        <div class="streak-popup-icon">🏆</div>
        <div class="streak-popup-title">NEW RECORD!</div>
        <div class="streak-popup-message">Your longest streak ever!</div>
      </div>
    `;

    document.body.appendChild(popup);

    setTimeout(() => popup.classList.add('show'), 10);
    setTimeout(() => {
      popup.classList.remove('show');
      setTimeout(() => popup.remove(), 300);
    }, 4000);

    // Confetti effect
    this.triggerConfetti();
  }

  showStreakBroken(brokenStreak) {
    const popup = document.createElement('div');
    popup.className = 'streak-popup broken';
    popup.innerHTML = `
      <div class="streak-popup-content">
        <div class="streak-popup-icon">💔</div>
        <div class="streak-popup-title">Streak Broken</div>
        <div class="streak-popup-message">You had a ${brokenStreak} day streak. Starting fresh!</div>
      </div>
    `;

    document.body.appendChild(popup);

    setTimeout(() => popup.classList.add('show'), 10);
    setTimeout(() => {
      popup.classList.remove('show');
      setTimeout(() => popup.remove(), 300);
    }, 3000);
  }

  showStreakDetails() {
    const modal = document.createElement('div');
    modal.className = 'streak-modal';
    modal.innerHTML = `
      <div class="streak-modal-content">
        <button class="streak-modal-close">&times;</button>
        <h2>🔥 Your Streak</h2>
        <div class="streak-stats">
          <div class="streak-stat">
            <div class="streak-stat-number">${this.streakData.currentStreak || 0}</div>
            <div class="streak-stat-label">Current Streak</div>
          </div>
          <div class="streak-stat">
            <div class="streak-stat-number">${this.streakData.bestStreak || 0}</div>
            <div class="streak-stat-label">Best Streak</div>
          </div>
          <div class="streak-stat">
            <div class="streak-stat-number">${this.streakData.totalVisits || 0}</div>
            <div class="streak-stat-label">Total Visits</div>
          </div>
        </div>
        <p class="streak-modal-message">Visit every day to build your streak! 🚀</p>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('.streak-modal-close').addEventListener('click', () => {
      modal.remove();
    });

    modal.addEventListener('click', (e) => {
      if (e.target === modal) modal.remove();
    });
  }

  triggerConfetti() {
    // Simple confetti effect
    for (let i = 0; i < 50; i++) {
      setTimeout(() => {
        const confetti = document.createElement('div');
        confetti.textContent = ['🎉', '⭐', '✨', '🎊'][Math.floor(Math.random() * 4)];
        confetti.style.cssText = `
          position: fixed;
          top: ${Math.random() * 100}vh;
          left: ${Math.random() * 100}vw;
          font-size: ${20 + Math.random() * 20}px;
          pointer-events: none;
          z-index: 10001;
          animation: confettiFall ${2 + Math.random() * 2}s ease-out forwards;
        `;
        document.body.appendChild(confetti);
        setTimeout(() => confetti.remove(), 4000);
      }, i * 50);
    }
  }

  loadStreakData() {
    const stored = localStorage.getItem('meme_streak_data');
    return stored ? JSON.parse(stored) : {};
  }

  saveStreakData() {
    localStorage.setItem('meme_streak_data', JSON.stringify(this.streakData));
  }

  static getCurrentStreak() {
    const system = new StreakSystem();
    return system.streakData.currentStreak || 0;
  }

  static getBestStreak() {
    const system = new StreakSystem();
    return system.streakData.bestStreak || 0;
  }
}

// Auto-initialize
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.streakSystem = new StreakSystem();
  });
} else {
  window.streakSystem = new StreakSystem();
}

// Add confetti animation CSS
const style = document.createElement('style');
style.textContent = `
  @keyframes confettiFall {
    0% {
      transform: translateY(-100px) rotate(0deg);
      opacity: 1;
    }
    100% {
      transform: translateY(100vh) rotate(720deg);
      opacity: 0;
    }
  }
`;
document.head.appendChild(style);

window.StreakSystem = StreakSystem;
