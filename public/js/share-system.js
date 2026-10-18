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

export function currentShareImage(container) {
  const image = container.querySelector('.gallery-slide.active img') || container.querySelector('#meme-image');
  if (!image || image.dataset.mediaFailed === 'true') return null;
  try {
    const url = new URL(image.currentSrc || image.src, window.location.href);
    if (url.origin === window.location.origin && url.pathname.startsWith('/images/')) return url.href;
    if (url.protocol === 'https:' && !url.username && !url.password &&
        ['i.redd.it', 'preview.redd.it', 'external-preview.redd.it', 'i.imgur.com'].includes(url.hostname) &&
        !url.port) return url.href;
  } catch (_) {}
  return null;
}

export async function prepareImageFile(mediaUrl) {
  const url = new URL(mediaUrl);
  const local = url.origin === window.location.origin;
  const response = await fetch(local ? url.href : `/download?${new URLSearchParams({ url: url.href })}`);
  if (!response.ok) throw new Error('Image unavailable');
  const blob = await response.blob();
  const extensions = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' };
  const type = blob.type.split(';')[0].toLowerCase();
  if (!extensions[type] || !blob.size || blob.size > 10 * 1024 * 1024) throw new Error('Unsupported image');
  return new File([blob], `meme-explorer.${extensions[type]}`, { type });
}

function addImageShare(container, bar, status) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'share-btn share-image';
  button.textContent = 'Share image';
  const recovery = document.createElement('div');
  recovery.hidden = true;
  let prepared = null;
  const fallback = (media, data) => {
    recovery.replaceChildren();
    const help = document.createElement('p');
    help.textContent = 'Download this image, then attach it in X. Tweet link opens a text/link composer; it cannot attach the image automatically.';
    const download = document.createElement('a');
    download.textContent = 'Download selected image';
    const url = new URL(media);
    download.href = url.origin === window.location.origin ? url.href : `/download?${new URLSearchParams({ url: media })}`;
    download.download = 'meme-explorer';
    recovery.appendChild(help);
    recovery.appendChild(download);
    const link = document.createElement('a');
    link.textContent = 'Open X with this meme link';
    link.href = twitterIntent(data);
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    recovery.appendChild(document.createTextNode(' '));
    recovery.appendChild(link);
    recovery.hidden = false;
  };
  button.addEventListener('click', async () => {
    if (button.disabled) return;
    const data = exactShareData(container);
    const media = currentShareImage(container);
    if (!data || !media) {
      prepared = null;
      recovery.hidden = true;
      button.textContent = 'Share image';
      status.textContent = 'Image sharing is unavailable for this item. Videos are not shared as poster images.';
      return;
    }
    if (prepared?.media === media && prepared.url === data.url) {
      // Second click preserves transient activation after the asynchronous download.
      try {
        await navigator.share({ files: [prepared.file], title: data.title, text: data.url });
        status.textContent = 'Image handed to your share app. Choose X if available; nothing was posted automatically.';
      } catch (error) {
        if (error.name === 'AbortError') status.textContent = 'Image sharing canceled.';
        else { status.textContent = 'Image sharing was unavailable. You can download and attach it manually.'; fallback(media, data); }
      }
      return;
    }
    prepared = null;
    recovery.hidden = true;
    button.textContent = 'Share image';
    fallback(media, data);
    if (!navigator.share || !navigator.canShare) {
      status.textContent = 'This browser cannot share image files. Download the image and attach it in X.';
      return;
    }
    button.disabled = true;
    status.textContent = 'Preparing selected image…';
    try {
      const file = await prepareImageFile(media);
      if (currentShareImage(container) !== media || exactShareData(container)?.url !== data.url) {
        status.textContent = 'The displayed image changed. Press Share image to prepare the current one.';
        recovery.hidden = true;
        return;
      }
      if (!navigator.canShare({ files: [file] })) {
        status.textContent = 'This image cannot be shared as a file here. Download and attach it in X.';
        return;
      }
      prepared = { media, url: data.url, file };
      button.textContent = 'Choose app to share image';
      status.textContent = 'Image ready. Press Choose app to share image, then select X if available.';
    } catch (_) {
      status.textContent = 'Could not prepare the image. Try downloading it to attach manually.';
    } finally { button.disabled = false; }
  });
  bar.appendChild(button);
  bar.appendChild(recovery);
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
    addImageShare(container, bar, status);
    for (const [action, label] of [['whatsapp', 'WhatsApp'], ['twitter', 'Tweet link'], ['copy', 'Copy Link']]) {
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
