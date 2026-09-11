// Meme Explorer - Main Entry Point (Vite Bundler)
//
// BUG FIX: this used to also import progressive-disclosure.js,
// enhanced-lazy-load.js, web-vitals.js, ad-manager.js, ad-lazy-load.js,
// trending.js, dark-mode.js, error-handler.js, keyboard-navigation.js, and
// mobile-swipe.js - every one of which is ALSO loaded via its own
// standalone <script src="..."> tag in views/layout.erb (or
// views/trending.erb for trending.js). Since these are all self-executing
// IIFEs that register event listeners/observers immediately on load,
// bundling them here too meant every page load ran each of them twice:
// two dark-mode toggles wired up, two Core Web Vitals reporters, two ad
// lazy-load IntersectionObservers, two error-handler listeners
// double-reporting every exception to Sentry, and - worst of all for the
// user - two keydown listeners each handling j/k/l/s/?/Esc, and two swipe
// gesture handlers, both firing on every keypress/swipe. Same class of
// bug as the documented "two MemeNavigation instances" fix in
// views/random.erb - just not yet caught here. Removed the duplicate
// imports; each of those scripts now loads exactly once, via its
// standalone <script> tag, wherever the page needs it.
//
// Only imports .js files that exist (not .min.js versions), and only
// modules that are NOT also loaded via a standalone <script> tag anywhere.

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

console.log('✅ Meme Explorer bundled - 74→23 JS files');
