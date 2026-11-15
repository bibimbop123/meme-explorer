// Trending Page - ES module (bundled via public/js/main.js)
// Fetches memes from /api/v1/trending and /api/v1/daily-digest and renders
// cards; the click-to-open lightbox is class-based (see /css/trending.css),
// focus-trapped, scroll-locked and restores focus on close.

export class TrendingPage {
  constructor() {
    this.container = document.getElementById('trendingContainer');
    this.sortDropdown = document.getElementById('sortDropdown');
    this.tabButtons = document.querySelectorAll('.tab-button');
    this.scrollObserver = document.getElementById('scrollObserver');

    this.currentPage = 0;
    this.currentTimeWindow = '24h';
    this.currentSort = 'trending';
    this.isLoading = false;

    // Initialize Ad Manager if available (feed-position placeholders only
    // - real ad revenue comes from Monetag's site-wide tag, loaded
    // independently via public/js/cookie-consent.js)
    this.adManager = window.AdManager ? new AdManager({
      frequency: parseInt(window.AD_FREQUENCY || '12', 10)
    }) : null;

    this.memeCount = 0; // Track total memes rendered for ad placement
    this.renderedMemes = [];
    this.previousFocus = null;
    this.previousBodyOverflow = null;
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
    const isDailyPack = this.currentTimeWindow === 'daily_top_10';
    if (isDailyPack && append) {
      this.isLoading = false;
      return;
    }
    const cursor = append && this.nextCursor ? this.nextCursor : '';
    const url = isDailyPack
      ? '/api/v1/daily-digest?limit=10'
      : `/api/v1/trending?time_window=${this.currentTimeWindow}&sort_by=${this.currentSort}&cursor=${cursor}&limit=20`;

    fetch(url)
      .then(response => response.json())
      .then(data => {
        if (data.data && Array.isArray(data.data)) {
          const memes = data.data;
          if (!append) {
            this.container.innerHTML = '';
            this.memeCount = 0; // Reset counter when loading fresh
            this.renderedMemes = [];
            if (isDailyPack) {
              const banner = document.createElement('div');
              banner.className = 'trending-daily-banner';
              banner.textContent = `🎯 Today's Top ${memes.length} Daily Pack — Strictly 1 top meme per humor community`;
              this.container.appendChild(banner);
            }
          }
          memes.forEach(meme => this.renderMemeCard(meme));
          if (isDailyPack && memes.length > 0) {
            const doneCard = document.createElement('div');
            doneCard.className = 'trending-daily-done';
            doneCard.innerHTML = '<strong>🎉 You’ve reached the end of Today’s Top 10!</strong> <a href="/random">🔥 Continue in Random Feed →</a>';
            this.container.appendChild(doneCard);
          }

          // Setup lazy loading for ads after rendering
          if (this.adManager) {
            setTimeout(() => this.adManager.setupLazyLoading(), 200);
          }

          // Store next cursor for infinite scroll
          this.nextCursor = isDailyPack ? null : (data.pagination?.next_cursor || null);
          this.hasMore = isDailyPack ? false : (data.pagination?.has_more || false);
        }
        this.isLoading = false;
      })
      .catch(error => {
        console.error('Error loading trending memes:', error);
        if (!append) {
          this.container.innerHTML = '<p class="trending-error">Failed to load memes. Please refresh.</p>';
        }
        this.isLoading = false;
      });
  }

  escapeHtml(value) {
    return String(value ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  safeMediaUrl(rawUrl, fallbackSub) {
    const str = String(rawUrl || '').trim();
    if (/^https?:\/\//i.test(str) || str.startsWith('/images/')) {
      return this.escapeHtml(str);
    }
    const cleanSub = String(fallbackSub || 'dank').replace(/[^a-z0-9_]/gi, '') || 'dank';
    return `/images/${cleanSub}1.jpeg`;
  }

  renderMemeCard(meme) {
    // Check if we should insert an ad before this meme
    if (this.adManager && this.adManager.shouldShowAdAtPosition(this.memeCount)) {
      const ad = this.adManager.createAdElement(this.adManager.adCount, 'square');
      this.container.appendChild(ad);
      this.adManager.adCount++;
    }

    // Use API image URL with smart fallback
    const imageUrl = this.safeMediaUrl(meme.image_url || meme.url, meme.subreddit);
    const safeTitle = this.escapeHtml(meme.title || 'Untitled');
    const safeAlt = this.escapeHtml(meme.title || 'Meme');
    const safeSub = this.escapeHtml(meme.subreddit || 'local');
    const safeLikes = parseInt(meme.likes, 10) || 0;
    const safeViews = parseInt(meme.views, 10) || 0;

    this.renderedMemes = this.renderedMemes || [];
    const cardIndex = this.renderedMemes.length;
    this.renderedMemes.push(meme);
    const isDailyPack = this.currentTimeWindow === 'daily_top_10';
    const rankBadge = isDailyPack ? `<span class="trending-rank-badge">#${cardIndex + 1}</span>` : '';

    const card = document.createElement('div');
    card.className = 'meme-card';
    card.style.cursor = 'pointer';
    card.innerHTML = `
      <img
        class="meme-image"
        src="${imageUrl}"
        alt="${safeAlt}"
        loading="lazy"
        onerror="this.src='/images/meme-placeholder.svg'"
      />
      <div class="meme-info">
        <h3 class="meme-title">${safeTitle}</h3>
        <div class="meme-meta">
          ${rankBadge}
          <span>/r/${safeSub}</span>
          <span>❤️ ${safeLikes}</span>
          <span>👁️ ${safeViews}</span>
        </div>
      </div>
    `;

    // Make card clickable - shows meme in modal (no redirect)
    card.addEventListener('click', () => {
      this.showMemeModal(meme, cardIndex);
    });

    this.container.appendChild(card);
    this.memeCount++; // Increment meme counter
  }

  showMemeModal(meme, index = -1) {
    this.renderedMemes = this.renderedMemes || [];
    const resolvedIndex = index >= 0 ? index : this.renderedMemes.indexOf(meme);
    const totalLoaded = this.renderedMemes.length;
    const hasPrev = resolvedIndex > 0;
    const hasNext = resolvedIndex >= 0 && resolvedIndex < totalLoaded - 1;

    const modal = document.createElement('div');
    modal.className = 'trending-modal-overlay';
    modal.setAttribute?.('role', 'dialog');
    modal.setAttribute?.('aria-modal', 'true');
    modal.setAttribute?.('aria-label', this.escapeHtml(meme.title || 'Meme'));

    const imageUrl = this.safeMediaUrl(meme.image_url || meme.url, meme.subreddit);
    const safeTitle = this.escapeHtml(meme.title || 'Meme');
    const safeSub = this.escapeHtml(meme.subreddit || 'reddit');
    const safeLikes = parseInt(meme.likes, 10) || 0;
    const safeViews = parseInt(meme.views, 10) || 0;
    const positionLabel = resolvedIndex >= 0 && totalLoaded > 1 ? `#${resolvedIndex + 1} of ${totalLoaded} • ` : '';

    modal.innerHTML = `
      <div class="trending-modal-content">
        <img class="trending-modal-img" src="${imageUrl}"
             alt="${safeTitle}"
             onerror="this.src='/images/meme-placeholder.svg'">
        <div class="trending-modal-info">
          <h3>${safeTitle}</h3>
          <p class="trending-modal-meta">${positionLabel}/r/${safeSub} • ❤️ ${safeLikes} • 👁️ ${safeViews}</p>
          ${totalLoaded > 1 ? `
            <div class="trending-modal-nav">
              <button type="button" class="trending-modal-btn" data-modal-nav="prev" ${hasPrev ? '' : 'disabled'}>← Prev</button>
              <button type="button" class="trending-modal-btn" data-modal-nav="close">✕ Close (Esc)</button>
              <button type="button" class="trending-modal-btn" data-modal-nav="next" ${hasNext ? '' : 'disabled'}>Next →</button>
            </div>
          ` : ''}
          <p class="trending-modal-links">
            ${meme.viewer_path && /^\/meme\/[a-f0-9]{64}$/.test(meme.viewer_path) ? `<a class="trending-modal-link-viewer" href="${meme.viewer_path}">🎯 Open & Share in Viewer →</a>` : ''}
            <a class="trending-modal-link-community" href="/search?q=${encodeURIComponent(meme.subreddit || '')}">More from r/${safeSub} →</a>
            <a class="trending-modal-link-random" href="/random">Explore Random Feed →</a>
          </p>
          <p class="trending-modal-hint">Use ← / → arrow keys to browse, Esc or click backdrop to close</p>
        </div>
      </div>
    `;

    // Scroll lock + focus management while the dialog is open.
    this.previousFocus = typeof document !== 'undefined' ? document.activeElement : null;
    const body = document.body;
    this.previousBodyOverflow = body?.style ? body.style.overflow : null;
    if (body?.style) body.style.overflow = 'hidden';
    body?.classList?.add?.('modal-open');

    const closeModal = () => {
      document.removeEventListener?.('keydown', onKeyDown);
      if (body?.style) body.style.overflow = this.previousBodyOverflow || '';
      body?.classList?.remove?.('modal-open');
      if (modal.parentNode) {
        modal.parentNode.removeChild(modal);
      } else {
        body?.removeChild?.(modal);
      }
      this.previousFocus?.focus?.({ preventScroll: true });
    };

    const onKeyDown = (event) => {
      if (event.key === 'Escape') {
        event.preventDefault?.();
        closeModal();
        return;
      }
      if (event.key === 'ArrowLeft' && hasPrev) {
        event.preventDefault?.();
        closeModal();
        this.showMemeModal(this.renderedMemes[resolvedIndex - 1], resolvedIndex - 1);
        return;
      }
      if (event.key === 'ArrowRight' && hasNext) {
        event.preventDefault?.();
        closeModal();
        this.showMemeModal(this.renderedMemes[resolvedIndex + 1], resolvedIndex + 1);
        return;
      }
      if (event.key === 'Tab') {
        const controls = Array.from(
          modal.querySelectorAll?.('button, a[href]') || []
        ).filter(control => !control.disabled);
        if (!controls.length) return;
        const first = controls[0];
        const last = controls[controls.length - 1];
        if (!controls.includes(document.activeElement)) {
          event.preventDefault?.();
          first.focus?.();
        } else if (event.shiftKey && document.activeElement === first) {
          event.preventDefault?.();
          last.focus?.();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault?.();
          first.focus?.();
        }
      }
    };

    document.addEventListener?.('keydown', onKeyDown);

    modal.addEventListener('click', (event) => {
      const navBtn = event?.target?.closest?.('[data-modal-nav]');
      if (navBtn) {
        event.stopPropagation?.();
        const action = navBtn.getAttribute('data-modal-nav');
        if (action === 'prev' && hasPrev) {
          closeModal();
          this.showMemeModal(this.renderedMemes[resolvedIndex - 1], resolvedIndex - 1);
        } else if (action === 'next' && hasNext) {
          closeModal();
          this.showMemeModal(this.renderedMemes[resolvedIndex + 1], resolvedIndex + 1);
        } else if (action === 'close') {
          closeModal();
        }
        return;
      }
      if (event?.target?.closest?.('a')) {
        return;
      }
      closeModal();
    });

    document.body.appendChild(modal);
    modal.querySelector?.('[data-modal-nav="close"]')?.focus?.({ preventScroll: true });
  }
}

// Boot only on the trending page in a real browser (never under Node tests).
if (typeof window !== 'undefined' && typeof document !== 'undefined') {
  const bootTrendingPage = () => {
    if (document.getElementById?.('trendingContainer')) {
      const trendingPage = new TrendingPage();
      trendingPage.initialize();
      window.trendingPage = trendingPage;
    }
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bootTrendingPage);
  } else {
    bootTrendingPage();
  }
}
