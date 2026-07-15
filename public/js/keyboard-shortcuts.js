/**
 * KEYBOARD SHORTCUTS - WEEK 2
 * Power user features for faster navigation
 */

(function() {
  'use strict';
  
  const KeyboardShortcuts = {
    init() {
      this.setupListeners();
      this.showHintsOnFirstVisit();
    },
    
    setupListeners() {
      document.addEventListener('keydown', (e) => {
        // Don't interfere with input fields
        if (e.target.matches('input, textarea')) return;
        
        switch(e.key) {
          case ' ':
            e.preventDefault();
            this.nextMeme();
            break;
          case 'l':
          case 'L':
            e.preventDefault();
            this.likeMeme();
            break;
          case 's':
          case 'S':
            e.preventDefault();
            this.saveMeme();
            break;
          case 'Escape':
            this.closeModals();
            break;
          case 'ArrowLeft':
            this.previousMeme();
            break;
          case 'ArrowRight':
            this.nextMeme();
            break;
          case '?':
            e.preventDefault();
            this.showShortcutsHelp();
            break;
        }
      });
    },
    
    nextMeme() {
      const nextBtn = document.querySelector('[data-action="next"], .next-meme-btn, #next-meme');
      if (nextBtn) {
        nextBtn.click();
        this.showFeedback('Next →');
      }
    },
    
    previousMeme() {
      const prevBtn = document.querySelector('[data-action="previous"], .prev-meme-btn');
      if (prevBtn) {
        prevBtn.click();
        this.showFeedback('← Previous');
      }
    },
    
    likeMeme() {
      const likeBtn = document.querySelector('[data-action="like"], .like-btn, #like-button');
      if (likeBtn) {
        likeBtn.click();
        this.showFeedback('❤️ Liked');
      }
    },
    
    saveMeme() {
      const saveBtn = document.querySelector('[data-action="save"], .save-btn, #save-button');
      if (saveBtn) {
        saveBtn.click();
        this.showFeedback('⭐ Saved');
      }
    },
    
    closeModals() {
      const closeBtn = document.querySelector('[data-dismiss="modal"], .close-modal');
      if (closeBtn) {
        closeBtn.click();
      }
      
      // Close gamification panel
      const gamificationPanel = document.querySelector('.gamification-expanded');
      if (gamificationPanel) {
        gamificationPanel.classList.remove('gamification-expanded');
        gamificationPanel.classList.add('gamification-collapsed');
      }
    },
    
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
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        background: rgba(0,0,0,0.8);
        color: white;
        padding: 12px 24px;
        border-radius: 8px;
        z-index: 10000;
        animation: fadeInOut 1s;
      `;
      
      document.body.appendChild(feedback);
      
      setTimeout(() => feedback.remove(), 1000);
    },
    
    showHintsOnFirstVisit() {
      if (localStorage.getItem('keyboard-shortcuts-seen')) return;
      
      setTimeout(() => {
        const hint = document.createElement('div');
        hint.className = 'keyboard-shortcuts-hint';
        hint.innerHTML = `
          <div style="
            position: fixed;
            bottom: 80px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(0,0,0,0.9);
            color: white;
            padding: 16px 24px;
            border-radius: 12px;
            z-index: 10000;
            max-width: 400px;
            text-align: center;
          ">
            <strong>💡 Pro Tip:</strong><br>
            Use <kbd>Space</kbd> for next meme, <kbd>L</kbd> to like, <kbd>S</kbd> to save<br>
            <small style="opacity: 0.7; display: block; margin-top: 8px;">
              Press <kbd>?</kbd> to see all shortcuts
            </small>
            <button onclick="this.parentElement.remove(); localStorage.setItem('keyboard-shortcuts-seen', '1')" 
                    style="
                      margin-top: 12px;
                      background: transparent;
                      border: 1px solid white;
                      color: white;
                      padding: 6px 16px;
                      border-radius: 6px;
                      cursor: pointer;
                    ">
              Got it!
            </button>
          </div>
        `;
        
        document.body.appendChild(hint);
        
        setTimeout(() => {
          hint.remove();
          localStorage.setItem('keyboard-shortcuts-seen', '1');
        }, 8000);
      }, 3000);
    },
    
    showShortcutsHelp() {
      const help = document.createElement('div');
      help.className = 'shortcuts-help-modal';
      help.innerHTML = `
        <div style="
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          background: white;
          padding: 32px;
          border-radius: 16px;
          box-shadow: 0 8px 32px rgba(0,0,0,0.3);
          z-index: 10001;
          max-width: 500px;
          max-height: 80vh;
          overflow-y: auto;
        ">
          <h2 style="margin: 0 0 20px 0;">⌨️ Keyboard Shortcuts</h2>
          <table style="width: 100%; border-collapse: collapse;">
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 12px 0;"><kbd>Space</kbd> or <kbd>→</kbd></td>
              <td style="padding: 12px 0; text-align: right;">Next meme</td>
            </tr>
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 12px 0;"><kbd>←</kbd></td>
              <td style="padding: 12px 0; text-align: right;">Previous meme</td>
            </tr>
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 12px 0;"><kbd>L</kbd></td>
              <td style="padding: 12px 0; text-align: right;">Like meme</td>
            </tr>
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 12px 0;"><kbd>S</kbd></td>
              <td style="padding: 12px 0; text-align: right;">Save meme</td>
            </tr>
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 12px 0;"><kbd>Esc</kbd></td>
              <td style="padding: 12px 0; text-align: right;">Close modals</td>
            </tr>
            <tr>
              <td style="padding: 12px 0;"><kbd>?</kbd></td>
              <td style="padding: 12px 0; text-align: right;">Show this help</td>
            </tr>
          </table>
          <button onclick="this.closest('.shortcuts-help-modal').remove()" 
                  style="
                    margin-top: 24px;
                    width: 100%;
                    background: #3B82F6;
                    color: white;
                    border: none;
                    padding: 12px;
                    border-radius: 8px;
                    cursor: pointer;
                    font-size: 16px;
                  ">
            Close
          </button>
        </div>
        <div onclick="this.closest('.shortcuts-help-modal').remove()" 
             style="
               position: fixed;
               top: 0;
               left: 0;
               right: 0;
               bottom: 0;
               background: rgba(0,0,0,0.5);
               z-index: 10000;
             ">
        </div>
      `;
      
      document.body.appendChild(help);
    }
  };
  
  // Add CSS for kbd styling
  const style = document.createElement('style');
  style.textContent = `
    kbd {
      background: #f1f5f9;
      border: 1px solid #cbd5e1;
      border-radius: 4px;
      padding: 2px 6px;
      font-family: monospace;
      font-size: 13px;
      box-shadow: 0 1px 2px rgba(0,0,0,0.1);
    }
    
    @keyframes fadeInOut {
      0%, 100% { opacity: 0; }
      10%, 90% { opacity: 1; }
    }
    
    @media (prefers-color-scheme: dark) {
      .shortcuts-help-modal > div:first-child {
        background: #1F2937 !important;
        color: white !important;
      }
      
      kbd {
        background: #374151;
        border-color: #4B5563;
        color: white;
      }
    }
  `;
  document.head.appendChild(style);
  
  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => KeyboardShortcuts.init());
  } else {
    KeyboardShortcuts.init();
  }
})();
