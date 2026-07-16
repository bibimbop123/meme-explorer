/**
 * Meme Explorer - Main Application Entry Point
 * 
 * This is the primary entry point for the meme viewing experience.
 * It initializes all necessary modules and coordinates their interaction.
 * 
 * Architecture:
 * - MemeDisplay: Handles image/video rendering and carousel
 * - MemeNavigation: Keyboard shortcuts and AJAX loading
 * - MemeInteractions: Like, save, share functionality
 * - MemeTracking: Analytics and behavioral tracking (optional)
 * - MemePrefetch: Performance optimization (optional)
 */

import { MemeDisplay } from './meme-display.js';
import { MemeNavigation } from './meme-navigation.js';
import { MemeInteractions } from './meme-interactions.js';

// Optional modules - load based on configuration
let trackingEnabled = false;
let prefetchEnabled = false; // Disabled - module not yet implemented

class MemeApp {
  constructor() {
    this.display = null;
    this.navigation = null;
    this.interactions = null;
    this.tracking = null;
    this.prefetch = null;
    
    this.init();
  }
  
  async init() {
    console.log('[MemeApp] Initializing...');
    
    // Initialize core modules
    this.display = new MemeDisplay();
    this.navigation = new MemeNavigation();
    this.interactions = new MemeInteractions();
    
    // Load optional modules
    if (trackingEnabled) {
      const { MemeTracking } = await import('./meme-tracking.js');
      this.tracking = new MemeTracking();
    }
    
    if (prefetchEnabled) {
      const { MemePrefetch } = await import('./meme-prefetch.js');
      this.prefetch = new MemePrefetch();
    }
    
    console.log('[MemeApp] Initialized successfully');
    
    // Expose to window for debugging
    if (window.location.hostname === 'localhost') {
      window.memeApp = this;
    }
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => new MemeApp());
} else {
  new MemeApp();
}
