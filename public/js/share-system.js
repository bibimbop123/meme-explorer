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

export async function copyImageFile(mediaUrl) {
  if (!navigator.clipboard?.write || typeof ClipboardItem === 'undefined') throw new Error('Image clipboard unavailable');
  // Start clipboard.write during the user gesture; provide PNG bytes asynchronously.
  const png = prepareImageFile(mediaUrl).then(async file => {
    if (file.type === 'image/png') return file;
    const bitmap = await createImageBitmap(file);
    try {
      // Bound additional canvas allocation, not the decoder's own allocation.
      // Keep full-resolution download available rather than silently downscaling.
      if (!Number.isFinite(bitmap.width) || !Number.isFinite(bitmap.height) ||
          bitmap.width <= 0 || bitmap.height <= 0 || bitmap.width > 8192 ||
          bitmap.height > 8192 || bitmap.width * bitmap.height > 16_000_000) {
        throw new Error('Image too large for clipboard conversion');
      }
      const canvas = document.createElement('canvas');
      canvas.width = bitmap.width;
      canvas.height = bitmap.height;
      canvas.getContext('2d').drawImage(bitmap, 0, 0);
      return await new Promise((resolve, reject) => canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error('Image conversion failed')), 'image/png'));
    } finally { bitmap.close(); }
  });
  // Clipboard permission can reject before the asynchronous image promise settles.
  // Observe rejection here as well so it cannot become an unhandled rejection.
  png.catch(() => {});
  await navigator.clipboard.write([new ClipboardItem({ 'image/png': png })]);
}

function addImageShare(container, bar, status) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'share-btn share-image';
  button.textContent = 'Share image';
  const recovery = document.createElement('div');
  recovery.hidden = true;
  let prepared = null;
  let revision = 0;
  const reset = () => {
    revision++;
    prepared = null;
    recovery.hidden = true;
    recovery.replaceChildren();
    button.textContent = 'Share image';
    button.disabled = false;
    status.textContent = '';
  };
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
    const startedAt = revision;
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
        if (startedAt !== revision) return;
        status.textContent = 'Image handed to your share app. Choose X if available; nothing was posted automatically.';
      } catch (error) {
        if (startedAt !== revision) return;
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
      if (startedAt !== revision) return;
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
      if (startedAt !== revision) return;
      status.textContent = 'Could not prepare the image. Try downloading it to attach manually.';
    } finally { if (startedAt === revision) button.disabled = false; }
  });
  bar.appendChild(button);
  bar.appendChild(recovery);
  return reset;
}

export function initializeShareButtons() {
  document.querySelectorAll('.meme-container, .meme-detail, .meme-card').forEach(container => {
    // Cards without an explicit exact link must not share a misleading homepage.
    if (!container.querySelector('#meme-display') && !container.dataset.sharePath) return;
    if (container.querySelector('.share-bar')) return;
    const panel = document.createElement('details');
    panel.className = 'meme-share-panel';
    if (container.querySelector('#meme-display')) panel.id = 'meme-share-panel';
    const summary = document.createElement('summary');
    summary.textContent = 'Image and link sharing options';
    panel.appendChild(summary);
    const bar = document.createElement('div');
    bar.className = 'share-bar';
    const status = document.createElement('p');
    status.setAttribute('role', 'status');
    status.setAttribute('aria-live', 'polite');
    const guidance = document.createElement('p');
    guidance.className = 'share-guidance';
    guidance.textContent = 'Send the image: use Share image on supported devices, or copy/download it and attach it in X. Link options below do not attach an image.';
    bar.appendChild(guidance);
    const resetImageShare = addImageShare(container, bar, status);
    const display = container.querySelector('#meme-display');
    if (display && typeof MutationObserver !== 'undefined') {
      let identity = `${exactShareData(container)?.url || ''}|${currentShareImage(container) || ''}`;
      const observer = new MutationObserver(() => {
        const next = `${exactShareData(container)?.url || ''}|${currentShareImage(container) || ''}`;
        if (next === identity) return;
        identity = next;
        resetImageShare();
      });
      observer.observe(display, { childList: true, subtree: true, attributes: true, attributeFilter: ['src', 'class', 'data-meme-url'] });
    }
    for (const [action, label] of [['copy-image', 'Copy image for X'], ['download-image', 'Download image'], ['whatsapp', 'WhatsApp link'], ['twitter', 'Tweet link'], ['copy', 'Copy exact link']]) {
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
        if (action === 'download-image') {
          const media = currentShareImage(container);
          if (!media) { status.textContent = 'No shareable image is displayed. Use the viewer Download control for video.'; return; }
          const url = new URL(media);
          const link = document.createElement('a');
          link.href = url.origin === window.location.origin ? url.href : `/download?${new URLSearchParams({ url: media })}`;
          link.download = 'meme-explorer';
          link.rel = 'noopener';
          document.body.appendChild(link);
          link.click();
          link.remove();
          status.textContent = 'Image download requested. Attach the downloaded file in X; it is not posted automatically.';
        } else if (action === 'copy-image') {
          const media = currentShareImage(container);
          if (!media) { status.textContent = 'No shareable image is displayed. Videos cannot be copied as images.'; return; }
          button.disabled = true;
          try {
            await copyImageFile(media);
            if (currentShareImage(container) !== media || exactShareData(container)?.url !== data.url) return;
            status.textContent = 'Selected image copied. Paste into X with Ctrl+V or Cmd+V. Animated images are copied as a still frame.';
          } catch (_) {
            if (currentShareImage(container) !== media || exactShareData(container)?.url !== data.url) return;
            status.textContent = 'Image copying is unavailable here. Choose Download image, then attach the file in X.';
          } finally { button.disabled = false; }
        } else if (action === 'twitter') {
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
    const close = document.createElement('button');
    close.type = 'button';
    close.textContent = 'Close sharing options';
    const dismiss = () => {
      panel.open = false;
      (document.getElementById?.('share-btn') || summary).focus?.();
    };
    close.addEventListener('click', dismiss);
    panel.addEventListener('keydown', event => {
      if (event.key === 'Escape') { event.preventDefault(); dismiss(); }
    });
    bar.appendChild(close);
    panel.appendChild(bar);
    container.appendChild(panel);
  });
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeShareButtons);
else initializeShareButtons();
