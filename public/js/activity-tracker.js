// Activity Tracker - Real-time user activity display
// Updates live user counts every 10 seconds

class ActivityTracker {
  constructor() {
    this.updateInterval = 10000; // 10 seconds
    this.activityElement = null;
    this.isActive = false;
  }
  
  init() {
    // Find or create activity display element
    this.activityElement = document.querySelector('.live-activity');
    
    if (!this.activityElement) {
      // Create element if it doesn't exist
      this.createActivityElement();
    }
    
    // Start tracking
    this.startTracking();
  }
  
  createActivityElement() {
    const element = document.createElement('div');
    element.className = 'live-activity';
    element.innerHTML = '🔥 <span class="count">...</span> people viewing memes right now';
    
    // Add to header or create floating badge
    const header = document.querySelector('header nav');
    if (header) {
      header.appendChild(element);
    } else {
      // Floating badge
      element.style.cssText = `
        position: fixed;
        top: 10px;
        right: 10px;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 8px 16px;
        border-radius: 20px;
        font-size: 0.9rem;
        font-weight: 600;
        box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        z-index: 1000;
        animation: fadeIn 0.3s ease-out;
      `;
      document.body.appendChild(element);
    }
    
    this.activityElement = element;
  }
  
  async startTracking() {
    if (this.isActive) return;
    
    this.isActive = true;
    
    // Initial fetch
    await this.updateActivityCount();
    
    // Periodic updates
    setInterval(async () => {
      if (this.isActive) {
        await this.updateActivityCount();
      }
    }, this.updateInterval);
  }
  
  async updateActivityCount() {
    try {
      const response = await fetch('/api/activity-stats');
      
      if (!response.ok) {
        console.warn('[Activity Tracker] API not available');
        return;
      }
      
      const data = await response.json();
      
      // Update display
      const countElement = this.activityElement.querySelector('.count');
      if (countElement) {
        const newCount = data.viewing_users || data.active_users || 0;
        const oldCount = parseInt(countElement.textContent) || 0;
        
        // Animate count change
        if (newCount !== oldCount) {
          this.animateCountChange(countElement, oldCount, newCount);
        }
      } else {
        // Fallback if no count element
        this.activityElement.textContent = `🔥 ${data.viewing_users || 0} people viewing memes right now`;
      }
      
      // Add pulse animation on update
      this.activityElement.classList.add('pulse');
      setTimeout(() => {
        this.activityElement.classList.remove('pulse');
      }, 300);
      
    } catch (error) {
      console.warn('[Activity Tracker] Error fetching stats:', error.message);
      // Don't show error to user, just skip update
    }
  }
  
  animateCountChange(element, from, to) {
    // Smooth number transition
    const duration = 500; // ms
    const steps = 20;
    const stepDuration = duration / steps;
    const increment = (to - from) / steps;
    
    let current = from;
    let step = 0;
    
    const interval = setInterval(() => {
      step++;
      current += increment;
      
      if (step >= steps) {
        element.textContent = to;
        clearInterval(interval);
      } else {
        element.textContent = Math.round(current);
      }
    }, stepDuration);
  }
  
  stop() {
    this.isActive = false;
  }
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.activityTracker = new ActivityTracker();
    window.activityTracker.init();
  });
} else {
  window.activityTracker = new ActivityTracker();
  window.activityTracker.init();
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(-10px); }
    to { opacity: 1; transform: translateY(0); }
  }
  
  .live-activity.pulse {
    animation: pulse 0.3s ease-out;
  }
  
  @keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.05); }
  }
  
  .live-activity {
    transition: all 0.3s ease;
  }
  
  .live-activity:hover {
    transform: scale(1.05);
    cursor: default;
  }
`;
document.head.appendChild(style);
