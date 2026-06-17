// Global Error Handler - Phase 2
// Catches unhandled exceptions and sends to Sentry if configured

(function() {
  'use strict';
  
  // Track if Sentry is available
  const hasSentry = typeof Sentry !== 'undefined';
  
  // Global error handler
  window.addEventListener('error', function(event) {
    console.error('[Global Error]', {
      message: event.message,
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno,
      error: event.error
    });
    
    if (hasSentry) {
      Sentry.captureException(event.error || new Error(event.message));
    }
    
    // Don't prevent default error handling
    return false;
  });
  
  // Unhandled promise rejection handler
  window.addEventListener('unhandledrejection', function(event) {
    console.error('[Unhandled Promise Rejection]', event.reason);
    
    if (hasSentry) {
      Sentry.captureException(event.reason);
    }
  });
  
  // Log initialization
  console.log('[Error Handler] Global error handler initialized');
})();
