/* Service Worker Refresh - Force reload ONCE to pick up new CSP.
 *
 * BUG FIX: this used to unconditionally call window.location.reload(true)
 * on every single page load, with no guard to stop once the old service
 * worker was already gone. Since navigator.serviceWorker.getRegistrations()
 * still resolves (with an empty array) even when there's nothing left to
 * unregister, the .then() chain ran every time, reloading the page over and
 * over forever - an infinite auto-reload loop. On /random, each of those
 * automatic reloads serves a brand new randomly-selected meme, which looked
 * exactly like memes "carouselling" by themselves with zero user
 * interaction (no Space bar press required to trigger it).
 *
 * Fixed: only reload if there was actually at least one registration to
 * unregister, and use a sessionStorage flag as a hard stop so this can
 * never fire more than once per browser tab even if something else about
 * the registration detection is ever wrong again.
 */

if ('serviceWorker' in navigator && !sessionStorage.getItem('sw-refresh-done')) {
  navigator.serviceWorker.getRegistrations().then(function(registrations) {
    if (registrations.length === 0) {
      // Nothing to unregister - don't reload, just mark as done.
      sessionStorage.setItem('sw-refresh-done', '1');
      return;
    }

    Promise.all(
      registrations.map(function(registration) {
        return registration.unregister().then(function(success) {
          console.log('[SW] Unregistered old service worker:', success);
        });
      })
    ).then(function() {
      sessionStorage.setItem('sw-refresh-done', '1');
      console.log('[SW] Reloading once to register fresh service worker...');
      window.location.reload();
    });
  });
}
