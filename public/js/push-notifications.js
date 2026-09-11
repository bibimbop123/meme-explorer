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

  if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
    console.log('⚠️ Push notifications not supported');
    return;
  }

  // Check if user already granted permission
  if (Notification.permission === 'granted') {
    registerPushNotifications();
  } else if (Notification.permission !== 'denied') {
    // Show friendly prompt after user is engaged (3 seconds delay)
    setTimeout(showPushPrompt, 3000);
  }

  function showPushPrompt() {
    const banner = document.createElement('div');
    banner.id = 'push-prompt-banner';
    banner.innerHTML = `
      <div style="position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
                  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                  color: white; padding: 16px 24px; border-radius: 12px;
                  box-shadow: 0 4px 20px rgba(0,0,0,0.3); z-index: 10000;
                  max-width: 400px; text-align: center; animation: push-notif-slide-up 0.5s ease-out;">
        <p style="margin: 0 0 12px 0; font-weight: 600;">🔥 Never lose your streak!</p>
        <p style="margin: 0 0 16px 0; font-size: 0.9rem; opacity: 0.9;">
          Get reminded when your streak is about to break
        </p>
        <div style="display: flex; gap: 12px; justify-content: center;">
          <button onclick="window.enablePushNotifications()"
                  style="background: white; color: #667eea; border: none;
                         padding: 10px 20px; border-radius: 8px; font-weight: 600;
                         cursor: pointer; transition: transform 0.2s;">
            Enable Notifications ✨
          </button>
          <button onclick="window.closePushPrompt()"
                  style="background: rgba(255,255,255,0.2); color: white;
                         border: none; padding: 10px 20px; border-radius: 8px;
                         cursor: pointer; transition: transform 0.2s;">
            Maybe Later
          </button>
        </div>
      </div>
    `;
    document.body.appendChild(banner);
  }

  window.closePushPrompt = function () {
    const banner = document.getElementById('push-prompt-banner');
    if (banner) banner.remove();
  };

  window.enablePushNotifications = async function () {
    try {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        window.closePushPrompt();
        await registerPushNotifications();
        showSuccessMessage('🎉 Notifications enabled! We\'ll keep your streak safe.');
      }
    } catch (error) {
      console.error('❌ Push notification error:', error);
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
        console.log('✅ Push subscription saved successfully');
      } else {
        console.error('❌ Failed to save push subscription:', await response.text());
      }
    } catch (error) {
      console.error('❌ Push registration error:', error);
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
