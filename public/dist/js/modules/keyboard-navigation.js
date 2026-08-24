/**
 * Keyboard Navigation Module
 * Provides intuitive keyboard shortcuts for meme browsing
 * 
 * Shortcuts:
 * - j: Next meme
 * - k: Previous meme
 * - l: Like current meme
 * - s: Save/bookmark current meme
 * - Shift+S: Share current meme
 * - ?: Show shortcuts help modal
 * - Esc: Close modals/overlays
 */

(function() {
  'use strict';

  const KeyboardNavigation = {
    // Configuration
    config: {
      enabled: true,
      shortcuts: {
        'j': 'nextMeme',
        'k': 'previousMeme',
        'l': 'likeMeme',
        's': 'saveMeme',
        'S': 'shareMeme',  // Shift+S
        '?': 'showHelp',
        'Escape': 'closeModals'
      }
    },

    // State
    state: {
      helpModalVisible: false,
      inputFocused: false
    },

    /**
     * Initialize keyboard navigation
     */
    init() {
      console.log('🎹 Initializing keyboard navigation...');
      
      this.setupEventListeners();
      this.createHelpModal();
      this.detectInputFocus();
      
      console.log('✅ Keyboard navigation ready');
    },

    /**
     * Setup keyboard event listeners
     */
    setupEventListeners() {
      document.addEventListener('keydown', (e) => {
        // Don't capture keys when typing in inputs
        if (this.state.inputFocused) return;
        
        // Don't capture keys when modals are open (except Escape)
        if (document.body.classList.contains('modal-open') && e.key !== 'Escape') {
          return;
        }

        const handler = this.getHandlerForKey(e);
        if (handler) {
          e.preventDefault();
          this[handler]();
        }
      });
    },

    /**
     * Get handler function name for a key event
     */
    getHandlerForKey(event) {
      const key = event.shiftKey && event.key.toLowerCase() !== event.key 
        ? event.key  // Shift+S
        : event.key.toLowerCase();
      
      return this.config.shortcuts[key] || this.config.shortcuts[event.key];
    },

    /**
     * Detect when user is typing in an input field
     */
    detectInputFocus() {
      document.addEventListener('focusin', (e) => {
        if (e.target.matches('input, textarea, select, [contenteditable="true"]')) {
          this.state.inputFocused = true;
        }
      });

      document.addEventListener('focusout', (e) => {
        if (e.target.matches('input, textarea, select, [contenteditable="true"]')) {
          this.state.inputFocused = false;
        }
      });
    },

    /**
     * Navigate to next meme
     */
    nextMeme() {
      console.log('⏭️ Next meme (j)');
      const nextButton = document.querySelector('[data-action="next-meme"], .next-button, button[onclick*="next"]');
      if (nextButton) {
        nextButton.click();
        this.showFeedback('Next meme');
      } else {
        // Fallback: try to find navigation function in global scope
        if (typeof window.nextMeme === 'function') {
          window.nextMeme();
        } else if (typeof window.loadNextMeme === 'function') {
          window.loadNextMeme();
        }
      }
    },

    /**
     * Navigate to previous meme
     */
    previousMeme() {
      console.log('⏮️ Previous meme (k)');
      const prevButton = document.querySelector('[data-action="prev-meme"], .prev-button, button[onclick*="prev"]');
      if (prevButton) {
        prevButton.click();
        this.showFeedback('Previous meme');
      } else {
        // Fallback
        if (typeof window.previousMeme === 'function') {
          window.previousMeme();
        } else if (typeof window.loadPreviousMeme === 'function') {
          window.loadPreviousMeme();
        }
      }
    },

    /**
     * Like current meme
     */
    likeMeme() {
      console.log('❤️ Like meme (l)');
      const likeButton = document.querySelector('[data-action="like"], .like-button, button[onclick*="like"]');
      if (likeButton) {
        likeButton.click();
        this.showFeedback('Liked!');
      } else {
        // Fallback
        if (typeof window.likeMeme === 'function') {
          window.likeMeme();
        }
      }
    },

    /**
     * Save/bookmark current meme
     */
    saveMeme() {
      console.log('💾 Save meme (s)');
      const saveButton = document.querySelector('[data-action="save"], .save-button, button[onclick*="save"]');
      if (saveButton) {
        saveButton.click();
        this.showFeedback('Saved!');
      } else {
        // Fallback
        if (typeof window.saveMeme === 'function') {
          window.saveMeme();
        }
      }
    },

    /**
     * Share current meme
     */
    shareMeme() {
      console.log('📤 Share meme (Shift+S)');
      const shareButton = document.querySelector('[data-action="share"], .share-button, button[onclick*="share"]');
      if (shareButton) {
        shareButton.click();
        this.showFeedback('Share opened');
      } else {
        // Fallback
        if (typeof window.shareMeme === 'function') {
          window.shareMeme();
        }
      }
    },

    /**
     * Show keyboard shortcuts help
     */
    showHelp() {
      console.log('❓ Show help (?)');
      this.state.helpModalVisible = true;
      const modal = document.getElementById('keyboard-shortcuts-modal');
      if (modal) {
        modal.style.display = 'flex';
        modal.setAttribute('aria-hidden', 'false');
        document.body.classList.add('modal-open');
      }
    },

    /**
     * Close any open modals
     */
    closeModals() {
      console.log('❌ Close modals (Esc)');
      const modal = document.getElementById('keyboard-shortcuts-modal');
      if (modal) {
        modal.style.display = 'none';
        modal.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('modal-open');
        this.state.helpModalVisible = false;
      }
      
      // Close any other modals
      const openModals = document.querySelectorAll('.modal:not([aria-hidden="true"])');
      openModals.forEach(m => {
        m.style.display = 'none';
        m.setAttribute('aria-hidden', 'true');
      });
    },

    /**
     * Show visual feedback for keyboard action
     */
    showFeedback(message) {
      // Remove existing feedback
      const existing = document.querySelector('.keyboard-feedback');
      if (existing) existing.remove();

      // Create feedback element
      const feedback = document.createElement('div');
      feedback.className = 'keyboard-feedback';
      feedback.textContent = message;
      feedback.style.cssText = `
        position: fixed;
        bottom: 20px;
        right: 20px;
        background: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 12px 20px;
        border-radius: 8px;
        font-size: 14px;
        font-weight: 500;
        z-index: 10000;
        animation: feedbackSlide 0.3s ease-out;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      `;

      document.body.appendChild(feedback);

      // Remove after 1.5 seconds
      setTimeout(() => {
        feedback.style.animation = 'feedbackSlideOut 0.3s ease-out';
        setTimeout(() => feedback.remove(), 300);
      }, 1500);
    },

    /**
     * Create help modal HTML
     */
    createHelpModal() {
      // Check if modal already exists
      if (document.getElementById('keyboard-shortcuts-modal')) return;

      const modal = document.createElement('div');
      modal.id = 'keyboard-shortcuts-modal';
      modal.className = 'modal';
      modal.setAttribute('role', 'dialog');
      modal.setAttribute('aria-labelledby', 'shortcuts-title');
      modal.setAttribute('aria-hidden', 'true');
      modal.style.display = 'none';

      modal.innerHTML = `
        <div class="modal-overlay" onclick="document.getElementById('keyboard-shortcuts-modal').style.display='none'"></div>
        <div class="modal-content" style="max-width: 500px;">
          <div class="modal-header">
            <h2 id="shortcuts-title">⌨️ Keyboard Shortcuts</h2>
            <button class="modal-close" onclick="document.getElementById('keyboard-shortcuts-modal').style.display='none'" aria-label="Close">×</button>
          </div>
          <div class="modal-body">
            <div class="shortcuts-grid">
              <div class="shortcut-item">
                <kbd>j</kbd>
                <span>Next meme</span>
              </div>
              <div class="shortcut-item">
                <kbd>k</kbd>
                <span>Previous meme</span>
              </div>
              <div class="shortcut-item">
                <kbd>l</kbd>
                <span>Like current meme</span>
              </div>
              <div class="shortcut-item">
                <kbd>s</kbd>
                <span>Save/bookmark</span>
              </div>
              <div class="shortcut-item">
                <kbd>Shift</kbd> + <kbd>S</kbd>
                <span>Share meme</span>
              </div>
              <div class="shortcut-item">
                <kbd>?</kbd>
                <span>Show this help</span>
              </div>
              <div class="shortcut-item">
                <kbd>Esc</kbd>
                <span>Close modals</span>
              </div>
            </div>
            <div class="shortcuts-tip">
              💡 <strong>Pro tip:</strong> Keyboard shortcuts won't work while typing in text fields.
            </div>
          </div>
        </div>
      `;

      // Add styles
      const style = document.createElement('style');
      style.textContent = `
        .keyboard-shortcuts-modal .modal-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0, 0, 0, 0.5);
          z-index: 9998;
        }

        .keyboard-shortcuts-modal .modal-content {
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          background: white;
          border-radius: 12px;
          padding: 0;
          z-index: 9999;
          max-height: 90vh;
          overflow-y: auto;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        }

        .keyboard-shortcuts-modal .modal-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 20px 24px;
          border-bottom: 1px solid #e5e7eb;
        }

        .keyboard-shortcuts-modal .modal-header h2 {
          margin: 0;
          font-size: 20px;
          font-weight: 600;
        }

        .keyboard-shortcuts-modal .modal-close {
          background: none;
          border: none;
          font-size: 28px;
          cursor: pointer;
          color: #6b7280;
          line-height: 1;
          padding: 0;
          width: 32px;
          height: 32px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 6px;
          transition: all 0.2s;
        }

        .keyboard-shortcuts-modal .modal-close:hover {
          background: #f3f4f6;
          color: #111827;
        }

        .keyboard-shortcuts-modal .modal-body {
          padding: 24px;
        }

        .keyboard-shortcuts-modal .shortcuts-grid {
          display: grid;
          gap: 16px;
        }

        .keyboard-shortcuts-modal .shortcut-item {
          display: flex;
          align-items: center;
          gap: 16px;
        }

        .keyboard-shortcuts-modal .shortcut-item kbd {
          background: #f3f4f6;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          padding: 6px 12px;
          font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
          font-size: 13px;
          font-weight: 600;
          color: #374151;
          box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
          min-width: 40px;
          text-align: center;
        }

        .keyboard-shortcuts-modal .shortcut-item span {
          flex: 1;
          color: #6b7280;
          font-size: 14px;
        }

        .keyboard-shortcuts-modal .shortcuts-tip {
          margin-top: 20px;
          padding: 12px 16px;
          background: #eff6ff;
          border-radius: 8px;
          font-size: 13px;
          color: #1e40af;
          border-left: 3px solid #3b82f6;
        }

        @keyframes feedbackSlide {
          from {
            transform: translateY(20px);
            opacity: 0;
          }
          to {
            transform: translateY(0);
            opacity: 1;
          }
        }

        @keyframes feedbackSlideOut {
          from {
            transform: translateY(0);
            opacity: 1;
          }
          to {
            transform: translateY(20px);
            opacity: 0;
          }
        }

        @media (max-width: 640px) {
          .keyboard-shortcuts-modal .modal-content {
            width: 90%;
            max-width: none;
          }

          .keyboard-shortcuts-modal .shortcut-item {
            gap: 12px;
          }

          .keyboard-shortcuts-modal .shortcut-item kbd {
            min-width: 36px;
            padding: 4px 8px;
            font-size: 12px;
          }
        }
      `;

      document.head.appendChild(style);
      document.body.appendChild(modal);

      // Close on overlay click
      modal.querySelector('.modal-overlay').addEventListener('click', () => {
        this.closeModals();
      });

      // Close button
      modal.querySelectorAll('.modal-close').forEach(btn => {
        btn.addEventListener('click', () => {
          this.closeModals();
        });
      });
    }
  };

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => KeyboardNavigation.init());
  } else {
    KeyboardNavigation.init();
  }

  // Expose to window for debugging
  window.KeyboardNavigation = KeyboardNavigation;

})();
