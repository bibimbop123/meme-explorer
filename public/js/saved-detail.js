// Saved detail removal: keep the favorite visible until persistence confirms success.
(() => {
  const button = document.getElementById('remove-saved-meme');
  const status = document.getElementById('saved-removal-status');
  if (!button || !status) return;
  let removed = false;
  button.addEventListener('click', async () => {
    if (button.disabled) return;
    button.disabled = true;
    status.textContent = removed ? 'Restoring favorite…' : 'Removing favorite…';
    try {
      const url = document.querySelector("input[name='url']")?.value;
      const response = await fetch(removed ? '/api/save-meme' : '/api/unsave-meme', {
        method: 'POST', body: new URLSearchParams({ url: url || '', title: button.dataset.title || 'Unknown', subreddit: button.dataset.subreddit || 'unknown' }),
        headers: { Accept: 'application/json' }
      });
      const data = await response.json();
      if (!response.ok || data.success !== true || (removed ? data.saved : data.unsaved) !== true) throw new Error('Save change failed');
      let navigationFailed = false;
      if (removed && Number.isSafeInteger(data.saved_id) && data.saved_id > 0) {
        try {
          const location = new URL(window.location.href);
          location.pathname = `/saved/${data.saved_id}`;
          window.history.replaceState(window.history.state, '', location.pathname + location.search);
          const back = document.getElementById('saved-back-link');
          if (back) {
            const returnUrl = new URL(back.href, window.location.href);
            returnUrl.hash = `saved-card-${data.saved_id}`;
            back.href = returnUrl.href;
            button.dataset.returnPath = returnUrl.pathname + returnUrl.search + returnUrl.hash;
          }
        } catch (_) {
          navigationFailed = true;
        }
      }
      removed = !removed;
      button.textContent = removed ? 'Undo removal' : 'Remove';
      status.textContent = removed ? 'Favorite removed. Undo is available until you leave this page.' : 'Favorite restored.';
      if (navigationFailed) status.textContent = 'Favorite restored. Use Back to find it in Saved; this page address could not be updated.';
    } catch (_) {
      status.textContent = removed ? 'Could not restore this favorite. Please try again.' : 'Could not remove this favorite. Please try again.';
    } finally {
      button.disabled = false;
    }
  });
})();