// PWA Install Prompt
// Shows install banner for installable PWAs

(function() {
  'use strict';
  
  let deferredPrompt = null;
  const PROMPT_DISMISSED_KEY = 'pwa-prompt-dismissed';
  const PROMPT_DELAY = 30000; // 30 seconds
  
  // Check if user previously dismissed
  function wasPromptDismissed() {
    const dismissed = localStorage.getItem(PROMPT_DISMISSED_KEY);
    if (!dismissed) return false;
    
    // Reset after 7 days
    const dismissedDate = new Date(dismissed);
    const daysSince = (Date.now() - dismissedDate.getTime()) / (1000 * 60 * 60 * 24);
    return daysSince < 7;
  }
  
  // Show install prompt
  function showInstallPrompt() {
    if (!deferredPrompt || wasPromptDismissed()) {
      return;
    }
    
    const banner = document.createElement('div');
    banner.id = 'pwa-install-banner';
    banner.className = 'pwa-install-banner';
    banner.innerHTML = `
      <div class="pwa-banner-content">
        <span class="pwa-icon">📱</span>
        <div class="pwa-text">
          <strong>Install Meme Explorer</strong>
          <p>Get the app experience with offline access!</p>
        </div>
        <div class="pwa-actions">
          <button id="pwa-install-btn" class="btn btn-primary btn-sm">Install</button>
          <button id="pwa-dismiss-btn" class="btn btn-secondary btn-sm">Not now</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(banner);
    
    // Install button click
    document.getElementById('pwa-install-btn').addEventListener('click', async () => {
      banner.remove();
      deferredPrompt.prompt();
      const { outcome } = await deferredPrompt.userChoice;
      
      if (typeof gtag !== 'undefined') {
        gtag('event', 'pwa_install', {
          outcome: outcome
        });
      }
      
      deferredPrompt = null;
    });
    
    // Dismiss button click
    document.getElementById('pwa-dismiss-btn').addEventListener('click', () => {
      banner.remove();
      localStorage.setItem(PROMPT_DISMISSED_KEY, new Date().toISOString());
      
      if (typeof gtag !== 'undefined') {
        gtag('event', 'pwa_prompt_dismissed');
      }
    });
  }
  
  // Listen for beforeinstallprompt event
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    
    // Show prompt after delay
    setTimeout(showInstallPrompt, PROMPT_DELAY);
  });
  
  // Listen for successful install
  window.addEventListener('appinstalled', () => {
    deferredPrompt = null;
    
    if (typeof gtag !== 'undefined') {
      gtag('event', 'pwa_installed');
    }
  });
})();
