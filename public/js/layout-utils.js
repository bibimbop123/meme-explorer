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
    if (open) {
      const header = toggle.closest?.('.main-nav');
      const bottom = header?.getBoundingClientRect().bottom;
      if (Number.isFinite(bottom)) {
        const top = Math.max(8, Math.min(bottom + 8, window.innerHeight - 64));
        menu.style.top = `${top}px`;
        menu.style.maxHeight = `${Math.max(48, window.innerHeight - top - 8)}px`;
      }
    }
    menu.hidden = !open;
    menu.classList.toggle('active', open);
    toggle.setAttribute('aria-expanded', String(open));
  };
  setOpen(false);
  toggle.addEventListener('click', () => setOpen(menu.hidden));
  if (typeof window !== 'undefined') {
    const closeForLayoutChange = () => {
      if (menu.hidden) return;
      const focusedInside = menu.contains(document.activeElement);
      setOpen(false);
      if (focusedInside) toggle.focus({ preventScroll: true });
    };
    window.addEventListener('resize', closeForLayoutChange);
    window.addEventListener('scroll', closeForLayoutChange, { passive: true });
  }
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
// Avoid fragment navigation reaching the viewer's content-history popstate handler.
document.querySelector('.skip-to-content')?.addEventListener('click', event => {
  const main = document.getElementById('main-content');
  if (!main) return;
  event.preventDefault();
  main.focus({ preventScroll: true });
  main.scrollIntoView({ block: 'start', behavior: 'instant' });
});

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { toggleMobileNav, initNavigationDisclosure };
}
