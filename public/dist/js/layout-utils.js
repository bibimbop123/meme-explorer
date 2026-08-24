// Extracted inline scripts from layout.erb
// Date: July 19, 2026

// Navigation toggle
function toggleMobileNav() {
  const nav = document.querySelector('.mobile-nav');
  if (nav) {
    nav.classList.toggle('open');
  }
}

// Theme preference
function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('theme', theme);
}

function initTheme() {
  const savedTheme = localStorage.getItem('theme') || 'light';
  setTheme(savedTheme);
}

// Initialize on DOM load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initTheme);
} else {
  initTheme();
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { toggleMobileNav, setTheme, initTheme };
}
