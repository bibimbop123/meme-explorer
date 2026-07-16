/**
 * Meme Navigation Module
 * Handles keyboard shortcuts and AJAX loading of memes
 */

export class MemeNavigation {
  constructor() {
    this.loading = false;
    this.init();
  }
  
  init() {
    console.log('[MemeNavigation] Initializing...');
    this.bindKeyboardShortcuts();
    this.bindNavigationButtons();
  }
  
  bindKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => this.handleKeyPress(e));
  }
  
  bindNavigationButtons() {
    // Bind to any "Next" buttons
    const nextButtons = document.querySelectorAll('[data-action="next-meme"]');
    nextButtons.forEach(btn => {
      btn.addEventListener('click', () => this.loadNextMeme());
    });
  }
  
  handleKeyPress(event) {
    // Don't trigger if user is typing in an input
    if (this.isInputFocused()) {
      return;
    }
    
    switch(event.code) {
      case 'Space':
        event.preventDefault();
        this.loadNextMeme();
        break;
      case 'ArrowRight':
        event.preventDefault();
        this.loadNextMeme();
        break;
      case 'ArrowLeft':
        event.preventDefault();
        window.history.back();
        break;
      case 'KeyT':
        event.preventDefault();
        this.toggleTitle();
        break;
    }
  }
  
  isInputFocused() {
    const activeElement = document.activeElement;
    return activeElement && (
      activeElement.tagName === 'INPUT' ||
      activeElement.tagName === 'TEXTAREA' ||
      activeElement.isContentEditable
    );
  }
  
  loadNextMeme() {
    if (this.loading) {
      console.log('[MemeNavigation] Already loading, please wait...');
      return;
    }
    
    console.log('[MemeNavigation] Loading next meme...');
    this.loading = true;
    
    // Simple approach: just reload the page
    // TODO: Implement AJAX loading
    window.location.href = '/random';
  }
  
  toggleTitle() {
    const titleElement = document.querySelector('.meme-title');
    if (titleElement) {
      titleElement.style.display = 
        titleElement.style.display === 'none' ? 'block' : 'none';
    }
  }
}
