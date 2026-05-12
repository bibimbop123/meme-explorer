// Surprise Rewards UI System
// Created: May 11, 2026
// Part of: Priority 2 Entertainment Enhancements
//
// Handles displaying surprise reward notifications with celebrations

window.surpriseRewards = {
  // Show reward notification with celebration
  show: function(reward) {
    if (!reward) return;
    
    console.log('🎁 Surprise reward:', reward);
    
    // Play sound if available
    if (window.soundSystem) {
      window.soundSystem.play('achievement');
    }
    
    // Trigger haptic feedback
    if (window.hapticSystem) {
      window.hapticSystem.trigger('medium');
    }
    
    // Trigger visual celebration
    this.celebrate(reward.celebration || 'confetti');
    
    // Show notification modal
    this.showModal(reward);
    
    // Track analytics
    if (typeof gtag === 'function') {
      gtag('event', 'surprise_reward', {
        reward_type: reward.type,
        reward_value: reward.xp_amount || 0
      });
    }
  },
  
  // Show notification modal
  showModal: function(reward) {
    const modal = document.createElement('div');
    modal.className = 'surprise-reward-modal';
    modal.innerHTML = `
      <div class="surprise-reward-overlay"></div>
      <div class="surprise-reward-content">
        <div class="surprise-reward-icon">${reward.icon}</div>
        <h2 class="surprise-reward-title">${reward.title}</h2>
        <p class="surprise-reward-message">${reward.message}</p>
        ${reward.duration ? `<p class="surprise-reward-duration">⏰ Active for ${this.formatDuration(reward.duration)}</p>` : ''}
        <button class="surprise-reward-button" onclick="this.closest('.surprise-reward-modal').remove()">
          Awesome! 🎉
        </button>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      if (modal.parentElement) {
        modal.classList.add('surprise-reward-fadeout');
        setTimeout(() => modal.remove(), 300);
      }
    }, 5000);
  },
  
  // Trigger celebration effect
  celebrate: function(type) {
    if (!window.particleSystem) return;
    
    const centerX = window.innerWidth / 2;
    const centerY = window.innerHeight / 2;
    
    switch (type) {
      case 'confetti':
        window.particleSystem.confetti(centerX, centerY, 80);
        break;
      case 'fireworks':
        window.particleSystem.fireworks(centerX, centerY, 5);
        break;
      case 'explosion':
        window.particleSystem.explode(centerX, centerY, 100);
        break;
      case 'sparkle':
        window.particleSystem.sparkle(centerX, centerY, 50);
        break;
      case 'shield':
        this.shieldEffect();
        break;
      default:
        window.particleSystem.confetti(centerX, centerY, 60);
    }
  },
  
  // Shield protection effect
  shieldEffect: function() {
    const shield = document.createElement('div');
    shield.className = 'shield-effect';
    shield.innerHTML = '🛡️';
    document.body.appendChild(shield);
    
    setTimeout(() => shield.remove(), 2000);
  },
  
  // Format duration in human-readable format
  formatDuration: function(seconds) {
    if (seconds >= 3600) {
      const hours = Math.floor(seconds / 3600);
      return `${hours} hour${hours > 1 ? 's' : ''}`;
    } else if (seconds >= 60) {
      const minutes = Math.floor(seconds / 60);
      return `${minutes} minute${minutes > 1 ? 's' : ''}`;
    } else {
      return `${seconds} second${seconds > 1 ? 's' : ''}`;
    }
  },
  
  // Check for rewards on page load (if any pending)
  checkPending: async function() {
    try {
      const response = await fetch('/api/surprise-rewards/check');
      if (!response.ok) return;
      
      const data = await response.json();
      if (data.reward) {
        this.show(data.reward);
      }
    } catch (error) {
      console.error('Error checking for rewards:', error);
    }
  },
  
  // Display active boosts in UI
  showActiveBoosts: function(boosts) {
    if (!boosts || boosts.length === 0) return;
    
    const container = document.getElementById('active-boosts-container');
    if (!container) {
      // Create container if it doesn't exist
      const newContainer = document.createElement('div');
      newContainer.id = 'active-boosts-container';
      newContainer.className = 'active-boosts-container';
      document.body.appendChild(newContainer);
    }
    
    const boostsHTML = boosts.map(boost => {
      const expiresIn = this.formatDuration(boost.expires_in);
      return `
        <div class="active-boost" data-type="${boost.type}">
          <span class="boost-icon">${boost.icon}</span>
          <span class="boost-time">${expiresIn}</span>
        </div>
      `;
    }).join('');
    
    document.getElementById('active-boosts-container').innerHTML = boostsHTML;
  }
};

// Auto-check for rewards on page load (if user is logged in)
document.addEventListener('DOMContentLoaded', () => {
  if (document.body.dataset.userId) {
    setTimeout(() => window.surpriseRewards.checkPending(), 1000);
  }
});

// Inline styles (check if already injected to prevent duplicate declaration errors)
if (!document.getElementById('surprise-rewards-styles')) {
  const style = document.createElement('style');
  style.id = 'surprise-rewards-styles';
  style.textContent = `
  .surprise-reward-modal {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    z-index: 10000;
    display: flex;
    align-items: center;
    justify-content: center;
    animation: fadeIn 0.3s ease-out;
  }
  
  .surprise-reward-overlay {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(5px);
  }
  
  .surprise-reward-content {
    position: relative;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    padding: 3rem 2rem;
    border-radius: 20px;
    text-align: center;
    color: white;
    max-width: 400px;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
    animation: bounceIn 0.6s cubic-bezier(0.68, -0.55, 0.265, 1.55);
  }
  
  .surprise-reward-icon {
    font-size: 5rem;
    margin-bottom: 1rem;
    animation: pulse 0.8s ease-in-out infinite;
  }
  
  .surprise-reward-title {
    font-size: 2rem;
    font-weight: bold;
    margin: 0 0 1rem 0;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
  }
  
  .surprise-reward-message {
    font-size: 1.2rem;
    margin: 0 0 1rem 0;
    opacity: 0.95;
  }
  
  .surprise-reward-duration {
    font-size: 0.9rem;
    opacity: 0.8;
    margin: 0.5rem 0 1.5rem 0;
  }
  
  .surprise-reward-button {
    background: white;
    color: #667eea;
    border: none;
    padding: 0.8rem 2rem;
    border-radius: 10px;
    font-size: 1.1rem;
    font-weight: bold;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
  }
  
  .surprise-reward-button:hover {
    transform: scale(1.05);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.3);
  }
  
  .surprise-reward-fadeout {
    animation: fadeOut 0.3s ease-out forwards;
  }
  
  .shield-effect {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%) scale(0);
    font-size: 15rem;
    z-index: 9999;
    animation: shieldPulse 2s ease-out forwards;
    pointer-events: none;
  }
  
  .active-boosts-container {
    position: fixed;
    top: 80px;
    right: 20px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    z-index: 999;
  }
  
  .active-boost {
    background: linear-gradient(135deg, rgba(102, 126, 234, 0.9) 0%, rgba(118, 75, 162, 0.9) 100%);
    padding: 10px 16px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    gap: 8px;
    color: white;
    font-weight: bold;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    animation: slideInRight 0.3s ease-out;
  }
  
  .boost-icon {
    font-size: 1.5rem;
  }
  
  .boost-time {
    font-size: 0.85rem;
    opacity: 0.9;
  }
  
  @keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.1); }
  }
  
  @keyframes shieldPulse {
    0% { transform: translate(-50%, -50%) scale(0); opacity: 0; }
    50% { transform: translate(-50%, -50%) scale(1.2); opacity: 1; }
    100% { transform: translate(-50%, -50%) scale(1.5); opacity: 0; }
  }
  
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  
  @keyframes fadeOut {
    from { opacity: 1; }
    to { opacity: 0; }
  }
  
  @keyframes bounceIn {
    0% { transform: scale(0.3); opacity: 0; }
    50% { transform: scale(1.05); }
    70% { transform: scale(0.9); }
    100% { transform: scale(1); opacity: 1; }
  }
  
  @keyframes slideInRight {
    from { transform: translateX(400px); opacity: 0; }
    to { transform: translateX(0); opacity: 1; }
  }
`;
  document.head.appendChild(style);
}
