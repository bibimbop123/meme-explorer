// Error Boundary for JavaScript Modules
// Prevents one module's errors from crashing the entire app

class ErrorBoundary {
  constructor(moduleName) {
    this.moduleName = moduleName;
    this.errors = [];
  }

  wrap(fn) {
    return (...args) => {
      try {
        return fn(...args);
      } catch (error) {
        this.handleError(error);
        return null;
      }
    };
  }

  async wrapAsync(fn) {
    return async (...args) => {
      try {
        return await fn(...args);
      } catch (error) {
        this.handleError(error);
        return null;
      }
    };
  }

  handleError(error) {
    console.error(`[${this.moduleName}] Error:`, error);
    
    // Log to server if AppLogger is available
    if (window.AppLogger) {
      window.AppLogger.error({
        module: this.moduleName,
        error: error.message,
        stack: error.stack
      });
    }
    
    // Store for debugging
    this.errors.push({
      timestamp: new Date(),
      error: error.message,
      stack: error.stack
    });
    
    // Show user-friendly message
    this.showUserMessage();
  }

  showUserMessage() {
    // Only show once per session
    if (sessionStorage.getItem(`error_shown_${this.moduleName}`)) {
      return;
    }
    
    const message = `We encountered an issue with ${this.moduleName}. Please refresh the page.`;
    
    if (window.showToast) {
      window.showToast(message, 'error');
    } else {
      console.warn(message);
    }
    
    sessionStorage.setItem(`error_shown_${this.moduleName}`, 'true');
  }

  getErrors() {
    return this.errors;
  }
}

// Export for use in modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ErrorBoundary;
} else {
  window.ErrorBoundary = ErrorBoundary;
}
