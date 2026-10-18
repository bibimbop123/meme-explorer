/**
 * Meme Navigation Module - IMPROVED VERSION
 * Implements AJAX loading for smooth, fast meme browsing
 *
 * BEFORE: Full page reload (2-3 seconds, janky experience)
 * AFTER: AJAX loading (<500ms, smooth transitions)
 *
 * Expected Impact: 3x longer sessions, 40% lower bounce rate
 */

export class MemeNavigation {
  constructor() {
    this.loading = false;
    this.prefetchedMeme = null;
    this.prefetchPromise = null;
    this.interactionStates = new Map();
    this.navigationVersion = 0;
    this.historyPosition = 0;
    // Current content identity and presentation timestamp for recovery.
    this.currentMeme = null;
    this.currentMemeShownAt = null;
    // Fast, snappy "one meme at a time" transition. Must match the
    // "out" keyframe duration in /css/meme-transition.css (memeTransitionOut)
    // so content swaps exactly when the pop-out animation finishes.
    // Combined with the prefetch-ahead pattern below, this keeps Space-bar
    // navigation feeling instant rather than a slow carousel-style crossfade.
    this.transitionDuration = 140; // ms

    this.init();
  }

  init() {
    console.log('[MemeNavigation] Initializing AJAX navigation...');
    this.bindKeyboardShortcuts();
    this.bindNavigationButtons();
    this.bindGalleryControls();
    this.setupPopStateHandler();
    document.addEventListener('meme:interaction', event => this.rememberInteraction(event.detail));
    document.addEventListener('meme:gallery-position', event => this.rememberGalleryPosition(event.detail?.index));
    this.seedInitialHistory();
    this.bindVideoRecovery();
    this.bindScrollRecovery();
    this.bindRecentMemes();
    this.bindMediaRecovery();
    this.bindTitleToggle();
    const display = document.querySelector('#meme-display');
    if (display?.dataset.impressionId) {
      this.observeImpression(this.currentMeme || { impression_id: display.dataset.impressionId }, display);
    }

    // Prefetch first next meme immediately
    this.prefetchNext();
  }

  bindKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => this.handleKeyPress(e));
  }

  bindTitleToggle() {
    document.querySelector('#meme-info')?.addEventListener('click', event => {
      if (!event.target.closest?.('[data-action="toggle-meme-title"]')) return;
      event.preventDefault();
      this.toggleTitle();
    });
  }

  bindRecentMemes() {
    this.restoreRecentMemes();
    document.querySelector('#clear-recent-memes')?.addEventListener('click', () => {
      this.recentMemes = [];
      this.persistRecentMemes();
      this.renderRecentMemes();
    });
    document.querySelector('#recent-meme-list')?.addEventListener('click', event => {
      const button = event.target.closest?.('[data-recent-index]');
      if (!button) return;
      this.openRecentMeme(Number(button.dataset.recentIndex));
    });
  }

  bindMediaRecovery() {
    const display = document.querySelector('#meme-display');
    if (!display) return;
    const failed = event => {
      // Browsers may emit a nested <source> error without setting video.error
      // or dispatching an error on <video> itself.
      const media = event.target.tagName === 'SOURCE' ? event.target.parentElement : event.target;
      if (!media.matches?.('[data-recoverable-media]')) return;
      media.dataset.mediaFailed = 'true';
      const existing = media.parentElement.querySelector('[data-media-recovery]');
      if (existing) {
        existing.querySelector('p').textContent = 'Still not loading. Try again or choose another meme.';
        return;
      }
      const notice = document.createElement('div');
      notice.dataset.mediaRecovery = 'true';
      notice.setAttribute('role', 'status');
      notice.innerHTML = '<p>This media isn’t loading.</p><button type="button" data-media-action="retry">Try again</button> <button type="button" data-media-action="next">Show another meme</button>';
      media.after(notice);
    };
    display.addEventListener('error', failed, true);
    const recovered = event => {
      const media = event.target;
      if (!media.matches?.('[data-recoverable-media]')) return;
      delete media.dataset.mediaFailed;
      const notice = media.parentElement.querySelector('[data-media-recovery]');
      if (notice?.contains?.(document.activeElement)) {
        display.setAttribute('tabindex', '-1');
        display.focus({ preventScroll: true });
      }
      notice?.remove();
    };
    display.addEventListener('load', recovered, true);
    display.addEventListener('loadeddata', recovered, true);
    display.addEventListener('click', event => {
      const button = event.target.closest?.('[data-media-action]');
      if (!button || !display.contains(button) || this.loading) return;
      if (button.dataset.mediaAction === 'next') { this.loadNextMeme(); return; }
      const media = button.closest('[data-media-recovery]')?.parentElement.querySelector('[data-recoverable-media]');
      if (!media) return;
      const message = button.closest('[data-media-recovery]')?.querySelector?.('p');
      if (message) message.textContent = 'Retrying media…';
      if (media.tagName === 'VIDEO') media.load();
      else media.src = media.getAttribute('src');
    });
    // Initial images may finish failing before the deferred bundle initializes.
    display.querySelectorAll('[data-recoverable-media]').forEach(media => {
      if ((media.tagName === 'IMG' && media.complete && media.naturalWidth === 0) ||
          (media.tagName === 'VIDEO' && media.error)) failed({ target: media });
    });
  }

  recentSnapshot(meme) {
    if (!meme || typeof meme.url !== 'string' || meme.url.length > 4096 ||
        !/^(https?:\/\/|\/(?!\/))/.test(meme.url) ||
        typeof meme.share_path !== 'string' || !/^\/meme\/[a-f0-9]{64}$/.test(meme.share_path)) return null;
    const snapshot = {};
    // Only list labels and exact navigation identity are needed on refresh.
    // Never persist media snapshots, ACK tokens or account-specific state.
    for (const key of ['url', 'title', 'share_path']) {
      if (typeof meme[key] === 'string') snapshot[key] = meme[key].slice(0, 4096);
    }
    // A gallery without its bounded media snapshot must not masquerade as a single image.
    if (meme.is_gallery || meme.gallery_images?.length) return null;
    return snapshot;
  }

  persistRecentMemes() {
    try {
      const items = (this.recentMemes || []).map(meme => this.recentSnapshot(meme)).filter(Boolean).slice(0, 20);
      const data = JSON.stringify({ version: 1, items });
      if (data.length <= 131072) window.sessionStorage.setItem('meme-explorer:recent:v1', data);
      else window.sessionStorage.removeItem('meme-explorer:recent:v1');
    } catch (_) { /* Storage is optional, including in private browsing. */ }
  }

  restoreRecentMemes() {
    try {
      const raw = window.sessionStorage.getItem('meme-explorer:recent:v1');
      if (!raw || raw.length > 131072) return;
      const saved = JSON.parse(raw);
      if (!saved || saved.version !== 1 || !Array.isArray(saved.items)) return;
      const seen = new Set();
      this.recentMemes = saved.items.slice(0, 20).map(meme => this.recentSnapshot(meme)).filter(meme => {
        if (!meme || seen.has(meme.url)) return false;
        seen.add(meme.url);
        meme.restoredFromStorage = true;
        return true;
      });
      this.renderRecentMemes();
    } catch (_) { /* Malformed or unavailable storage must not block navigation. */ }
  }

  rememberRecentMeme(meme) {
    if (!meme || typeof meme.url !== 'string' || !meme.url) return;
    this.recentMemes = [{ ...meme }, ...(this.recentMemes || []).filter(item => item.url !== meme.url)].slice(0, 20);
    this.persistRecentMemes();
    this.renderRecentMemes();
  }

  updateRecentState(url, patch) {
    const entry = this.recentMemes?.find(item => item.url === url);
    if (entry) Object.assign(entry, patch);
  }

  renderRecentMemes() {
    const list = document.querySelector('#recent-meme-list');
    if (!list) return;
    const active = document.activeElement;
    const focusedUrl = list.contains?.(active) ? active.dataset?.recentUrl : null;
    list.innerHTML = this.recentMemes?.length ? this.recentMemes.map((meme, index) =>
      `<button type="button" data-recent-index="${index}" data-recent-url="${this.escapeHtml(meme.url)}" style="display: block; padding: 12px; margin: 8px 0; width: 100%; text-align: left;">${this.escapeHtml(meme.title || 'Untitled meme')}</button>`
    ).join('') : '<p>No viewed memes yet.</p>';
    if (focusedUrl) {
      const replacement = Array.from(list.querySelectorAll('[data-recent-url]')).find(button => button.dataset.recentUrl === focusedUrl);
      (replacement || document.querySelector('#clear-recent-memes'))?.focus({ preventScroll: true });
    }
  }

  async openRecentMeme(index) {
    if (this.loading || !Number.isInteger(index) || !this.recentMemes?.[index]) return;
    const selected = this.recentMemes[index];
    if (selected.restoredFromStorage) {
      // Re-resolve content and current account state, rather than presenting
      // stale saved/liked defaults from a previous authenticated session.
      if (/^\/meme\/[a-f0-9]{64}$/.test(selected.share_path || '')) {
        window.location.assign(selected.share_path);
      } else {
        this.showError('This history entry cannot be reopened. Choose another meme.');
      }
      return;
    }
    const meme = { ...selected, ...(this.interactionStates?.get(selected.url) || {}) };
    const version = this.beginNavigation();
    try {
      this.showLoadingState();
      const rendered = await this.renderMeme(meme, true, version, true);
      if (rendered === false || version !== this.navigationVersion) return;
      this.currentMeme = meme;
      this.currentMemeShownAt = Date.now();
    } catch (_) {
      if (version === this.navigationVersion) this.showError('Could not reopen this meme.');
    } finally {
      if (version === this.navigationVersion) {
        this.loading = false;
        this.hideLoadingState();
      }
    }
  }

  bindGalleryControls() {
    const display = document.querySelector('#meme-display');
    display?.addEventListener('click', event => {
      const button = event.target.closest?.('[data-gallery-action]');
      if (!button || !display.contains(button)) return;
      event.preventDefault();
      if (button.dataset.galleryAction === 'previous') this.prevGalleryImage();
      if (button.dataset.galleryAction === 'next') this.nextGalleryImage();
    });
    let start = null;
    display?.addEventListener('touchstart', event => {
      start = null;
      if (!event.target.closest?.('.meme-gallery') || event.target.closest?.('button, a, input, textarea, select, [contenteditable]') || event.touches.length !== 1) return;
      start = { x: event.touches[0].clientX, y: event.touches[0].clientY };
    }, { passive: true });
    display?.addEventListener('touchmove', event => {
      if (!start) return;
      if (event.touches.length !== 1) { start = null; return; }
      const x = Math.abs(event.touches[0].clientX - start.x);
      const y = Math.abs(event.touches[0].clientY - start.y);
      if (y > 10 && y >= x) start = null;
    }, { passive: true });
    display?.addEventListener('touchend', event => {
      const origin = start;
      start = null;
      if (!origin || event.touches.length || !event.changedTouches.length) return;
      const x = event.changedTouches[0].clientX - origin.x;
      const y = event.changedTouches[0].clientY - origin.y;
      if (Math.abs(x) < 50 || Math.abs(x) <= Math.abs(y) * 1.5) return;
      if (x < 0) this.nextGalleryImage(); else this.prevGalleryImage();
    }, { passive: true });
    display?.addEventListener('touchcancel', () => { start = null; }, { passive: true });
  }

  bindNavigationButtons() {
    document.querySelectorAll('[data-action="prev-meme"]').forEach(button => {
      button.addEventListener('click', event => {
        event.preventDefault();
        this.loadPreviousMeme();
      });
    });
    // Bind to any "Next" buttons
    const nextButtons = document.querySelectorAll('[data-action="next-meme"], .next-button, #next-btn');
    nextButtons.forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        this.loadNextMeme();
      });
    });

    // Also bind to similar buttons if they exist
    const similarButtons = document.querySelectorAll('[data-action="similar-meme"]');
    similarButtons.forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        const subreddit = btn.dataset.subreddit;
        if (subreddit) {
          this.loadSimilarMeme(subreddit);
        }
      });
    });
  }

  setupPopStateHandler() {
    // Handle browser back/forward buttons
    window.addEventListener('popstate', async (event) => {
      if (event.state && event.state.meme) {
        const version = this.beginNavigation();
        try {
          const restored = { ...event.state.meme, ...(this.interactionStates?.get(event.state.meme.url) || {}) };
          const rendered = await this.renderMeme(restored, false, version);
          if (rendered === false || version !== this.navigationVersion) return;
          this.currentMeme = restored;
          this.historyPosition = Number.isInteger(event.state.memePosition) && event.state.memePosition >= 0 ? event.state.memePosition : 0;
          this.currentMemeShownAt = Date.now();
          document.title = `${event.state.meme.title || 'Random Meme'} - Meme Explorer`;
        } catch (error) {
          if (version === this.navigationVersion) this.showError('Could not restore this meme.');
        } finally {
          if (version === this.navigationVersion) {
            this.loading = false;
            this.hideLoadingState();
          }
        }
      } else {
        // Fallback: reload page
        window.location.reload();
      }
    });
  }

  beginNavigation() {
    this.stopScrollRestoration?.();
    this.navigationVersion = (this.navigationVersion || 0) + 1;
    this.loading = true;
    return this.navigationVersion;
  }

  seedInitialHistory() {
    const data = document.querySelector('#initial-meme-data')?.dataset.meme;
    if (!data) return;
    try {
      const meme = JSON.parse(data);
      if (!meme || typeof meme.url !== 'string' || !meme.url) return;
      const sharePath = document.querySelector('#viewer-share-data')?.dataset.sharePath;
      if (/^\/meme\/[a-f0-9]{64}$/.test(sharePath || '')) meme.share_path = sharePath;
      this.currentMeme = meme;
      this.currentMemeShownAt = Date.now();
      this.historyPosition = 0;
      history.replaceState({ ...(history.state || {}), meme, memePosition: 0 }, '', window.location.href);
    } catch (error) {
      console.warn('[MemeNavigation] Could not seed initial history');
    }
  }

  loadPreviousMeme() {
    if (this.loading || !(this.historyPosition > 0)) return;
    window.history.back();
  }

  rememberGalleryPosition(index) {
    if (this.loading || !this.currentMeme || !Number.isInteger(index) || index < 0) return;
    this.currentMeme = { ...this.currentMeme, gallery_index: index };
    this.updateRecentState(this.currentMeme.url, { gallery_index: index });
    try {
      history.replaceState({ ...(history.state || {}), meme: this.currentMeme }, '', window.location.href);
    } catch (_) { /* History storage restrictions must not break gallery controls. */ }
    const display = document.querySelector('#meme-display');
    if (display && this.currentMeme.is_gallery) this.observeImpression(this.currentMeme, display);
  }

  bindVideoRecovery() {
    const display = document.querySelector('#meme-display');
    const remember = event => {
      const video = event.target;
      if (video.tagName !== 'VIDEO' || this.loading || !this.currentMeme || !Number.isFinite(video.currentTime) || video.currentTime < 0) return;
      // Coalesce frequent timeupdate events; pause/seek always preserve position.
      if (event.type === 'timeupdate' && Math.abs((this.currentMeme.video_time || 0) - video.currentTime) < 2) return;
      this.currentMeme = { ...this.currentMeme, video_time: video.currentTime };
      this.updateRecentState(this.currentMeme.url, { video_time: video.currentTime });
      try {
        history.replaceState({ ...(history.state || {}), meme: this.currentMeme }, '', window.location.href);
      } catch (_) { /* Playback remains usable when history storage is restricted. */ }
    };
    ['timeupdate', 'pause', 'seeked'].forEach(name => display?.addEventListener(name, remember, true));
  }

  bindScrollRecovery() {
    // This viewer owns same-document history restoration; avoid competing with
    // native automatic restoration while its media is being replaced.
    const previous = history.scrollRestoration;
    history.scrollRestoration = 'manual';
    window.addEventListener('pagehide', () => { history.scrollRestoration = previous; });
    window.addEventListener('pageshow', () => { history.scrollRestoration = 'manual'; });
    let scheduled = false;
    window.addEventListener('scroll', () => {
      if (scheduled || this.loading || !this.currentMeme) return;
      const version = this.navigationVersion;
      scheduled = true;
      requestAnimationFrame(() => {
        scheduled = false;
        if (this.loading || version !== this.navigationVersion || !this.currentMeme) return;
        const offset = window.scrollY;
        if (!Number.isFinite(offset) || offset < 0) return;
        this.currentMeme = { ...this.currentMeme, scroll_y: offset };
        this.updateRecentState(this.currentMeme.url, { scroll_y: offset });
        try {
          history.replaceState({ ...(history.state || {}), meme: this.currentMeme }, '', window.location.href);
        } catch (_) { /* Reading content must work when history storage fails. */ }
      });
    }, { passive: true });
  }

  restoreScrollPosition(meme, pushState, version, display = null) {
    this.stopScrollRestoration?.();
    if (version !== this.navigationVersion) return;
    const offset = !pushState && Number.isFinite(meme.scroll_y) ? Math.max(0, meme.scroll_y) : 0;
    window.scrollTo({ top: offset, behavior: 'instant' });
    if (pushState || !offset || !display) return;
    let stopped = false;
    let timeout;
    let observer;
    const inputEvents = ['wheel', 'touchstart', 'pointerdown', 'keydown', 'pagehide'];
    const stop = () => {
      if (stopped) return;
      stopped = true;
      clearTimeout(timeout);
      observer?.disconnect();
      display.removeEventListener('load', retry, true);
      display.removeEventListener('loadedmetadata', retry, true);
      inputEvents.forEach(name => window.removeEventListener(name, stop, true));
    };
    const retry = () => {
      if (stopped || version !== this.navigationVersion || !display.isConnected) { stop(); return; }
      window.scrollTo({ top: offset, behavior: 'instant' });
      if (Math.abs(window.scrollY - offset) <= 2) stop();
    };
    this.stopScrollRestoration = stop;
    display.addEventListener('load', retry, true);
    display.addEventListener('loadedmetadata', retry, true);
    inputEvents.forEach(name => window.addEventListener(name, stop, { capture: true, passive: true }));
    if (typeof ResizeObserver !== 'undefined') {
      observer = new ResizeObserver(retry);
      observer.observe(display);
    }
    timeout = setTimeout(stop, 3000);
    retry();
  }

  restoreVideoPosition(meme, display, version) {
    if (!Number.isFinite(meme.video_time) || meme.video_time < 0) return;
    const video = display.querySelector('video');
    if (!video) return;
    const restore = () => {
      if (version !== this.navigationVersion || !display.contains(video)) return;
      try {
        const maximum = Number.isFinite(video.duration) ? Math.max(0, video.duration - 0.1) : meme.video_time;
        video.currentTime = Math.min(meme.video_time, maximum);
      } catch (_) { /* Some media sources cannot seek; leave native controls usable. */ }
    };
    if (video.readyState >= 1) restore();
    else video.addEventListener('loadedmetadata', restore, { once: true });
  }

  updatePreviousAvailability() {
    const button = document.querySelector('[data-action="prev-meme"]');
    if (button) button.disabled = this.loading || !(this.historyPosition > 0);
  }

  withConfirmedInteractions(meme) {
    return { ...meme, ...(this.interactionStates?.get(meme.url) || {}) };
  }

  rememberInteraction(detail) {
    if (!detail || typeof detail.url !== 'string') return;
    this.interactionStates ||= new Map();
    const patch = {};
    if (typeof detail.liked === 'boolean') patch.liked = detail.liked;
    if (typeof detail.saved === 'boolean') patch.saved = detail.saved;
    if (Number.isFinite(Number(detail.likes)) && detail.likes != null) patch.likes = Number(detail.likes);
    this.interactionStates.set(detail.url, { ...(this.interactionStates.get(detail.url) || {}), ...patch });
    this.updateRecentState(detail.url, patch);
    if (this.interactionStates.size > 200) this.interactionStates.delete(this.interactionStates.keys().next().value);
    if (this.currentMeme?.url !== detail.url) return;
    this.currentMeme = { ...this.currentMeme, ...patch };
    try {
      history.replaceState({ ...(history.state || {}), meme: this.currentMeme }, '', window.location.href);
    } catch (_) { /* Restricted history storage must not break interactions. */ }
  }

  handleKeyPress(event) {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) return;
    const focused = document.activeElement;
    const nextFocused = event.code === 'Space' && focused?.matches?.('[data-action="next-meme"], .next-button, #next-btn');
    if (nextFocused && !event.defaultPrevented && !event.metaKey && !event.ctrlKey && !event.altKey && !document.body.classList.contains('modal-open')) {
      // Prevent native keyup activation so this path cannot also dispatch a click.
      event.preventDefault();
      if (!event.repeat && !focused.disabled) this.loadNextMeme();
      return;
    }
    // Don't trigger if user is typing in an input
    if (this.isInputFocused() || event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey || document.body.classList.contains('modal-open')) {
      return;
    }

    // Ignore OS/browser key-repeat events. Holding a key down (even briefly,
    // which is very easy to do with the space bar) fires many synthetic
    // keydown events per second with event.repeat === true. Without this
    // guard, one "held" Space press fires loadNextMeme() over and over in
    // rapid succession - which looks exactly like an auto-playing carousel
    // instead of a single, deliberate meme change per press.
    if (event.repeat) {
      return;
    }

    if (event.code === 'ArrowLeft' || event.code === 'ArrowRight') {
      const gallery = document.querySelector('#meme-display .gallery-carousel, #meme-display .meme-gallery');
      if (gallery) {
        const button = gallery.querySelector(event.code === 'ArrowLeft' ? '.gallery-prev' : '.gallery-next');
        if (button) {
          event.preventDefault();
          button.click();
          return;
        }
      }
    }

    switch(event.code) {
      case 'Space':
      case 'ArrowRight':
        event.preventDefault();
        this.loadNextMeme();
        break;
      case 'ArrowLeft':
        event.preventDefault();
        this.loadPreviousMeme();
        break;
      case 'KeyL':
        event.preventDefault();
        this.triggerLike();
        break;
      case 'KeyS':
        event.preventDefault();
        this.triggerSave();
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
      activeElement.tagName === 'SELECT' ||
      activeElement.tagName === 'BUTTON' ||
      activeElement.tagName === 'A' ||
      activeElement.isContentEditable
    );
  }

  /**
   * CORE METHOD: Load next meme via AJAX
   * This is the main UX improvement - no page reload!
   */
  async loadNextMeme() {
    if (this.loading) {
      console.log('[MemeNavigation] Already loading, please wait...');
      return;
    }

    console.log('[MemeNavigation] Loading next meme via AJAX...');
    const version = this.beginNavigation();

    // Next is navigation, not an explicit negative preference signal.
    let succeeded = false;

    try {
      // Show loading state
      this.showLoadingState();

      // Use prefetched meme if available
      let meme;
      if (!this.prefetchedMeme && this.prefetchPromise) await this.prefetchPromise;
      if (version !== this.navigationVersion) return;
      if (this.prefetchedMeme) {
        console.log('[MemeNavigation] Using prefetched meme');
        meme = this.prefetchedMeme;
        this.prefetchedMeme = null;
      } else {
        // Fetch new meme
        meme = await this.fetchMeme('/random.json');
      }

      // Cached/stale selection must never repaint the currently displayed meme.
      for (let attempt = 0; meme.url === this.currentMeme?.url && !meme.inventory_exhausted && attempt < 2; attempt++) {
        if (version !== this.navigationVersion) return;
        meme = await this.fetchMeme('/random.json');
      }
      if (meme.url === this.currentMeme?.url && meme.inventory_exhausted === true) {
        if (version !== this.navigationVersion) return;
        const supply = document.getElementById('feed-supply-status');
        if (supply) supply.hidden = false;
        this.showError('No different meme is available right now. Your current meme is still here. Try Search or return later.');
        return;
      }
      if (meme.url === this.currentMeme?.url) throw new Error('No different meme available');

      // Render the new meme
      if (version !== this.navigationVersion) return;
      meme = this.withConfirmedInteractions(meme);
      const rendered = await this.renderMeme(meme, true, version);
      if (rendered === false || version !== this.navigationVersion) return;
      this.currentMeme = meme;
      this.currentMemeShownAt = Date.now();

      // Prefetch next meme in background
      succeeded = true;

      // Track analytics
      this.trackView(meme);

      console.log('[MemeNavigation] ✅ Meme loaded successfully');

    } catch (error) {
      if (version !== this.navigationVersion) return;
      console.error('[MemeNavigation] Failed to load meme:', error);
      this.showError('Failed to load meme. Please try again.');


    } finally {
      if (version === this.navigationVersion) {
        this.loading = false;
        this.hideLoadingState();
        if (succeeded) this.prefetchNext();
      }
    }
  }

  /**
   * Load similar meme from same subreddit
   */
  async loadSimilarMeme(subreddit) {
    if (this.loading) return;

    console.log(`[MemeNavigation] Loading similar meme from r/${subreddit}...`);
    const version = this.beginNavigation();
    let succeeded = false;

    try {
      this.showLoadingState();

      const meme = this.withConfirmedInteractions(await this.fetchMeme(`/similar.json?subreddit=${encodeURIComponent(subreddit)}`));
      if (version !== this.navigationVersion) return;
      const rendered = await this.renderMeme(meme, true, version);
      if (rendered === false || version !== this.navigationVersion) return;
      this.currentMeme = meme;
      this.currentMemeShownAt = Date.now();
      succeeded = true;
      this.trackView(meme);

    } catch (error) {
      if (version !== this.navigationVersion) return;
      console.error('[MemeNavigation] Failed to load similar meme:', error);
      this.showError('Could not load a similar meme. Your current meme is still here.');

    } finally {
      if (version === this.navigationVersion) {
        this.loading = false;
        this.hideLoadingState();
        if (succeeded) this.prefetchNext();
      }
    }
  }

  // Replace media with an optional transition; reduced motion swaps immediately.
  async renderMeme(meme, pushState = true, version = this.navigationVersion, recoverPosition = false) {
    const display = document.querySelector('#meme-display');
    const info = document.querySelector('#meme-info');

    if (!display) {
      console.error('[MemeNavigation] #meme-display not found');
      return;
    }

    const reducedMotion = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    display.classList.remove('meme-transition-in');
    display.classList.remove('meme-transition-out');
    if (!reducedMotion) {
      void display.offsetWidth;
      display.classList.add('meme-transition-out');
      await this.wait(this.transitionDuration);
    }
    // A later Back/Forward action owns the display, controls and history now.
    if (version !== this.navigationVersion) return false;
    Object.assign(meme, this.withConfirmedInteractions(meme));

    // Update meme display
    document.getElementById('meme-navigation-error')?.remove();
    display.innerHTML = this.renderMemeHTML(meme);
    display.dataset.memeUrl = meme.url || '';
    const manualShare = document.querySelector('#manual-share');
    if (manualShare) manualShare.hidden = true;
    const saveSignIn = document.querySelector('#save-sign-in');
    if (saveSignIn) saveSignIn.hidden = true;
    const shareData = document.querySelector('#viewer-share-data');
    if (shareData) shareData.dataset.sharePath = meme.share_path || '';
    if (meme.is_gallery) this.showGallerySlide(meme.gallery_index || 0, false);
    this.restoreVideoPosition(meme, display, version);
    this.observeImpression(meme, display);

    // Update info/metadata
    if (info) {
      info.innerHTML = this.renderInfoHTML(meme);
    }

    // Update controls state
    this.updateControlsState(meme);

    // Play the springy "in" animation
    display.classList.remove('meme-transition-out');
    if (!reducedMotion) {
      void display.offsetWidth;
      display.classList.add('meme-transition-in');
    }

    // Push state for browser history
    if (pushState) {
      this.updateURL(meme);
    }

    this.restoreScrollPosition(meme, pushState && !recoverPosition, version, display);
    this.announceMeme(meme, version);
    return true;
  }

  announceMeme(meme, version) {
    const supply = document.getElementById('feed-supply-status');
    if (supply && version === this.navigationVersion) supply.hidden = meme.inventory_exhausted !== true;
    if (version !== this.navigationVersion) return;
    const status = document.getElementById('viewer-status');
    if (!status) return;
    const title = String(meme.title || 'Untitled meme').slice(0, 180);
    const type = meme.is_gallery ? 'Gallery' : meme.media_type === 'video' ? 'Video' : 'Meme';
    // Text assignment avoids interpreting content titles as HTML.
    status.textContent = `${type}: ${title}`;
  }

  /**
   * Generate HTML for meme based on type
   */
  renderMemeHTML(meme) {
    // Video meme
    if (meme.media_type === 'video' || meme.url?.includes('v.redd.it')) {
      return `
        <div class="meme-video-container">
          <video
            data-recoverable-media
            src="${this.escapeHtml(this.safeMediaUrl(meme.url))}"
            controls
            muted
            loop
            playsinline
            class="meme-video"
          >
            Your browser doesn't support video playback.
          </video>
        </div>
      `;
    }

    // Gallery meme
    if (meme.is_gallery && meme.gallery_images?.length > 0) {
      return this.renderGalleryHTML(meme.gallery_images, meme.title);
    }

    // Standard image meme
    return `
      <div class="meme-image-container">
        <img
          id="meme-image"
          ${this.mediaDimensionAttributes(meme)}
          data-recoverable-media
          src="${this.escapeHtml(this.safeMediaUrl(meme.url))}"
          alt="${this.escapeHtml(meme.title || 'Meme')}"
          class="meme-image"
          loading="eager"
        />
      </div>
    `;
  }

  /**
   * Render gallery/carousel
   */
  renderGalleryHTML(images, title) {
    const imageElements = images.map((img, index) => `
      <div class="gallery-slide${index === 0 ? ' active' : ''}" data-index="${index}" ${index === 0 ? '' : 'hidden style="display: none;"'}>
        <img
          data-recoverable-media
          ${this.mediaDimensionAttributes(img)}
          src="${this.escapeHtml(this.safeMediaUrl(img.url || img))}"
          alt="${this.escapeHtml(title)} - Image ${index + 1}"
          class="gallery-image"
          loading="${index === 0 ? 'eager' : 'lazy'}"
        />
      </div>
    `).join('');

    return `
      <div class="meme-gallery">
        <div class="gallery-container">
          ${imageElements}
        </div>
        <div class="gallery-controls">
          <button type="button" class="gallery-prev" data-gallery-action="previous" aria-label="Previous gallery image">‹</button>
          <span class="gallery-counter" role="status" aria-live="polite">1 / ${images.length}</span>
          <button type="button" class="gallery-next" data-gallery-action="next" aria-label="Next gallery image">›</button>
        </div>
      </div>
    `;
  }

  mediaDimensionAttributes(media) {
    const width = media?.width;
    const height = media?.height;
    const valid = value => /^[1-9]\d{0,4}$/.test(String(value)) && Number(value) <= 30000;
    return valid(width) && valid(height) ? `width="${Number(width)}" height="${Number(height)}" style="aspect-ratio: auto ${Number(width)} / ${Number(height)} !important;"` : '';
  }

  /**
   * Render meme info/metadata
   */
  renderInfoHTML(meme) {
    const subreddit = this.escapeHtml(meme.subreddit || 'unknown');
    const title = this.escapeHtml(meme.title || 'Untitled Meme');
    const likes = parseInt(meme.likes) || 0;
    const poolType = this.escapeHtml(meme.diversity_pool || meme.selection_method || 'random');
    const source = this.redditSourceUrl(meme.reddit_path || meme.permalink);

    return `
      <h2 class="meme-title" id="viewer-meme-title">${title}</h2>
      <button type="button" data-action="toggle-meme-title" aria-controls="viewer-meme-title" aria-expanded="true">Hide title</button>
      <div class="meme-meta">
        <span class="meme-subreddit">
          <a href="/search?q=${encodeURIComponent(meme.subreddit || '')}" title="Search r/${subreddit}">
            r/${subreddit}
          </a>
        </span>
        <span class="meme-divider">•</span>
        <span class="meme-likes">${likes} likes</span>
        ${source ? `<a href="${this.escapeHtml(source)}" target="_blank" rel="noopener" aria-label="View original post on Reddit">Source →</a>` : ''}
        ${poolType !== 'random' ? `
          <span class="meme-divider">•</span>
          <span class="meme-pool-type badge">${poolType}</span>
        ` : ''}
      </div>
      ${meme.total_unseen ? `
        <div class="memes-remaining">
          <small>${this.escapeHtml(meme.total_unseen)} unseen memes remaining</small>
        </div>
      ` : ''}
    `;
  }

  redditSourceUrl(value) {
    if (typeof value !== 'string' || /[\u0000-\u0020<>"'\\]/.test(value) || value.startsWith('//')) return null;
    try {
      const url = new URL(value, 'https://www.reddit.com');
      if (!['http:', 'https:'].includes(url.protocol) || !['reddit.com', 'www.reddit.com', 'old.reddit.com'].includes(url.hostname) || url.username || url.password || url.port) return null;
      if (!/^\/r\/[A-Za-z0-9_]+\/comments\/[A-Za-z0-9]+(?:\/.*)?$/.test(url.pathname)) return null;
      return `https://www.reddit.com${url.pathname}`;
    } catch (_) { return null; }
  }

  /**
   * Update like/save button states
   */
  updateControlsState(meme) {
    // Reset like button
    const likeBtn = document.querySelector('#like-btn');
    if (likeBtn) {
      likeBtn.classList.toggle('liked', meme.liked === true);
      likeBtn.dataset.liked = String(meme.liked === true);
      likeBtn.setAttribute('aria-pressed', String(meme.liked === true));
      likeBtn.dataset.memeUrl = meme.url;
    }

    // Update like count
    const likeCount = document.querySelector('#like-count');
    if (likeCount) {
      likeCount.textContent = meme.likes || 0;
    }

    // Reset save button
    const saveBtn = document.querySelector('#save-btn');
    if (saveBtn) {
      saveBtn.classList.toggle('saved', meme.saved === true);
      saveBtn.dataset.saved = String(meme.saved === true);
      saveBtn.setAttribute('aria-pressed', String(meme.saved === true));
      saveBtn.dataset.memeUrl = meme.url;
    }
  }

  /**
   * Show loading state with spinner
   */
  showLoadingState() {
    const status = document.getElementById('viewer-status');
    if (status) status.textContent = 'Loading meme…';
    const display = document.querySelector('#meme-display');
    if (display) {
      display.classList.add('loading');
      display.setAttribute('aria-busy', 'true');
    }

    // Disable controls while loading
    const controls = document.querySelectorAll('.meme-controls button, .viewer-navigation button');
    controls.forEach(btn => btn.disabled = true);
  }

  /**
   * Hide loading state
   */
  hideLoadingState() {
    const status = document.getElementById('viewer-status');
    // Do not erase a newer content announcement or leave a stale loading one.
    if (status?.textContent === 'Loading meme…') status.textContent = '';
    const display = document.querySelector('#meme-display');
    if (display) {
      display.classList.remove('loading');
      display.setAttribute('aria-busy', 'false');
    }

    // Re-enable controls
    const controls = document.querySelectorAll('.meme-controls button, .viewer-navigation button');
    controls.forEach(btn => btn.disabled = false);
    this.updatePreviousAvailability();
  }

  /**
   * Show error message
   */
  showError(message) {
    const display = document.querySelector('#meme-display');
    if (display) {
      let error = document.getElementById('meme-navigation-error');
      if (!error) {
        error = document.createElement('div');
        error.id = 'meme-navigation-error';
        error.className = 'error-message';
        error.setAttribute('role', 'alert');
        display.after(error);
      }
      error.textContent = message + ' Use Next meme to retry.';
    }
  }

  /**
   * Update browser URL without reload
   */
  updateURL(meme) {
    const position = (this.historyPosition || 0) + 1;
    const state = { meme: meme, memePosition: position };
    const title = meme.title || 'Random Meme';
    const url = '/random'; // Keep URL simple

    try {
      history.pushState(state, title, url);
      this.historyPosition = position;
      document.title = `${title} - Meme Explorer`;
    } catch (e) {
      console.warn('[MemeNavigation] Failed to update history:', e);
    }
  }

  /**
   * Prefetch next meme in background for instant loading
   */
  prefetchNext() {
    if (this.dataSavingEnabled()) return this.prefetchPromise;
    // Don't prefetch if already loading or already have one
    if (this.loading || this.prefetchedMeme || this.prefetchPromise) {
      return this.prefetchPromise;
    }

    console.log('[MemeNavigation] Prefetching next meme...');

    this.prefetchPromise = this.fetchMeme('/random.json')
      .then(meme => {
        this.prefetchedMeme = meme;
        console.log('[MemeNavigation] ✅ Next meme prefetched');

        // Preload image to cache it
        if (!this.dataSavingEnabled() && meme.url && !meme.url.includes('v.redd.it')) {
          const img = new Image();
          img.src = this.safeMediaUrl(meme.url);
        }
      })
      .catch(error => {
        console.warn('[MemeNavigation] Prefetch failed:', error);
        // Silent fail - not critical
      })
      .finally(() => { this.prefetchPromise = null; });
    return this.prefetchPromise;
  }

  dataSavingEnabled() {
    return typeof navigator !== 'undefined' && navigator.connection?.saveData === true;
  }

  async fetchMeme(url) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    try {
      const response = await fetch(url, { signal: controller.signal, cache: 'no-store' });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const meme = await response.json();
      if (!meme || typeof meme !== 'object' || Array.isArray(meme) || typeof meme.url !== 'string' || !meme.url) {
        throw new Error('Invalid meme response');
      }
      return meme;
    } finally {
      clearTimeout(timeout);
    }
  }

  observeImpression(meme, display) {
    this.stopImpressionObserver?.();
    if (!meme.impression_id || typeof IntersectionObserver === 'undefined') return;
    if (this.qualifiedImpressions?.has(meme.impression_id)) return;
    const media = display.querySelector('.gallery-slide.active img') || display.querySelector('img, video');
    if (!media) return;
    let timer = null;
    let visible = false;
    let sent = false;
    const ready = () => !media.dataset?.mediaFailed && (media.tagName === 'VIDEO' ? media.readyState >= 2 : media.complete && media.naturalWidth > 0);
    const cancel = () => { clearTimeout(timer); timer = null; };
    const update = () => {
      cancel();
      if (!visible || document.visibilityState !== 'visible' || !ready() || sent) return;
      timer = setTimeout(() => {
        if (!ready() || document.visibilityState !== 'visible') return;
        sent = true;
        this.qualifiedImpressions ||= new Set();
        this.qualifiedImpressions.add(meme.impression_id);
        if (this.qualifiedImpressions.size > 200) this.qualifiedImpressions.delete(this.qualifiedImpressions.values().next().value);
        this.rememberRecentMeme(this.currentMeme?.url === meme.url ? this.currentMeme : meme);
        this.acknowledgeImpression(meme.impression_id);
        this.stopImpressionObserver?.();
      }, 1000);
    };
    const observer = new IntersectionObserver(entries => {
      const entry = entries[0];
      const viewportArea = entry.rootBounds ? entry.rootBounds.width * entry.rootBounds.height : entry.boundingClientRect.width * entry.boundingClientRect.height;
      const requiredArea = Math.min(entry.boundingClientRect.width * entry.boundingClientRect.height, viewportArea) * 0.5;
      visible = entry.isIntersecting && entry.intersectionRect.width * entry.intersectionRect.height >= requiredArea;
      update();
    }, { threshold: Array.from({ length: 101 }, (_, index) => index / 100) });
    observer.observe(media);
    media.addEventListener('load', update);
    media.addEventListener('loadeddata', update);
    document.addEventListener('visibilitychange', update);
    this.stopImpressionObserver = () => {
      cancel(); observer.disconnect();
      media.removeEventListener('load', update);
      media.removeEventListener('loadeddata', update);
      document.removeEventListener('visibilitychange', update);
    };
  }

  async acknowledgeImpression(id) {
    // The same server-issued ID makes retry after a lost response safe.
    for (let attempt = 0; attempt < 3; attempt++) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 5000);
      try {
        const response = await fetch('/api/impressions', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ impression_id: id }), signal: controller.signal
        });
        if (response.ok) return true;
        // Expired IDs, authentication and validation errors are terminal.
        if (response.status < 500 && response.status !== 429) return false;
      } catch (_) {
        // Transient network failure or request deadline; retry within budget.
      } finally {
        clearTimeout(timeout);
      }
      if (attempt < 2) await this.wait(500 * (2 ** attempt));
    }
    return false;
  }

  /**
   * Track meme view for analytics
   */
  trackView(meme) {
    // Send view event to analytics
    if (typeof gtag !== 'undefined') {
      gtag('event', 'meme_view', {
        meme_url: meme.url,
        subreddit: meme.subreddit,
        pool_type: meme.diversity_pool || 'random'
      });
    }

    // Custom analytics endpoint if exists
    if (typeof window.trackMemeView === 'function') {
      window.trackMemeView(meme);
    }
  }

  // Helper methods

  toggleTitle() {
    const titleElement = document.querySelector('#viewer-meme-title');
    if (titleElement) {
      titleElement.hidden = !titleElement.hidden;
      titleElement.style.display = titleElement.hidden ? 'none' : '';
      const button = document.querySelector('#meme-info [data-action="toggle-meme-title"]');
      if (button) {
        button.setAttribute('aria-expanded', String(!titleElement.hidden));
        button.textContent = titleElement.hidden ? 'Show title' : 'Hide title';
      }
    }
  }

  triggerLike() {
    const likeBtn = document.querySelector('#like-btn');
    if (likeBtn) likeBtn.click();
  }

  triggerSave() {
    const saveBtn = document.querySelector('#save-btn');
    if (saveBtn) saveBtn.click();
  }

  wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Brief full-viewport light pulse (CSS-driven, GPU-accelerated) to add
   * extra "impact" the instant a new meme lands. Reuses a single element
   * so rapid Space presses don't pile up DOM nodes.
   */
  flashPulse() {
    let pulse = document.querySelector('.meme-flash-pulse');
    if (!pulse) {
      pulse = document.createElement('div');
      pulse.className = 'meme-flash-pulse';
      document.body.appendChild(pulse);
    } else {
      // Restart the animation if it's already mid-flight
      pulse.style.animation = 'none';
      void pulse.offsetWidth;
      pulse.style.animation = '';
    }
  }

  escapeHtml(text) {
    return String(text ?? '').replace(/[&<>"']/g, character => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[character]);
  }

  safeMediaUrl(value) {
    const fallback = '/images/meme-placeholder.svg';
    if (typeof value !== 'string' || !value || /[\u0000-\u0020\u007f<>"'\\]/.test(value)) return fallback;
    if (value.startsWith('/') && !value.startsWith('//')) return value;
    try {
      const url = new URL(value);
      return ['http:', 'https:'].includes(url.protocol) && !url.username && !url.password ? value : fallback;
    } catch (_) {
      return fallback;
    }
  }

  // Gallery navigation methods

  nextGalleryImage() {
    const container = document.querySelector('.gallery-container');
    if (!container) return;

    const slides = container.querySelectorAll('.gallery-slide');
    if (!slides.length) return;
    const current = container.querySelector('.gallery-slide.active') || slides[0];
    const currentIndex = parseInt(current.dataset.index);
    const nextIndex = (currentIndex + 1) % slides.length;

    this.showGallerySlide(nextIndex);
  }

  prevGalleryImage() {
    const container = document.querySelector('.gallery-container');
    if (!container) return;

    const slides = container.querySelectorAll('.gallery-slide');
    if (!slides.length) return;
    const current = container.querySelector('.gallery-slide.active') || slides[0];
    const currentIndex = parseInt(current.dataset.index);
    const prevIndex = currentIndex === 0 ? slides.length - 1 : currentIndex - 1;

    this.showGallerySlide(prevIndex);
  }

  showGallerySlide(index, remember = true) {
    const container = document.querySelector('#meme-display .gallery-container');
    if (!container) return;
    const slides = container.querySelectorAll('.gallery-slide');
    if (!slides.length) return;
    index = Number.isInteger(index) ? Math.max(0, Math.min(index, slides.length - 1)) : 0;
    const counter = document.querySelector('#meme-display .gallery-counter');

    slides.forEach((slide, i) => {
      slide.classList.toggle('active', i === index);
      slide.hidden = i !== index;
      slide.style.display = i === index ? '' : 'none';
    });

    if (counter) {
      counter.textContent = `${index + 1} / ${slides.length}`;
    }
    if (remember) this.rememberGalleryPosition(index);
  }
}
