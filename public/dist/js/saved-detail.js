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
      removed = !removed;
      button.textContent = removed ? 'Undo removal' : 'Remove';
      status.textContent = removed ? 'Favorite removed. Undo is available until you leave this page.' : 'Favorite restored.';
    } catch (_) {
      status.textContent = removed ? 'Could not restore this favorite. Please try again.' : 'Could not remove this favorite. Please try again.';
    } finally {
      button.disabled = false;
    }
  });
})();