// Single theme owner; loaded before first paint.
(() => {
  const root = document.documentElement;
  const system = window.matchMedia('(prefers-color-scheme: dark)');
  const valid = value => value === 'dark' || value === 'light';
  let preference = null;
  try {
    const stored = localStorage.getItem('meme-explorer-theme');
    const legacy = localStorage.getItem('theme');
    preference = valid(stored) ? stored : valid(legacy) ? legacy : null;
  } catch (_) {}
  const apply = theme => {
    root.setAttribute('data-theme', theme);
    root.classList.toggle('dark-mode', theme === 'dark');
    const button = document.getElementById('darkModeToggle');
    if (button) {
      button.textContent = theme === 'dark' ? '☀️' : '🌙';
      button.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
      button.setAttribute('aria-pressed', String(theme === 'dark'));
    }
  };
  const preferred = () => preference || (system.matches ? 'dark' : 'light');
  const toggle = () => {
    preference = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    try { localStorage.setItem('meme-explorer-theme', preference); } catch (_) {}
    apply(preference);
  };
  apply(preferred());
  const initialize = () => {
    apply(preferred());
    document.getElementById('darkModeToggle')?.addEventListener('click', toggle);
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
  system.addEventListener('change', () => { if (!preference) apply(preferred()); });
  document.addEventListener('keydown', event => {
    if (event.repeat || event.defaultPrevented || !(event.metaKey || event.ctrlKey) || event.key.toLowerCase() !== 'k') return;
    if (event.target.closest?.('input, textarea, select, [contenteditable]')) return;
    event.preventDefault();
    toggle();
  });
  window.toggleTheme = toggle;
})();
