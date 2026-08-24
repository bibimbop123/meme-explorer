// Meme Explorer - Main Entry Point (Vite Bundler)
// Simplified to only include .js files that exist

// Core modules
import './modules/meme-utils.js';
import './modules/meme-display.js';
import './modules/meme-navigation.js';
import './modules/meme-interactions.js';
import './modules/meme-app.js';
import './modules/keyboard-navigation.js';
import './modules/mobile-swipe.js';

// UI enhancements
import './progressive-disclosure.js';
import './enhanced-lazy-load.js';

// Analytics & ads
import './web-vitals.js';
import './ad-manager.js';
import './ad-lazy-load.js';

// Features
import './trending.js';
import './share-system.js';
import './dark-mode.js';
import './error-boundary.js';
import './error-handler.js';
import './pwa-install.js';
import './sw-refresh.js';
import './hamburger-menu.js';
import './keyboard-shortcuts.js';
import './layout-utils.js';
import './video-player.js';
import './cookie-consent.js';

console.log('✅ Meme Explorer - 78→18 JS files = Single Bundle');
