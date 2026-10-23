// Opt-in browser observations, not confirmed human attention.
if (typeof document !== 'undefined' && document.querySelector('meta[name="visitor-metrics-enabled"]')) {
  let sent = false;
  let inFlight = false;
  let choiceVersion = 0;
  let observation = Promise.resolve();
  const choiceKey = 'meme_explorer_visitor_consent';
  const status = message => {
    const element = document.getElementById('visitor-privacy-status');
    if (element) element.textContent = message;
  };
  const observe = () => {
    if (sent || inFlight || document.visibilityState !== 'visible' || navigator.globalPrivacyControl || navigator.doNotTrack === '1') return;
    if (!/^\/(random|trending|search|meme\/[^/]+)?$/.test(location.pathname)) return;
    try {
      if (localStorage.getItem(choiceKey) !== 'accepted') return;
    } catch (_) { return; }
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    if (!token) return;
    sent = true;
    inFlight = true;
    const version = choiceVersion;
    const report = message => {
      if (version !== choiceVersion) return;
      try { if (localStorage.getItem(choiceKey) !== 'accepted') return; } catch (_) { return; }
      status(message);
    };
    observation = fetch('/api/visitor-observation', { method: 'POST', credentials: 'same-origin',
      headers: { 'X-CSRF-Token': token }, body: new URLSearchParams({ consent: 'accepted' }) })
      .then(response => report(response.ok ? 'Visitor observation recorded. Advertising choice is unchanged.' :
        response.status === 409 ? 'This browser identity was withdrawn. Reload to start a new visitor identity.' :
          'Consent saved, but measurement is unavailable. Reload to retry.'))
      .catch(() => report('Consent saved, but measurement could not connect. Reload to retry.'))
      .finally(() => { inFlight = false; });
  };
  const showChoice = () => {
    if (navigator.globalPrivacyControl || navigator.doNotTrack === '1') {
      status('Your browser privacy signal prevents visitor measurement.');
      return;
    }
    try {
      const choice = localStorage.getItem(choiceKey);
      status(choice === 'accepted' ? 'Visitor measurement consent is saved. Advertising choice is unchanged.' :
        choice === 'rejected' ? 'Visitor measurement is declined. Use withdrawal again if record deletion needs retrying.' :
          'Visitor measurement is off until you choose Allow.');
    } catch (_) { status('Browser storage unavailable; visitor measurement remains off.'); }
  };
  showChoice();
  observe();
  document.addEventListener('visibilitychange', observe);
  window.addEventListener('storage', event => {
    if (event && event.key !== null && event.key !== choiceKey) return;
    choiceVersion++;
    showChoice();
    observe();
  });
  document.getElementById('visitor-allow')?.addEventListener('click', () => {
    if (navigator.globalPrivacyControl || navigator.doNotTrack === '1') {
      status('Your browser privacy signal prevents visitor measurement.');
      return;
    }
    try { localStorage.setItem(choiceKey, 'accepted'); }
    catch (_) { status('Browser storage unavailable; visitor measurement remains off.'); return; }
    status('Visitor measurement consent saved. Advertising choice is unchanged.');
    sent = false;
    observe();
  });
  document.getElementById('visitor-withdraw')?.addEventListener('click', async () => {
    choiceVersion++;
    sent = true;
    try { localStorage.setItem(choiceKey, 'rejected'); }
    catch (_) { status('Could not save your choice. Browser storage must be available to remember withdrawal.'); return; }
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    try {
      await observation;
      const response = await fetch('/api/visitor-withdrawal', { method: 'POST', credentials: 'same-origin', headers: { 'X-CSRF-Token': token || '' } });
      status(response.ok ? 'Visitor measurement declined. Visit time and cookie cleared; a temporary suppression key prevents late observations.' : 'Collection stopped in this browser. Server withdrawal failed; retry withdrawal.');
    } catch (_) { status('Collection stopped in this browser. Server withdrawal unavailable; retry withdrawal.'); }
  });
}