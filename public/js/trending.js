// Phase 1: Trending Page - Real Image Display
// Fetches memes from API and displays with real image URLs

class TrendingPage {
  constructor() {
    this.container = document.getElementById('trendingContainer');
    this.sortDropdown = document.getElementById('sortDropdown');
    this.tabButtons = document.querySelectorAll('.tab-button');
    this.scrollObserver = document.getElementById('scrollObserver');
    
    this.currentPage = 0;
    this.currentTimeWindow = '24h';
    this.currentSort = 'trending';
    this.isLoading = false;
  }

  initialize() {
    this.attachEventListeners();
    this.loadTrendingMemes();
  }

  attachEventListeners() {
    // Tab buttons
    this.tabButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        this.tabButtons.forEach(btn => btn.classList.remove('active'));
        e.target.classList.add('active');
        this.currentTimeWindow = e.target.getAttribute('data-time-window');
        this.currentPage = 0;
        this.container.innerHTML = '';
        this.loadTrendingMemes();
        localStorage.setItem('trendingTimeWindow', this.currentTimeWindow);
      });
    });

    // Sort dropdown
    this.sortDropdown.addEventListener('change', (e) => {
      this.currentSort = e.target.value;
      this.currentPage = 0;
      this.container.innerHTML = '';
      this.loadTrendingMemes();
      localStorage.setItem('trendingSort', this.currentSort);
    });

    // Infinite scroll
    const options = {
      root: null,
      rootMargin: '100px',
      threshold: 0.1
    };
    const observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting && !this.isLoading && this.hasMore !== false) {
        this.loadTrendingMemes(true);
      }
    }, options);
    observer.observe(this.scrollObserver);

    // Restore preferences
    const savedTimeWindow = localStorage.getItem('trendingTimeWindow');
    const savedSort = localStorage.getItem('trendingSort');
    if (savedTimeWindow) {
      this.currentTimeWindow = savedTimeWindow;
      document.querySelector(`[data-time-window="${savedTimeWindow}"]`)?.classList.add('active');
    }
    if (savedSort) {
      this.currentSort = savedSort;
      this.sortDropdown.value = savedSort;
    }
  }

  loadTrendingMemes(append = false) {
    if (this.isLoading) return;
    this.isLoading = true;

    // Use cursor-based pagination instead of page
    const cursor = append && this.nextCursor ? this.nextCursor : '';
    const url = `/api/v1/trending?time_window=${this.currentTimeWindow}&sort_by=${this.currentSort}&cursor=${cursor}&limit=20`;

    fetch(url)
      .then(response => response.json())
      .then(data => {
        if (data.data && Array.isArray(data.data)) {
          const memes = data.data;
          if (!append) {
            this.container.innerHTML = '';
          }
          memes.forEach(meme => this.renderMemeCard(meme));
          
          // Store next cursor for infinite scroll
          this.nextCursor = data.pagination?.next_cursor || null;
          this.hasMore = data.pagination?.has_more || false;
        }
        this.isLoading = false;
      })
      .catch(error => {
        console.error('Error loading trending memes:', error);
        if (!append) {
          this.container.innerHTML = '<p style="text-align:center;color:#666;">Failed to load memes. Please refresh.</p>';
        }
        this.isLoading = false;
      });
  }

  renderMemeCard(meme) {
    // Use API image URL with smart fallback
    const imageUrl = meme.image_url || `/images/${meme.subreddit || 'dank'}1.jpeg`;
    
    const card = document.createElement('div');
    card.className = 'meme-card';
    card.style.cursor = 'pointer';
    card.innerHTML = `
      <img 
        class="meme-image"
        src="${imageUrl}"
        alt="${meme.title || 'Meme'}"
        loading="lazy"
        onerror="this.src='/images/dank1.jpeg'"
      />
      <div class="meme-info">
        <h3 class="meme-title">${meme.title || 'Untitled'}</h3>
        <div class="meme-meta">
          <span>/r/${meme.subreddit || 'local'}</span>
          <span>❤️ ${meme.likes || 0}</span>
          <span>👁️ ${meme.views || 0}</span>
        </div>
      </div>
    `;
    
    // Make card clickable - shows meme in modal (no redirect)
    card.addEventListener('click', () => {
      this.showMemeModal(meme);
    });
    
    this.container.appendChild(card);
  }

  showMemeModal(meme) {
    // Create modal overlay
    const modal = document.createElement('div');
    modal.className = 'meme-modal';
    modal.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0,0,0,0.9);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10000;
      cursor: pointer;
    `;

    const imageUrl = meme.image_url || meme.url;
    
    modal.innerHTML = `
      <div style="max-width: 90%; max-height: 90%; position: relative;">
        <img src="${imageUrl}" 
             alt="${meme.title}" 
             style="max-width: 100%; max-height: 90vh; object-fit: contain;"
             onerror="this.src='/images/dank1.jpeg'">
        <div style="color: white; text-align: center; margin-top: 15px;">
          <h3 style="margin: 10px 0;">${meme.title || 'Meme'}</h3>
          <p style="opacity: 0.8;">/r/${meme.subreddit || 'reddit'} • ❤️ ${meme.likes || 0} • 👁️ ${meme.views || 0}</p>
          <p style="font-size: 12px; opacity: 0.6; margin-top: 10px;">Click anywhere to close</p>
        </div>
      </div>
    `;

    // Close on click
    modal.addEventListener('click', () => {
      document.body.removeChild(modal);
    });

    document.body.appendChild(modal);
  }
}
