// Extracted inline scripts from layout.erb
// Date: July 19, 2026

// Navigation toggle
function toggleMobileNav() {
  const nav = document.querySelector('.mobile-nav');
  if (nav) {
    nav.classList.toggle('open');
  }
}

// Initialize on DOM load
function initNavigationDisclosure() {
  const toggle = document.getElementById('menuToggle');
  const menu = document.getElementById('hamburgerMenu');
  if (!toggle || !menu || toggle.dataset.disclosureReady) return;
  toggle.dataset.disclosureReady = 'true';
  const setOpen = open => {
    menu.hidden = !open;
    menu.classList.toggle('active', open);
    toggle.setAttribute('aria-expanded', String(open));
  };
  setOpen(false);
  toggle.addEventListener('click', () => setOpen(menu.hidden));
  document.addEventListener('click', event => {
    if (!toggle.contains(event.target) && !menu.contains(event.target)) setOpen(false);
  });
  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape' || menu.hidden) return;
    event.preventDefault();
    setOpen(false);
    toggle.focus();
  });
  document.addEventListener('focusin', event => {
    if (!toggle.contains(event.target) && !menu.contains(event.target)) setOpen(false);
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initNavigationDisclosure);
} else {
  initNavigationDisclosure();
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { toggleMobileNav, initNavigationDisclosure };
}
