/**
 * COLLAPSIBLE GAMIFICATION - WEEK 2
 * Move stats/achievements to collapsible panel
 * Keeps main view focused on content
 */

(function() {
  'use strict';
  
  const CollapsibleGamification = {
    init() {
      this.createCollapsedView();
      this.setupToggle();
    },
    
    createCollapsedView() {
      // Find existing gamification elements
      const streakBadge = document.querySelector('.streak-badge, [data-streak]');
      const pointsDisplay = document.querySelector('.points-display, [data-points]');
      
      if (!streakBadge && !pointsDisplay) return;
      
      // Create collapsed view
      const collapsed = document.createElement('div');
      collapsed.className = 'gamification-collapsed';
      collapsed.setAttribute('data-gamification-toggle', '');
      collapsed.innerHTML = `
        <div class="stats-preview">
          <span class="stats-icon">🎮</span>
          <span class="stats-text">
            ${this.getStreakText(streakBadge)}
            ${this.getPointsText(pointsDisplay)}
          </span>
          <span class="expand-icon">▼</span>
        </div>
      `;
      
      document.body.appendChild(collapsed);
      
      // Hide original gamification elements (keep in DOM for functionality)
      const gamificationSection = document.querySelector('.gamification-section, .achievements-panel');
      if (gamificationSection) {
        gamificationSection.style.display = 'none';
        gamificationSection.setAttribute('data-hidden-by-simplified', 'true');
      }
    },
    
    getStreakText(element) {
      if (!element) return '';
      const streak = element.getAttribute('data-streak') || element.textContent.match(/\d+/)?.[0] || '0';
      return `🔥 ${streak}`;
    },
    
    getPointsText(element) {
      if (!element) return '';
      const points = element.getAttribute('data-points') || element.textContent.match(/\d+/)?.[0] || '0';
      return `⭐ ${points}`;
    },
    
    setupToggle() {
      document.addEventListener('click', (e) => {
        const toggle = e.target.closest('[data-gamification-toggle]');
        if (!toggle) return;
        
        this.togglePanel();
      });
    },
    
    togglePanel() {
      const collapsed = document.querySelector('.gamification-collapsed');
      
      if (collapsed) {
        this.showExpandedPanel();
        collapsed.remove();
      } else {
        this.hideExpandedPanel();
      }
    },
    
    showExpandedPanel() {
      const expanded = document.createElement('div');
      expanded.className = 'gamification-expanded';
      expanded.innerHTML = `
        <button class="close-btn" onclick="this.closest('.gamification-expanded').remove(); CollapsibleGamification.init();">×</button>
        <h2 style="margin: 0 0 20px 0;">Your Stats</h2>
        <div id="gamification-content"></div>
      `;
      
      document.body.appendChild(expanded);
      
      // Move original gamification content to expanded panel
      const hiddenSection = document.querySelector('[data-hidden-by-simplified]');
      if (hiddenSection) {
        const content = hiddenSection.cloneNode(true);
        content.style.display = 'block';
        content.removeAttribute('data-hidden-by-simplified');
        expanded.querySelector('#gamification-content').appendChild(content);
      }
    },
    
    hideExpandedPanel() {
      const expanded = document.querySelector('.gamification-expanded');
      if (expanded) {
        expanded.remove();
      }
      
      // Recreate collapsed view
      this.createCollapsedView();
    }
  };
  
  // Make available globally for inline handlers
  window.CollapsibleGamification = CollapsibleGamification;
  
  // Initialize
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => CollapsibleGamification.init());
  } else {
    CollapsibleGamification.init();
  }
})();
