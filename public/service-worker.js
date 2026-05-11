// Service Worker for Meme Explorer Push Notifications
// Created: May 11, 2026
// Part of: Priority 1 Entertainment Enhancements

self.addEventListener('push', event => {
  console.log('[Service Worker] Push notification received');
  
  const data = event.data ? event.data.json() : {};
  
  const options = {
    body: data.body || 'New memes are waiting for you! 🎉',
    icon: '/images/icon-192.png',
    badge: '/images/badge-72.png',
    vibrate: [200, 100, 200],
    tag: 'meme-notification',
    requireInteraction: false,
    data: {
      url: data.url || '/random',
      timestamp: Date.now()
    },
    actions: [
      { action: 'view', title: 'View Memes 🎉', icon: '/images/icon-192.png' },
      { action: 'close', title: 'Later' }
    ]
  };
  
  event.waitUntil(
    self.registration.showNotification(data.title || '🔥 Meme Explorer', options)
  );
});

self.addEventListener('notificationclick', event => {
  console.log('[Service Worker] Notification clicked:', event.action);
  event.notification.close();
  
  if (event.action === 'view' || !event.action) {
    const urlToOpen = event.notification.data.url || '/random';
    
    event.waitUntil(
      clients.matchAll({ type: 'window', includeUncontrolled: true })
        .then(windowClients => {
          // Check if there's already a window open
          for (let client of windowClients) {
            if (client.url.includes(self.location.origin) && 'focus' in client) {
              return client.focus().then(() => client.navigate(urlToOpen));
            }
          }
          // No window open, open new one
          if (clients.openWindow) {
            return clients.openWindow(urlToOpen);
          }
        })
    );
  }
});

self.addEventListener('install', event => {
  console.log('[Service Worker] Installing...');
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  console.log('[Service Worker] Activating...');
  event.waitUntil(clients.claim());
});

// Handle notification close
self.addEventListener('notificationclose', event => {
  console.log('[Service Worker] Notification closed:', event.notification.tag);
});

console.log('[Service Worker] Loaded and ready');
