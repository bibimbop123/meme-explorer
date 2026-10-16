// Saved media failures never remove the favorite or automatically loop requests.
(() => {
  const image = document.querySelector('[data-saved-media]');
  const recovery = document.getElementById('saved-media-recovery');
  const status = document.getElementById('saved-media-status');
  const retry = document.getElementById('retry-saved-media');
  if (!image || !recovery || !status) return;

  const failed = () => {
    image.hidden = true;
    recovery.hidden = false;
    status.textContent = 'This image is unavailable. Your favorite is still saved unless you remove it.';
    if (retry) retry.disabled = false;
  };
  if (image.dataset.savedMedia === 'unavailable') {
    failed();
    return;
  }
  image.addEventListener('error', failed);
  image.addEventListener('load', () => {
    image.hidden = false;
    if (retry?.disabled) {
      recovery.hidden = false;
      status.textContent = 'Image loaded.';
    } else {
      recovery.hidden = true;
    }
    if (retry) retry.disabled = false;
  });
  retry?.addEventListener('click', () => {
    if (retry.disabled) return;
    retry.disabled = true;
    status.textContent = 'Trying image again…';
    // Reassign the original validated source without fabricating cache parameters.
    image.src = image.getAttribute('src');
  });
  if (image.complete && image.naturalWidth === 0) failed();
})();