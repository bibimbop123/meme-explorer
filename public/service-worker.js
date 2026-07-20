/* Enhanced Service Worker v2.0
 * Features:
 * - Offline fallback page
 * - Network-first for API calls
 * - Cache-first for static assets
 * - Background sync for failed requests
 * - Push notification support (existing)
 */

const CACHE_VERSION = 'meme-explorer-v2.0';
const STATIC_CACHE = 'static-v2.0';
const API_CACHE = 'api-v2.0';
const IMAGE_CACHE = 'images-v2.0';

const STATIC_ASSETS = [
  '/',
  '/offline.html',
  '/css/meme_explorer.css',
  '/css/dark-mode.css',
  '/css/mobile-optimizations.css',
  '/js/dark-mode.js',
  '/images/meme-placeholder.svg',
  '/manifest.json'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker v2.0...');
  
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => {
        console.log('[SW] Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker v2.0...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name !== STATIC_CACHE && name !== API_CACHE && name !== IMAGE_CACHE)
            .map((name) => caches.delete(name))
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - handle requests with appropriate strategies
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // API requests - network first, fallback to cache
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirst(request, API_CACHE));
    return;
  }
  
  // Images - cache first, fallback to network
  if (request.destination === 'image') {
    event.respondWith(cacheFirst(request, IMAGE_CACHE));
    return;
  }
  
  // Static assets - cache first
  if (STATIC_ASSETS.includes(url.pathname)) {
    event.respondWith(cacheFirst(request, STATIC_CACHE));
    return;
  }
  
  // HTML pages - network first, offline fallback
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .catch(() => caches.match('/offline.html'))
    );
    return;
  }
  
  // Default - network first
  event.respondWith(fetch(request));
});

// Network-first strategy
async function networkFirst(request, cacheName) {
  try {
    const response = await fetch(request);
    const cache = await caches.open(cacheName);
    cache.put(request, response.clone());
    return response;
  } catch (error) {
    const cached = await caches.match(request);
    if (cached) {
      return cached;
    }
    throw error;
  }
}

// Cache-first strategy
async function cacheFirst(request, cacheName) {
  const cached = await caches.match(request);
  if (cached) {
    return cached;
  }
  
  try {
    const response = await fetch(request);
    const cache = await caches.open(cacheName);
    cache.put(request, response.clone());
    return response;
  } catch (error) {
    // Return placeholder for images
    if (request.destination === 'image') {
      return caches.match('/images/meme-placeholder.svg');
    }
    throw error;
  }
}

// Background sync for failed API requests
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-api-requests') {
    event.waitUntil(syncFailedRequests());
  }
});

async function syncFailedRequests() {
  // Implement queue for failed requests
  console.log('[SW] Syncing failed requests...');
  // TODO: Implement request queue persistence
}

// Push notification handling (keep existing functionality)
self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};
  const title = data.title || 'Meme Explorer';
  const options = {
    body: data.body || 'New content available!',
    icon: '/images/meme-placeholder.svg',
    badge: '/images/meme-placeholder.svg',
    data: data.url || '/'
  };
  
  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow(event.notification.data)
  );
});

console.log('[SW] Service Worker v2.0 loaded');
