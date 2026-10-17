// Push Notification Registration System
//
// Extracted from views/layout.erb (previously ~140 lines of inline <script>
// in the <head>, mixed with CSS keyframes and an ERB-interpolated VAPID key).
// A layout's job is to lay things out - it shouldn't also be running a
// push-subscription state machine inline. This file is now a normal static,
// cacheable asset like every other /js/*.js file, following the same
// "inline config + external script" pattern already used for ad-manager.js
// just above this include in layout.erb.
//
// Reads its configuration from window.PUSH_NOTIFICATIONS_CONFIG, which
// layout.erb sets in a small inline script before loading this file:
//   { enabled: <logged_in?>, vapidPublicKey: <ENV VAPID_PUBLIC_KEY> }
(function () {
  const config = window.PUSH_NOTIFICATIONS_CONFIG || {};
  if (!config.enabled) return;
  if (typeof config.vapidPublicKey !== 'string' || !config.vapidPublicKey.trim()) return;

  if (!('serviceWorker' in navigator) || !('PushManager' in window) || typeof Notification === 'undefined') {
    console.log('⚠️ Push notifications not supported');
    return;
  }

  const settingsAction = document.getElementById('notification-settings');
  if (settingsAction) {
    settingsAction.addEventListener('click', () => window.enablePushNotifications());
  }

  // Check if user already granted permission
  if (Notification.permission === 'granted') {
    registerPushNotifications().then(saved => {
      if (!saved) {
        if (settingsAction) settingsAction.hidden = false;
        reportStatus('Your notification subscription could not be saved. Use Enable notifications to retry.');
      }
    });
  } else if (Notification.permission !== 'denied') {
    // Permission is requested only from an explicit settings action.
    const settings = document.getElementById('notification-settings');
    if (settings) {
      settings.hidden = false;
    }
  }

  window.closePushPrompt = function () {
    const banner = document.getElementById('push-prompt-banner');
    if (banner) banner.remove();
  };

  let enabling = false;
  function reportStatus(message) {
    const status = document.getElementById('notification-status');
    if (status) {
      status.hidden = false;
      status.textContent = message;
    }
  }

  window.enablePushNotifications = async function () {
    if (enabling) return;
    enabling = true;
    const settings = document.getElementById('notification-settings');
    if (settings) settings.disabled = true;
    try {
      reportStatus('Waiting for notification permission…');
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        window.closePushPrompt();
        const saved = await registerPushNotifications();
        if (saved) {
          reportStatus('Notification subscription saved.');
          if (settings) settings.hidden = true;
          showSuccessMessage('Notification subscription saved.');
        } else {
          reportStatus('Permission granted, but the subscription could not be saved. Try Enable notifications again.');
        }
      } else if (permission === 'denied') {
        reportStatus('Notifications are blocked. You can change permission in your browser’s site settings.');
      } else {
        reportStatus('Notifications were not enabled. You can try again whenever you choose.');
      }
    } catch (error) {
      console.error('❌ Push notification error:', error);
      reportStatus('Notifications could not be enabled. Please try again.');
    } finally {
      enabling = false;
      if (settings) settings.disabled = false;
    }
  };

  async function registerPushNotifications() {
    try {
      console.log('🔔 Registering service worker...');
      const registration = await navigator.serviceWorker.register('/service-worker.js');
      console.log('✅ Service Worker registered');

      // Wait for service worker to be ready
      await navigator.serviceWorker.ready;

      const vapidKey = config.vapidPublicKey || '';
      if (!vapidKey) {
        console.log('⚠️ Push notifications not configured (missing VAPID_PUBLIC_KEY)');
        return;
      }

      // Subscribe to push notifications
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: vapidKey
      });

      console.log('🔔 Push subscription obtained, saving to server...');

      // Send subscription to server
      const response = await fetch('/api/subscribe-push', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        },
        body: JSON.stringify(subscription)
      });

      if (response.ok) {
        const data = await response.json();
        if (data.success !== true) return false;
        console.log('✅ Push subscription saved successfully');
        return true;
      } else {
        console.error('❌ Failed to save push subscription');
        return false;
      }
    } catch (error) {
      console.error('❌ Push registration error:', error);
      return false;
    }
  }

  function showSuccessMessage(message) {
    const toast = document.createElement('div');
    toast.textContent = message;
    toast.style.cssText = `
      position: fixed; top: 80px; right: 20px;
      background: #4CAF50; color: white;
      padding: 16px 24px; border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.2);
      z-index: 10001; animation: push-notif-slide-in-right 0.3s ease-out;
    `;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 4000);
  }
})();
