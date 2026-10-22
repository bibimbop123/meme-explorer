// Opt-in browser observations, not confirmed human attention.
if (typeof document !== 'undefined' && document.querySelector('meta[name="visitor-metrics-enabled"]')) {
  let sent = false;
  const observe = () => {
    if (sent || document.visibilityState !== 'visible' || navigator.globalPrivacyControl || navigator.doNotTrack === '1') return;
    if (!/^\/(random|trending|search|meme\/[^/]+)?$/.test(location.pathname)) return;
    try {
      if (localStorage.getItem('meme_explorer_cookie_consent') !== 'accepted') return;
    } catch (_) { return; }
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    if (!token) return;
    sent = true;
    fetch('/api/visitor-observation', { method: 'POST', credentials: 'same-origin',
      headers: { 'X-CSRF-Token': token }, body: new URLSearchParams({ consent: 'accepted' }) }).catch(() => {});
  };
  observe();
  document.addEventListener('visibilitychange', observe);
  window.addEventListener('storage', observe);
  // Existing consent buttons write storage synchronously in their click handler.
  document.addEventListener('click', () => setTimeout(observe, 0));
}