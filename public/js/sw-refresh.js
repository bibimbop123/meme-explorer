/* Service Worker Refresh - Force reload to pick up new CSP
 * Add this to your layout or run in console to force SW update
 */

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function(registrations) {
    for(let registration of registrations) {
      registration.unregister().then(function(success) {
        console.log('[SW] Unregistered old service worker:', success);
      });
    }
  }).then(function() {
    console.log('[SW] Reloading to register fresh service worker...');
    window.location.reload(true);
  });
}
