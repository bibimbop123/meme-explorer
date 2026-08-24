// Dark Mode Toggle
// Respects system preference by default, allows manual override

(function() {
  'use strict';
  
  const THEME_KEY = 'meme-explorer-theme';
  
  // Get stored preference or system preference
  function getPreferredTheme() {
    const stored = localStorage.getItem(THEME_KEY);
    if (stored) {
      return stored;
    }
    
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  
  // Apply theme to document
  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    updateToggleIcon(theme);
  }
  
  // Update toggle button icon
  function updateToggleIcon(theme) {
    const toggle = document.getElementById('theme-toggle');
    if (toggle) {
      toggle.textContent = theme === 'dark' ? '☀️' : '🌙';
      toggle.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
    }
  }
  
  // Toggle theme
  function toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || getPreferredTheme();
    const next = current === 'dark' ? 'light' : 'dark';
    
    localStorage.setItem(THEME_KEY, next);
    applyTheme(next);
    
    // Track theme change
    if (typeof gtag !== 'undefined') {
      gtag('event', 'theme_change', {
        theme: next
      });
    }
  }
  
  // Initialize theme on page load
  function initTheme() {
    const theme = getPreferredTheme();
    applyTheme(theme);
    
    // Listen for system preference changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem(THEME_KEY)) {
        applyTheme(e.matches ? 'dark' : 'light');
      }
    });
  }
  
  // Wait for DOM to be ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initTheme);
  } else {
    initTheme();
  }
  
  // Expose toggle function globally
  window.toggleTheme = toggleTheme;
})();
