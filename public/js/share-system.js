// Exact-content share bar. Resolve identity at click time, never page-load time.
export function exactShareData(container) {
  const viewer = container.querySelector('#meme-display');
  const path = viewer
    ? document.querySelector('#viewer-share-data')?.dataset.sharePath
    : container.dataset.sharePath;
  if (!/^\/meme\/[a-f0-9]{64}$/.test(path || '')) return null;
  const title = String(viewer
    ? document.querySelector('#viewer-meme-title')?.textContent || 'Meme Explorer'
    : container.dataset.title || 'Meme Explorer').trim().slice(0, 180);
  return { title, url: new URL(path, window.location.href).href };
}

export function twitterIntent(data) {
  const intent = new URL('https://twitter.com/intent/tweet');
  intent.search = new URLSearchParams({ text: data.title, url: data.url }).toString();
  return intent.href;
}

export function initializeShareButtons() {
  document.querySelectorAll('.meme-container, .meme-detail, .meme-card').forEach(container => {
    // Cards without an explicit exact link must not share a misleading homepage.
    if (!container.querySelector('#meme-display') && !container.dataset.sharePath) return;
    if (container.querySelector('.share-bar')) return;
    const bar = document.createElement('div');
    bar.className = 'share-bar';
    const status = document.createElement('p');
    status.setAttribute('role', 'status');
    status.setAttribute('aria-live', 'polite');
    for (const [action, label] of [['whatsapp', 'WhatsApp'], ['twitter', 'Tweet'], ['copy', 'Copy Link']]) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = `share-btn ${action}`;
      button.textContent = label;
      button.addEventListener('click', async () => {
        const data = exactShareData(container);
        if (!data) {
          status.textContent = 'An exact link is unavailable for this meme. Please try again later.';
          return;
        }
        status.textContent = '';
        if (action === 'twitter') {
          window.open(twitterIntent(data), '_blank', 'noopener,noreferrer,width=550,height=420');
        } else if (action === 'whatsapp') {
          const intent = new URL('https://wa.me/');
          intent.search = new URLSearchParams({ text: `${data.title} ${data.url}` }).toString();
          window.open(intent.href, '_blank', 'noopener,noreferrer');
        } else {
          try {
            await navigator.clipboard.writeText(data.url);
            status.textContent = 'Exact meme link copied.';
          } catch (_) {
            status.textContent = `Could not copy automatically. Exact meme link: ${data.url}`;
          }
        }
      });
      bar.appendChild(button);
    }
    bar.appendChild(status);
    container.appendChild(bar);
  });
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeShareButtons);
else initializeShareButtons();
