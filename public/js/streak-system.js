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
    // Streak badge disabled
    return;
  }

  showStreakIncrement(streak) {
    // Streak increment popup disabled
    return;
  }

  showNewRecord() {
    // New record popup disabled
    return;
  }

  showStreakBroken(brokenStreak) {
    // Streak broken popup disabled
    return;
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
