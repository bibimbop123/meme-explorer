// Meme Explorer - Main Entry Point (Vite Bundler)
//
// NOTE: dark-mode.js, error-handler.js, keyboard-navigation.js,
// mobile-swipe.js, progressive-disclosure.js, web-vitals.js,
// enhanced-lazy-load.js, ad-manager.js and ad-lazy-load.js are all
// self-executing scripts loaded via their own standalone <script> tags in
// views/layout.erb. They must NOT also be imported here - bundling them too
// ran each of them twice on every page (two dark-mode toggles, two vitals
// reporters, two keydown listeners for j/k/l/s/?/Esc, etc.).
// public/js/trending.js IS imported here (it is an ES module that only
// self-boots when #trendingContainer exists); views/trending.erb no longer
// loads it via a standalone tag.

// Core modules
import './modules/meme-utils.js';
import './modules/meme-display.js';
import './modules/meme-navigation.js';
import './modules/meme-interactions.js';
import './modules/meme-app.js';

// Features
import './share-system.js';
import './error-boundary.js';
import './sw-refresh.js';
import './layout-utils.js';
import './cookie-consent.js';
import './modules/browser-visitors.js';
import './trending.js';

console.log('✅ Meme Explorer bundled - 74→23 JS files');
