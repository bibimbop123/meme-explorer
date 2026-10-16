import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

// Load the browser ES module without changing the Vite project's package type.
const source = await readFile(new URL('../../public/js/modules/meme-navigation.js', import.meta.url), 'utf8');
const { MemeNavigation } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const navigation = () => Object.create(MemeNavigation.prototype);

for (const exhausted of [false, true]) {
  test(`Next rejects duplicate prefetched content (exhausted=${exhausted})`, async () => {
    const nav = navigation();
    let calls = 0;
    const renders = [];
    const errors = [];
    Object.assign(nav, {
      currentMeme: { url: '/same.jpg' }, prefetchedMeme: { url: '/same.jpg' },
      showLoadingState() {}, hideLoadingState() {}, prefetchNext() {}, trackView() {},
      async fetchMeme() { calls++; return { url: exhausted ? '/same.jpg' : '/different.jpg' }; },
      async renderMeme(meme) { renders.push(meme.url); return true; },
      showError: message => errors.push(message)
    });
    await nav.loadNextMeme();
    assert.deepEqual(renders, exhausted ? [] : ['/different.jpg']);
    assert.equal(calls, exhausted ? 2 : 1);
    assert.equal(errors.length, exhausted ? 1 : 0);
    assert.equal(nav.loading, false);
  });
}

test('meme fetch bypasses browser HTTP cache', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async (_url, options) => {
    assert.equal(options.cache, 'no-store');
    return { ok: true, json: async () => ({ url: '/fresh.jpg' }) };
  };
  try { assert.equal((await navigation().fetchMeme('/random.json')).url, '/fresh.jpg'); }
  finally { globalThis.fetch = original; }
});

test('navigation status announces current content as text and ignores stale operations', () => {
  const original = globalThis.document;
  const status = {};
  globalThis.document = { getElementById: () => status };
  const nav = navigation();
  nav.navigationVersion = 2;
  try {
    nav.announceMeme({ title: '<script>title</script>', is_gallery: true }, 2);
    assert.equal(status.textContent, 'Gallery: <script>title</script>');
    assert.equal(status.innerHTML, undefined);
    nav.announceMeme({ title: 'Stale' }, 1);
    assert.equal(status.textContent, 'Gallery: <script>title</script>');
    nav.announceMeme({ title: 'x'.repeat(500), media_type: 'video' }, 2);
    assert.equal(status.textContent.length, 187);
  } finally { globalThis.document = original; }
});

test('AJAX source attribution accepts real Reddit posts and rejects lookalike hosts', () => {
  const nav = navigation();
  assert.equal(nav.redditSourceUrl('/r/funny/comments/abc123/title/'), 'https://www.reddit.com/r/funny/comments/abc123/title/');
  for (const value of ['https://reddit.com.attacker.example/r/funny/comments/abc123/', '//attacker.example/path', 'javascript:alert(1)', '/r/funny']) {
    assert.equal(nav.redditSourceUrl(value), null);
  }
  assert.match(nav.renderInfoHTML({ reddit_path: '/r/funny/comments/abc123/' }), /View original post on Reddit/);
  assert.ok(!nav.renderInfoHTML({ reddit_path: 'javascript:bad' }).includes('Source →'));
});

test('title disclosure synchronizes hidden state, label and expanded semantics', () => {
  const original = globalThis.document;
  const title = { hidden: false, style: {} };
  const button = { setAttribute(key, value) { this[key] = value; } };
  globalThis.document = { querySelector: selector => selector === '#viewer-meme-title' ? title : button };
  try {
    const nav = navigation();
    nav.toggleTitle();
    assert.equal(title.hidden, true);
    assert.equal(button['aria-expanded'], 'false');
    assert.equal(button.textContent, 'Show title');
    nav.toggleTitle();
    assert.equal(title.hidden, false);
    assert.equal(button['aria-expanded'], 'true');
    assert.equal(button.textContent, 'Hide title');
    assert.match(nav.renderInfoHTML({ title: 'New meme' }), /aria-controls="viewer-meme-title"/);
  } finally { globalThis.document = original; }
});

test('Next after a liked or saved meme never sends negative preference feedback', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () => assert.fail('navigation must not post skip feedback');
  const nav = navigation();
  Object.assign(nav, {
    currentMeme: { url: '/enjoyed.jpg', liked: true, saved: true, subreddit: 'funny' },
    prefetchedMeme: { url: '/next.jpg' },
    showLoadingState() {}, hideLoadingState() {}, trackView() {}, prefetchNext() {},
    async renderMeme() { return true; }
  });
  try {
    await nav.loadNextMeme();
    assert.equal(nav.currentMeme.url, '/next.jpg');
    assert.ok(!source.includes("fetch('/api/skip-meme'"));
  } finally { globalThis.fetch = originalFetch; }
});

test('qualified gallery impression does not attach another observer on slide changes', () => {
  const original = globalThis.IntersectionObserver;
  let stopped = 0;
  globalThis.IntersectionObserver = class { constructor() { assert.fail('already qualified'); } };
  const nav = navigation();
  nav.stopImpressionObserver = () => { stopped++; };
  nav.qualifiedImpressions = new Set(['gallery-id']);
  try {
    nav.observeImpression({ impression_id: 'gallery-id' }, { querySelector() { assert.fail('must not rescan qualified content'); } });
    assert.equal(stopped, 1);
  } finally { globalThis.IntersectionObserver = original; }
});

test('recent list refresh preserves focused meme identity after reordering', () => {
  const original = globalThis.document;
  let focused = 0;
  const active = { dataset: { recentUrl: '/original.jpg' } };
  const replacement = { dataset: { recentUrl: '/original.jpg' }, focus: options => { assert.equal(options.preventScroll, true); focused++; } };
  const list = { contains: element => element === active, querySelectorAll: () => [replacement] };
  globalThis.document = { activeElement: active, querySelector: () => list };
  const nav = navigation();
  nav.recentMemes = [{ url: '/new.jpg', title: 'New' }, { url: '/original.jpg', title: 'Original' }];
  try {
    nav.renderRecentMemes();
    assert.equal(focused, 1);
    assert.ok(list.innerHTML.includes('data-recent-url="/original.jpg"'));
    document.activeElement = {};
    nav.renderRecentMemes();
    assert.equal(focused, 1);
  } finally { globalThis.document = original; }
});

test('recent-list eviction moves focus to a stable control', () => {
  const original = globalThis.document;
  let focused = false;
  const active = { dataset: { recentUrl: '/evicted.jpg' } };
  const list = { contains: () => true, querySelectorAll: () => [] };
  const clear = { focus: () => { focused = true; } };
  globalThis.document = { activeElement: active, querySelector: selector => selector === '#recent-meme-list' ? list : clear };
  try {
    const nav = navigation();
    nav.recentMemes = [];
    nav.renderRecentMemes();
    assert.equal(focused, true);
  } finally { globalThis.document = original; }
});

test('source dimensions reserve image ratio without guessing missing metadata', () => {
  const nav = navigation();
  assert.match(nav.renderMemeHTML({ url: '/tall.jpg', width: 800, height: 1600 }), /width="800" height="1600"/);
  assert.equal(nav.mediaDimensionAttributes({ width: '1" onload="bad', height: 100 }), '');
  assert.equal(nav.mediaDimensionAttributes({ width: 0, height: 100 }), '');
  assert.equal(nav.mediaDimensionAttributes({}), '');
});

test('Save-Data prevents speculative requests but leaves explicit Next available', async () => {
  const original = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { connection: { saveData: true } } });
  const nav = navigation();
  let requests = 0;
  Object.assign(nav, {
    showLoadingState() {}, hideLoadingState() {}, trackSkip() {}, trackView() {},
    async fetchMeme() { requests++; return { url: '/requested.jpg' }; },
    async renderMeme() { return true; }
  });
  try {
    nav.prefetchNext();
    assert.equal(requests, 0);
    await nav.loadNextMeme();
    assert.equal(requests, 1);
    assert.equal(nav.currentMeme.url, '/requested.jpg');
  } finally {
    if (original) Object.defineProperty(globalThis, 'navigator', original);
    else delete globalThis.navigator;
  }
});

test('missing connection API does not disable normal prefetch behavior', () => {
  const original = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: {} });
  try { assert.equal(navigation().dataSavingEnabled(), false); }
  finally {
    if (original) Object.defineProperty(globalThis, 'navigator', original);
    else delete globalThis.navigator;
  }
});

test('stale prefetched flags cannot override confirmed page-session interactions', async () => {
  const nav = navigation();
  const stale = { url: '/favorite.jpg', liked: false, saved: false, likes: 3, impression_id: 'new-selection' };
  nav.prefetchedMeme = stale;
  nav.interactionStates = new Map([['/favorite.jpg', { liked: true, saved: true, likes: 4 }]]);
  Object.assign(nav, {
    showLoadingState() {}, hideLoadingState() {}, trackSkip() {}, trackView() {}, prefetchNext() {},
    async renderMeme(meme) {
      assert.equal(meme.liked, true);
      assert.equal(meme.saved, true);
      assert.equal(meme.likes, 4);
      assert.equal(meme.impression_id, 'new-selection');
      return true;
    }
  });
  await nav.loadNextMeme();
  assert.equal(nav.currentMeme.saved, true);
  assert.equal(stale.saved, false);
});

test('server engagement state is retained when there is no confirmed local override', () => {
  const nav = navigation();
  const server = { url: '/server.jpg', liked: true, saved: true, likes: 9 };
  assert.deepEqual(nav.withConfirmedInteractions(server), server);
  nav.interactionStates = new Map([['/other.jpg', { liked: false }]]);
  assert.deepEqual(nav.withConfirmedInteractions(server), server);
});

test('reduced-motion rendering swaps immediately without animation classes or delay', async () => {
  const saved = { window: globalThis.window, document: globalThis.document };
  const added = [];
  const display = { dataset: {}, classList: { remove() {}, add: value => added.push(value) } };
  globalThis.window = { matchMedia: () => ({ matches: true }) };
  globalThis.document = { querySelector: selector => selector === '#meme-display' ? display : null, getElementById: () => null };
  const nav = navigation();
  nav.navigationVersion = 1;
  Object.assign(nav, {
    wait() { assert.fail('reduced motion must not wait for animation'); },
    renderMemeHTML: () => 'new media', restoreVideoPosition() {}, observeImpression() {},
    updateControlsState() {}, restoreScrollPosition() {}
  });
  try {
    assert.equal(await nav.renderMeme({ url: '/new.jpg' }, false, 1), true);
    assert.equal(display.innerHTML, 'new media');
    assert.deepEqual(added, []);
  } finally { Object.assign(globalThis, saved); }
});

test('successful retry returns focus only when the removed notice owns focus', () => {
  const original = globalThis.document;
  const handlers = {};
  let focused = 0;
  let removed = 0;
  const retry = {};
  const notice = { contains: target => target === retry, remove: () => { removed++; } };
  const media = { matches: () => true, dataset: { mediaFailed: 'true' }, parentElement: { querySelector: () => notice } };
  const display = { querySelectorAll: () => [], addEventListener: (name, handler) => { handlers[name] = handler; }, setAttribute() {}, focus: options => { assert.equal(options.preventScroll, true); focused++; } };
  globalThis.document = { querySelector: () => display, activeElement: retry };
  try {
    navigation().bindMediaRecovery();
    handlers.load({ target: media });
    assert.equal(focused, 1);
    assert.equal(removed, 1);
    document.activeElement = {};
    handlers.load({ target: media });
    assert.equal(focused, 1);
  } finally { globalThis.document = original; }
});

test('AJAX media offers delegated recovery rather than silent placeholder substitution', () => {
  const nav = navigation();
  const image = nav.renderMemeHTML({ url: '/one.jpg' });
  const video = nav.renderMemeHTML({ url: '/video.mp4', media_type: 'video' });
  assert.ok(image.includes('data-recoverable-media'));
  assert.ok(video.includes('data-recoverable-media'));
  assert.ok(!image.includes('onerror='));
});

test('recovery actions retry original media or explicitly request another meme', () => {
  const original = globalThis.document;
  const handlers = {};
  let next = 0;
  const media = { tagName: 'IMG', src: '', getAttribute: () => '/original.jpg' };
  const message = {};
  const notice = { querySelector: () => message, parentElement: { querySelector: () => media } };
  const button = { dataset: { mediaAction: 'retry' }, closest: () => notice };
  const display = { querySelectorAll: () => [], contains: () => true, addEventListener: (name, handler) => { handlers[name] = handler; } };
  globalThis.document = { querySelector: () => display };
  const nav = navigation();
  nav.loadNextMeme = () => { next++; };
  try {
    nav.bindMediaRecovery();
    const event = { target: { closest: () => button } };
    handlers.click(event);
    assert.equal(media.src, '/original.jpg');
    assert.equal(message.textContent, 'Retrying media…');
    button.dataset.mediaAction = 'next';
    handlers.click(event);
    assert.equal(next, 1);
    nav.loading = true;
    handlers.click(event);
    assert.equal(next, 1);
  } finally { globalThis.document = original; }
});

test('media failure creates one recovery notice and successful load clears it', () => {
  const original = globalThis.document;
  const handlers = {};
  let notice;
  let removed = false;
  const message = {};
  const display = { querySelectorAll: () => [], addEventListener: (name, handler) => { handlers[name] = handler; } };
  const parent = { querySelector: () => notice };
  const media = { matches: () => true, dataset: {}, parentElement: parent, after: value => { notice = value; } };
  globalThis.document = {
    querySelector: () => display,
    createElement: () => ({ dataset: {}, setAttribute() {}, querySelector: () => message, remove() { removed = true; notice = null; } })
  };
  try {
    navigation().bindMediaRecovery();
    handlers.error({ target: media });
    const first = notice;
    handlers.error({ target: media });
    assert.equal(notice, first);
    assert.equal(message.textContent, 'Still not loading. Try again or choose another meme.');
    assert.equal(media.dataset.mediaFailed, 'true');
    assert.ok(notice.innerHTML.includes('Try again'));
    handlers.load({ target: media });
    assert.equal(removed, true);
    assert.equal(media.dataset.mediaFailed, undefined);
  } finally { globalThis.document = original; }
});

test('initial images that failed before bundle initialization receive recovery actions', () => {
  const original = globalThis.document;
  let notice;
  const media = { tagName: 'IMG', complete: true, naturalWidth: 0, dataset: {}, matches: () => true,
    parentElement: { querySelector: () => notice }, after: value => { notice = value; } };
  const display = { querySelectorAll: () => [media], addEventListener() {} };
  globalThis.document = { querySelector: () => display, createElement: () => ({ dataset: {}, setAttribute() {} }) };
  try {
    navigation().bindMediaRecovery();
    assert.equal(media.dataset.mediaFailed, 'true');
    assert.ok(notice.innerHTML.includes('Try again'));
  } finally { globalThis.document = original; }
});

test('recently viewed is bounded and deduplicated without storing prefetch implicitly', () => {
  const nav = navigation();
  nav.renderRecentMemes = () => {};
  nav.prefetchedMeme = { url: '/unseen.jpg' };
  for (let index = 0; index < 25; index++) nav.rememberRecentMeme({ url: `/meme-${index}.jpg`, title: `Meme ${index}` });
  assert.equal(nav.recentMemes.length, 20);
  assert.ok(!nav.recentMemes.some(meme => meme.url === '/unseen.jpg'));
  nav.rememberRecentMeme({ url: '/meme-20.jpg', title: 'Revisited' });
  assert.equal(nav.recentMemes.length, 20);
  assert.equal(nav.recentMemes[0].title, 'Revisited');
});

test('recent meme reopening preserves impression identity and latest interaction state', async () => {
  const nav = navigation();
  nav.recentMemes = [{ url: '/recent.jpg', impression_id: 'original-id', title: 'Recent' }];
  nav.interactionStates = new Map([['/recent.jpg', { saved: true }]]);
  nav.showLoadingState = () => {};
  nav.hideLoadingState = () => {};
  nav.renderMeme = async (meme, push, _version, recoverPosition) => {
    assert.equal(meme.impression_id, 'original-id');
    assert.equal(meme.saved, true);
    assert.equal(push, true);
    assert.equal(recoverPosition, true);
    return true;
  };
  await nav.openRecentMeme(0);
  assert.equal(nav.currentMeme.url, '/recent.jpg');
  assert.equal(nav.loading, false);
});

test('recent recovery state updates existing viewed items without adding cleared or unseen items', () => {
  const nav = navigation();
  nav.recentMemes = [{ url: '/viewed.jpg', impression_id: 'original', title: 'Viewed' }];
  nav.updateRecentState('/viewed.jpg', { gallery_index: 2, video_time: 12, scroll_y: 640, saved: true });
  assert.equal(nav.recentMemes[0].gallery_index, 2);
  assert.equal(nav.recentMemes[0].video_time, 12);
  assert.equal(nav.recentMemes[0].scroll_y, 640);
  assert.equal(nav.recentMemes[0].impression_id, 'original');
  nav.updateRecentState('/prefetched.jpg', { scroll_y: 10 });
  assert.equal(nav.recentMemes.length, 1);
  nav.recentMemes = [];
  nav.updateRecentState('/viewed.jpg', { saved: false });
  assert.equal(nav.recentMemes.length, 0);
});

test('recent tray escapes stored titles and supports clearing', () => {
  const original = globalThis.document;
  const list = {};
  let clear;
  globalThis.document = { querySelector: selector => selector === '#recent-meme-list' ? { ...list, addEventListener() {} } : { addEventListener: (_name, callback) => { clear = callback; } } };
  const nav = navigation();
  nav.recentMemes = [{ url: '/one.jpg', title: '<script>bad</script>' }];
  const rendered = {};
  try {
    nav.bindRecentMemes();
    globalThis.document.querySelector = () => rendered;
    nav.renderRecentMemes();
    assert.ok(rendered.innerHTML.includes('&lt;script&gt;'));
    assert.ok(!rendered.innerHTML.includes('<script>'));
    clear();
    assert.equal(nav.recentMemes.length, 0);
    assert.ok(rendered.innerHTML.includes('No viewed memes yet'));
  } finally { globalThis.document = original; }
});

test('delayed layout retries saved offset and disconnects once reached', () => {
  const saved = { window: globalThis.window, ResizeObserver: globalThis.ResizeObserver };
  const events = {};
  const mediaEvents = {};
  let resize;
  let maximum = 100;
  let disconnected = false;
  globalThis.window = {
    scrollY: 0,
    scrollTo({ top }) { this.scrollY = Math.min(top, maximum); },
    addEventListener: (name, handler) => { events[name] = handler; },
    removeEventListener: name => { delete events[name]; }
  };
  globalThis.ResizeObserver = class {
    constructor(callback) { resize = callback; }
    observe() {}
    disconnect() { disconnected = true; }
  };
  const display = { isConnected: true, addEventListener: (name, handler) => { mediaEvents[name] = handler; }, removeEventListener: name => { delete mediaEvents[name]; } };
  const nav = navigation();
  nav.navigationVersion = 1;
  try {
    nav.restoreScrollPosition({ scroll_y: 800 }, false, 1, display);
    assert.equal(window.scrollY, 100);
    maximum = 1000;
    resize();
    assert.equal(window.scrollY, 800);
    assert.equal(disconnected, true);
    assert.equal(Object.keys(events).length, 0);
    assert.equal(Object.keys(mediaEvents).length, 0);
  } finally { nav.stopScrollRestoration?.(); Object.assign(globalThis, saved); }
});

test('user input cancels delayed restoration instead of pulling the reader back', () => {
  const saved = { window: globalThis.window };
  const events = {};
  let load;
  let scrolls = 0;
  globalThis.window = { scrollY: 0, scrollTo() { scrolls++; }, addEventListener: (name, handler) => { events[name] = handler; }, removeEventListener() {} };
  const display = { isConnected: true, addEventListener: (name, handler) => { if (name === 'load') load = handler; }, removeEventListener() {} };
  const nav = navigation();
  nav.navigationVersion = 1;
  try {
    nav.restoreScrollPosition({ scroll_y: 800 }, false, 1, display);
    events.wheel();
    const before = scrolls;
    load();
    assert.equal(scrolls, before);
  } finally { nav.stopScrollRestoration?.(); Object.assign(globalThis, saved); }
});

test('history restores reading offset while fresh selections start at top', () => {
  const original = globalThis.window;
  const calls = [];
  globalThis.window = { scrollTo: options => calls.push(options) };
  const nav = navigation();
  nav.navigationVersion = 2;
  try {
    nav.restoreScrollPosition({ scroll_y: 850 }, false, 2);
    nav.restoreScrollPosition({ scroll_y: 850 }, true, 2);
    nav.restoreScrollPosition({ scroll_y: -50 }, false, 2);
    nav.restoreScrollPosition({ scroll_y: 900 }, false, 1);
    assert.deepEqual(calls.map(value => value.top), [850, 0, 0]);
    assert.ok(calls.every(value => value.behavior === 'instant'));
  } finally { globalThis.window = original; }
});

test('scroll capture coalesces updates and preserves history identity', () => {
  const saved = { window: globalThis.window, history: globalThis.history, requestAnimationFrame: globalThis.requestAnimationFrame };
  const handlers = {};
  let frame;
  let state;
  globalThis.window = { scrollY: 600, location: { href: 'https://memes.example/random' }, addEventListener: (name, callback) => { handlers[name] = callback; } };
  globalThis.history = { scrollRestoration: 'auto', state: { memePosition: 2 }, replaceState: value => { state = value; } };
  globalThis.requestAnimationFrame = callback => { frame = callback; };
  const nav = navigation();
  nav.navigationVersion = 1;
  nav.currentMeme = { url: '/tall.jpg', impression_id: 'same' };
  try {
    nav.bindScrollRecovery();
    assert.equal(history.scrollRestoration, 'manual');
    handlers.scroll();
    handlers.scroll();
    frame();
    assert.equal(state.meme.scroll_y, 600);
    assert.equal(state.meme.impression_id, 'same');
    assert.equal(state.memePosition, 2);
    handlers.scroll();
    nav.beginNavigation();
    window.scrollY = 999;
    frame();
    assert.equal(state.meme.scroll_y, 600);
    handlers.pagehide();
    assert.equal(history.scrollRestoration, 'auto');
  } finally { Object.assign(globalThis, saved); }
});

test('video recovery clamps saved time without starting playback', () => {
  const nav = navigation();
  nav.navigationVersion = 3;
  const video = { readyState: 1, duration: 10, currentTime: 0, play() { assert.fail('must not autoplay recovery'); } };
  const display = { querySelector: () => video, contains: () => true };
  nav.restoreVideoPosition({ video_time: 50 }, display, 3);
  assert.equal(video.currentTime, 9.9);
  nav.restoreVideoPosition({ video_time: -5 }, display, 3);
  assert.equal(video.currentTime, 9.9);
});

test('late video metadata cannot seek superseded content', () => {
  const nav = navigation();
  nav.navigationVersion = 1;
  let metadata;
  const video = { readyState: 0, duration: 100, currentTime: 0, addEventListener: (_name, callback) => { metadata = callback; } };
  nav.restoreVideoPosition({ video_time: 20 }, { querySelector: () => video, contains: () => true }, 1);
  nav.navigationVersion = 2;
  metadata();
  assert.equal(video.currentTime, 0);
});

test('video seek stores position in the existing history entry', () => {
  const saved = { document: globalThis.document, history: globalThis.history, window: globalThis.window };
  const handlers = {};
  let state;
  globalThis.document = { querySelector: () => ({ addEventListener: (name, handler) => { handlers[name] = handler; } }) };
  globalThis.history = { state: { memePosition: 2 }, replaceState: value => { state = value; } };
  globalThis.window = { location: { href: 'https://memes.example/random' } };
  const nav = navigation();
  nav.currentMeme = { url: '/video.mp4', impression_id: 'same' };
  try {
    nav.bindVideoRecovery();
    handlers.seeked({ type: 'seeked', target: { tagName: 'VIDEO', currentTime: 12 } });
    assert.equal(state.meme.video_time, 12);
    assert.equal(state.meme.impression_id, 'same');
    assert.equal(state.memePosition, 2);
  } finally { Object.assign(globalThis, saved); }
});

test('gallery position replaces history while retaining impression and interaction state', () => {
  const saved = { history: globalThis.history, window: globalThis.window, document: globalThis.document };
  let observed = 0;
  globalThis.document = { querySelector: () => ({}) };
  let state;
  globalThis.history = { state: { memePosition: 3 }, replaceState: value => { state = value; } };
  globalThis.window = { location: { href: 'https://memes.example/random' } };
  const nav = navigation();
  nav.observeImpression = meme => { assert.equal(meme.gallery_index, 2); observed++; };
  nav.currentMeme = { url: '/gallery.jpg', is_gallery: true, impression_id: 'same', saved: true };
  try {
    nav.rememberGalleryPosition(2);
    assert.equal(state.meme.gallery_index, 2);
    assert.equal(state.meme.impression_id, 'same');
    assert.equal(state.meme.saved, true);
    assert.equal(state.memePosition, 3);
    assert.equal(observed, 1);
    nav.loading = true;
    nav.rememberGalleryPosition(0);
    assert.equal(state.meme.gallery_index, 2);
  } finally { Object.assign(globalThis, saved); }
});

test('Previous never leaves the first meme and ignores requests while loading', () => {
  const original = globalThis.window;
  let backs = 0;
  globalThis.window = { history: { back: () => { backs++; } } };
  const nav = navigation();
  try {
    nav.historyPosition = 0;
    nav.loadPreviousMeme();
    assert.equal(backs, 0);
    nav.historyPosition = 1;
    nav.loading = true;
    nav.loadPreviousMeme();
    assert.equal(backs, 0);
    nav.loading = false;
    nav.loadPreviousMeme();
    assert.equal(backs, 1);
  } finally { globalThis.window = original; }
});

test('Previous availability reflects the current session history position', () => {
  const original = globalThis.document;
  const button = {};
  globalThis.document = { querySelector: () => button };
  const nav = navigation();
  try {
    nav.historyPosition = 0;
    nav.updatePreviousAvailability();
    assert.equal(button.disabled, true);
    nav.historyPosition = 2;
    nav.updatePreviousAvailability();
    assert.equal(button.disabled, false);
    nav.loading = true;
    nav.updatePreviousAvailability();
    assert.equal(button.disabled, true);
  } finally { globalThis.document = original; }
});

test('gallery arrow keys change a slide instead of navigating the meme', () => {
  const original = globalThis.document;
  let clicks = 0;
  let prevented = 0;
  globalThis.document = { body: { classList: { contains: () => false } }, querySelector: () => ({ querySelector: () => ({ click: () => { clicks++; } }) }) };
  const nav = navigation();
  nav.isInputFocused = () => false;
  nav.loadNextMeme = () => assert.fail('gallery arrow skipped meme');
  try {
    nav.handleKeyPress({ code: 'ArrowRight', preventDefault: () => { prevented++; } });
    nav.handleKeyPress({ code: 'ArrowLeft', preventDefault: () => { prevented++; } });
    assert.equal(clicks, 2);
    assert.equal(prevented, 2);
  } finally { globalThis.document = original; }
});

test('AJAX gallery swipe owns horizontal gestures and ignores vertical scrolling', () => {
  const original = globalThis.document;
  const handlers = {};
  globalThis.document = { querySelector: () => ({ addEventListener: (name, callback) => { handlers[name] = callback; } }) };
  const nav = navigation();
  let next = 0;
  nav.nextGalleryImage = () => { next++; };
  try {
    nav.bindGalleryControls();
    const target = { closest: selector => selector === '.meme-gallery' ? {} : null };
    handlers.touchstart({ target, touches: [{ clientX: 100, clientY: 0 }] });
    handlers.touchend({ changedTouches: [{ clientX: 20, clientY: 10 }] });
    assert.equal(next, 1);
    handlers.touchstart({ target, touches: [{ clientX: 100, clientY: 0 }] });
    handlers.touchend({ changedTouches: [{ clientX: 20, clientY: 150 }] });
    assert.equal(next, 1);
  } finally { globalThis.document = original; }
});

test('AJAX gallery has accessible delegated controls without debug globals', () => {
  const html = navigation().renderGalleryHTML(['/images/one.jpg', '/images/two.jpg'], 'Gallery');
  assert.ok(!html.includes('window.memeApp'));
  assert.ok(!html.includes('onclick='));
  assert.match(html, /data-gallery-action="next"/);
  assert.match(html, /aria-label="Previous gallery image"/);
  assert.match(html, /gallery-slide active/);
  assert.match(html, /data-index="1" hidden/);
});

test('gallery clicks delegate through the persistent display in production', () => {
  const original = globalThis.document;
  let click;
  let next = 0;
  let previous = 0;
  const button = { dataset: { galleryAction: 'next' } };
  const display = { addEventListener: (event, handler) => { if (event === 'click') click = handler; }, contains: value => value === button };
  globalThis.document = { querySelector: () => display };
  const nav = navigation();
  nav.nextGalleryImage = () => { next++; };
  nav.prevGalleryImage = () => { previous++; };
  try {
    nav.bindGalleryControls();
    const event = { target: { closest: () => button }, preventDefault() {} };
    click(event);
    button.dataset.galleryAction = 'previous';
    click(event);
    assert.equal(next, 1);
    assert.equal(previous, 1);
  } finally { globalThis.document = original; }
});

test('gallery slide changes hide inactive media and update its scoped counter', () => {
  const original = globalThis.document;
  const slides = [0, 1].map(() => ({ classList: { toggle() {} }, hidden: false, style: {} }));
  const container = { querySelectorAll: () => slides };
  const counter = {};
  globalThis.document = { querySelector: selector => selector.endsWith('.gallery-container') ? container : counter };
  try {
    navigation().showGallerySlide(1);
    assert.equal(slides[0].hidden, true);
    assert.equal(slides[1].hidden, false);
    assert.equal(counter.textContent, '2 / 2');
    navigation().showGallerySlide(99, false);
    assert.equal(counter.textContent, '2 / 2');
    navigation().showGallerySlide(-1, false);
    assert.equal(counter.textContent, '1 / 2');
    assert.equal(slides[0].hidden, false);
  } finally { globalThis.document = original; }
});

test('confirmed interactions update the current history entry, not a different meme', () => {
  const saved = { history: globalThis.history, window: globalThis.window };
  let replaced;
  globalThis.history = { state: { existing: true }, replaceState: state => { replaced = state; } };
  globalThis.window = { location: { href: 'https://memes.example/random' } };
  try {
    const nav = navigation();
    nav.currentMeme = { url: '/one.jpg', impression_id: 'same-id' };
    nav.rememberInteraction({ url: '/one.jpg', liked: true, likes: 12, saved: true });
    assert.equal(replaced.meme.liked, true);
    assert.equal(replaced.meme.saved, true);
    assert.equal(replaced.meme.impression_id, 'same-id');
    assert.equal(replaced.existing, true);
    const previous = replaced;
    nav.rememberInteraction({ url: '/other.jpg', saved: true });
    assert.equal(replaced, previous);
    assert.equal(nav.interactionStates.get('/other.jpg').saved, true);
  } finally { Object.assign(globalThis, saved); }
});

test('initial history replaces the current entry and initializes meme identity', () => {
  const saved = { document: globalThis.document, history: globalThis.history, window: globalThis.window };
  const meme = { url: '/initial.jpg', title: 'Initial', impression_id: 'existing-id' };
  let replacement;
  globalThis.document = { querySelector: () => ({ dataset: { meme: JSON.stringify(meme) } }) };
  globalThis.window = { location: { href: 'https://memes.example/' } };
  globalThis.history = { state: { existing: true }, replaceState: (...args) => { replacement = args; }, pushState: () => assert.fail('must not add an entry') };
  try {
    const nav = navigation();
    nav.seedInitialHistory();
    assert.deepEqual(nav.currentMeme, meme);
    assert.equal(replacement[0].existing, true);
    assert.deepEqual(replacement[0].meme, meme);
    assert.equal(replacement[2], 'https://memes.example/');
  } finally {
    Object.assign(globalThis, saved);
  }
});

test('rendering Next and restored memes updates or clears exact share identity', async () => {
  const saved = { document: globalThis.document, window: globalThis.window };
  const display = { dataset: {}, classList: { add() {}, remove() {} } };
  const share = { dataset: { sharePath: `/meme/${'a'.repeat(64)}` } };
  globalThis.window = { matchMedia: () => ({ matches: true }) };
  globalThis.document = {
    querySelector: selector => selector === '#meme-display' ? display : selector === '#viewer-share-data' ? share : null,
    getElementById: () => null
  };
  const nav = navigation();
  Object.assign(nav, {
    navigationVersion: 1, withConfirmedInteractions: meme => meme,
    renderMemeHTML: meme => meme.url, restoreVideoPosition() {}, observeImpression() {},
    updateControlsState() {}, restoreScrollPosition() {}, announceMeme() {}, updateURL() {}
  });
  try {
    const next = { url: '/next.jpg', share_path: `/meme/${'b'.repeat(64)}` };
    assert.equal(await nav.renderMeme(next, true, 1), true);
    assert.equal(share.dataset.sharePath, next.share_path);
    const restored = { url: '/initial.jpg', share_path: `/meme/${'a'.repeat(64)}` };
    assert.equal(await nav.renderMeme(restored, false, 1), true);
    assert.equal(share.dataset.sharePath, restored.share_path);
    await nav.renderMeme({ url: '/unregistered.jpg' }, true, 1);
    assert.equal(share.dataset.sharePath, '');
    assert.equal(display.dataset.memeUrl, '/unregistered.jpg');
  } finally { Object.assign(globalThis, saved); }
});

test('popstate restores current identity and title without adding history', async () => {
  const saved = { window: globalThis.window, document: globalThis.document };
  let handler;
  const meme = { url: '/previous.jpg', title: 'Previous', impression_id: 'same-id', share_path: `/meme/${'a'.repeat(64)}` };
  globalThis.window = { addEventListener: (_event, callback) => { handler = callback; } };
  globalThis.document = { title: '' };
  const nav = navigation();
  nav.renderMeme = async (value, push) => { assert.deepEqual(value, meme); assert.equal(push, false); };
  nav.hideLoadingState = () => {};
  try {
    nav.setupPopStateHandler();
    await handler({ state: { meme, memePosition: 2 } });
    assert.deepEqual(nav.currentMeme, meme);
    assert.equal(nav.historyPosition, 2);
    assert.equal(globalThis.document.title, 'Previous - Meme Explorer');
    assert.ok(nav.currentMemeShownAt > 0);
  } finally { Object.assign(globalThis, saved); }
});

test('successful Next history entry advances the bounded Previous position', () => {
  const saved = { history: globalThis.history, document: globalThis.document };
  let state;
  globalThis.history = { pushState: value => { state = value; } };
  globalThis.document = { title: '' };
  const nav = navigation();
  nav.historyPosition = 0;
  try {
    nav.updateURL({ url: '/next.jpg', title: 'Next', share_path: `/meme/${'b'.repeat(64)}` });
    assert.equal(state.memePosition, 1);
    assert.equal(nav.historyPosition, 1);
    assert.equal(state.meme.url, '/next.jpg');
    assert.equal(state.meme.share_path, `/meme/${'b'.repeat(64)}`);
  } finally { Object.assign(globalThis, saved); }
});

test('Back supersedes a pending Next response without stale rendering or cleanup', async () => {
  const saved = { window: globalThis.window, document: globalThis.document };
  let popstate;
  let finishFetch;
  let cleanups = 0;
  const renders = [];
  const previous = { url: '/previous.jpg', title: 'Previous' };
  globalThis.window = { addEventListener: (_name, callback) => { popstate = callback; } };
  globalThis.document = { title: '' };
  const nav = navigation();
  Object.assign(nav, {
    loading: false, currentMeme: { url: '/current.jpg' },
    showLoadingState() {}, hideLoadingState() { cleanups++; },
    fetchMeme: () => new Promise(resolve => { finishFetch = resolve; }),
    async renderMeme(meme, push) { renders.push({ url: meme.url, push }); return true; },
    trackSkip() { assert.fail('stale operation must not record a skip'); },
    trackView() { assert.fail('stale operation must not record analytics'); },
    prefetchNext() { assert.fail('stale operation must not replenish'); }
  });
  try {
    nav.setupPopStateHandler();
    const next = nav.loadNextMeme();
    await popstate({ state: { meme: previous } });
    finishFetch({ url: '/stale-next.jpg' });
    await next;
    assert.deepEqual(renders, [{ url: '/previous.jpg', push: false }]);
    assert.equal(nav.currentMeme.url, '/previous.jpg');
    assert.equal(cleanups, 1);
    assert.equal(nav.loading, false);
  } finally { Object.assign(globalThis, saved); }
});

test('a superseded transition cannot replace content or observe an impression', async () => {
  const originalDocument = globalThis.document;
  const display = { innerHTML: 'current media', classList: { add() {}, remove() {} }, offsetWidth: 1 };
  globalThis.document = { querySelector: selector => selector === '#meme-display' ? display : null };
  let finishTransition;
  const nav = navigation();
  nav.navigationVersion = 1;
  nav.wait = () => new Promise(resolve => { finishTransition = resolve; });
  nav.observeImpression = () => assert.fail('stale impression observer');
  try {
    const render = nav.renderMeme({ url: '/stale.jpg' }, true, 1);
    nav.beginNavigation();
    finishTransition();
    assert.equal(await render, false);
    assert.equal(display.innerHTML, 'current media');
  } finally { globalThis.document = originalDocument; }
});

test('initial server-rendered media starts observation before speculative prefetch', () => {
  const originalDocument = globalThis.document;
  const display = { dataset: { impressionId: 'initial-id' } };
  const events = [];
  globalThis.document = { querySelector: () => display, addEventListener() {} };
  const nav = navigation();
  Object.assign(nav, {
    bindKeyboardShortcuts() {}, bindNavigationButtons() {}, bindGalleryControls() {}, setupPopStateHandler() {}, seedInitialHistory() {}, bindVideoRecovery() {}, bindScrollRecovery() {}, bindRecentMemes() {}, bindMediaRecovery() {}, bindTitleToggle() {},
    observeImpression(meme, element) { assert.equal(meme.impression_id, 'initial-id'); assert.equal(element, display); events.push('observe'); },
    prefetchNext() { events.push('prefetch'); }
  });
  try {
    nav.init();
    assert.deepEqual(events, ['observe', 'prefetch']);
  } finally { globalThis.document = originalDocument; }
});

test('impression observation does nothing for speculative or unsupported content', () => {
  const nav = navigation();
  let stopped = 0;
  nav.stopImpressionObserver = () => { stopped++; };
  nav.observeImpression({ url: '/prefetched.jpg' }, {});
  assert.equal(stopped, 1);
});

test('visible usable media acknowledges once after dwell and cleans up observation', async () => {
  const originals = Object.fromEntries(['IntersectionObserver', 'document', 'fetch', 'setTimeout', 'clearTimeout'].map(key => [key, globalThis[key]]));
  let intersection;
  let dwell;
  let disconnected = false;
  let requests = 0;
  const media = { tagName: 'IMG', complete: true, naturalWidth: 100, addEventListener() {}, removeEventListener() {} };
  globalThis.document = { visibilityState: 'visible', addEventListener() {}, removeEventListener() {} };
  globalThis.IntersectionObserver = class {
    constructor(callback) { intersection = callback; }
    observe() {}
    disconnect() { disconnected = true; }
  };
  globalThis.setTimeout = (callback, delay) => { assert.equal(delay, 1000); dwell = callback; return 1; };
  globalThis.clearTimeout = () => {};
  globalThis.fetch = async (url, options) => {
    assert.equal(url, '/api/impressions');
    assert.equal(JSON.parse(options.body).impression_id, 'issued-id');
    requests++;
    return { ok: true };
  };
  try {
    const nav = navigation();
    // Observer test isolates dwell scheduling from delivery's own deadline.
    nav.acknowledgeImpression = id => globalThis.fetch('/api/impressions', { body: JSON.stringify({ impression_id: id }) });
    nav.observeImpression({ impression_id: 'issued-id' }, { querySelector: () => media });
    assert.equal(requests, 0);
    intersection([{ isIntersecting: true, rootBounds: { width: 100, height: 100 }, boundingClientRect: { width: 100, height: 100 }, intersectionRect: { width: 100, height: 100 } }]);
    assert.equal(requests, 0);
    dwell();
    assert.equal(requests, 1);
    assert.equal(disconnected, true);
  } finally {
    for (const [key, value] of Object.entries(originals)) {
      if (value === undefined) delete globalThis[key]; else globalThis[key] = value;
    }
  }
});

test('impression retries transient failures with the same ID and bounded backoff', async () => {
  const originalFetch = globalThis.fetch;
  const nav = navigation();
  const waits = [];
  const ids = [];
  nav.wait = async delay => { waits.push(delay); };
  globalThis.fetch = async (_url, options) => {
    ids.push(JSON.parse(options.body).impression_id);
    if (ids.length === 1) throw new Error('connection lost');
    return ids.length === 2 ? { ok: false, status: 503 } : { ok: true };
  };
  try {
    assert.equal(await nav.acknowledgeImpression('same-id'), true);
    assert.deepEqual(ids, ['same-id', 'same-id', 'same-id']);
    assert.deepEqual(waits, [500, 1000]);
  } finally { globalThis.fetch = originalFetch; }
});

test('impression does not retry rejected IDs and stops after three server failures', async () => {
  const originalFetch = globalThis.fetch;
  const nav = navigation();
  nav.wait = async () => {};
  let calls = 0;
  globalThis.fetch = async () => { calls++; return { ok: false, status: 404 }; };
  try {
    assert.equal(await nav.acknowledgeImpression('expired'), false);
    assert.equal(calls, 1);
    calls = 0;
    globalThis.fetch = async () => { calls++; return { ok: false, status: 503 }; };
    assert.equal(await nav.acknowledgeImpression('issued'), false);
    assert.equal(calls, 3);
  } finally { globalThis.fetch = originalFetch; }
});

test('media URL policy rejects executable schemes and protocol-relative sources', () => {
  for (const value of ['javascript:alert(1)', 'data:image/svg+xml,bad', '//external.example/a', '/\\external/a', 'https://user:pass@example.com/a']) {
    assert.equal(navigation().safeMediaUrl(value), '/images/meme-placeholder.svg');
  }
  assert.equal(navigation().safeMediaUrl('https://i.redd.it/a.jpg'), 'https://i.redd.it/a.jpg');
  assert.equal(navigation().safeMediaUrl('/images/a.jpg'), '/images/a.jpg');
});

test('escaping protects text and double/single quoted HTML attributes', () => {
  assert.equal(navigation().escapeHtml('" onload="alert(1)<>&\''), '&quot; onload=&quot;alert(1)&lt;&gt;&amp;&#39;');
  assert.equal(navigation().escapeHtml(null), '');
});

test('AJAX image keeps the interaction ID and escapes malicious metadata', () => {
  const html = navigation().renderMemeHTML({ url: '/image.jpg" onload="alert(1)', title: '<script>bad</script>' });
  assert.match(html, /id="meme-image"/);
  assert.ok(!html.includes('src="/image.jpg" onload='));
  assert.ok(!html.includes('<script>'));
});

test('AJAX video is muted and does not force autoplay', () => {
  const html = navigation().renderMemeHTML({ media_type: 'video', url: 'https://v.redd.it/video' });
  assert.match(html, /muted/);
  assert.ok(!html.includes('autoplay'));
});

test('selection metadata cannot inject markup', () => {
  const html = navigation().renderInfoHTML({ diversity_pool: '<img onerror=alert(1)>', total_unseen: '<script>bad</script>' });
  assert.ok(!html.includes('<img'));
  assert.ok(!html.includes('<script>'));
});

test('next loads one meme and delegates history updates only to rendering', async () => {
  const nav = navigation();
  Object.assign(nav, { loading: false, prefetchedMeme: { url: '/one.jpg' }, trackSkip() {}, showLoadingState() {}, hideLoadingState() {}, prefetchNext() {}, trackView() {} });
  let renders = 0;
  nav.renderMeme = async () => { renders++; };
  nav.updateURL = () => { throw new Error('duplicate history entry'); };
  await nav.loadNextMeme();
  assert.equal(renders, 1);
  assert.equal(nav.currentMeme.url, '/one.jpg');
  assert.equal(nav.loading, false);
});

test('browser shortcuts are never intercepted', () => {
  const nav = navigation();
  nav.isInputFocused = () => false;
  nav.loadNextMeme = () => assert.fail('intercepted browser shortcut');
  nav.handleKeyPress({ ctrlKey: true, code: 'Space' });
  nav.handleKeyPress({ metaKey: true, code: 'KeyS' });
});

test('navigation awaits in-flight prefetch and replenishes only after unlocking controls', async () => {
  const nav = navigation();
  let complete;
  let skips = 0;
  let replenished = false;
  Object.assign(nav, {
    loading: false, currentMeme: { url: '/old.jpg' }, currentMemeShownAt: 1,
    prefetchPromise: new Promise(resolve => { complete = resolve; }),
    showLoadingState() {}, hideLoadingState() {}, trackView() {},
    trackSkip(meme) { assert.equal(meme.url, '/old.jpg'); skips++; },
    async renderMeme(meme) { assert.equal(meme.url, '/prefetched.jpg'); },
    fetchMeme() { assert.fail('duplicate selection request'); },
    prefetchNext() { assert.equal(this.loading, false); replenished = true; }
  });
  const result = nav.loadNextMeme();
  nav.prefetchedMeme = { url: '/prefetched.jpg' };
  complete();
  await result;
  assert.equal(skips, 0);
  assert.equal(replenished, true);
});

test('failed navigation preserves current state, unlocks, and does not report a skip', async () => {
  const nav = navigation();
  const current = { url: '/keep.jpg' };
  let errors = 0;
  Object.assign(nav, {
    loading: false, currentMeme: current, showLoadingState() {}, hideLoadingState() {},
    async fetchMeme() { throw new Error('offline'); },
    trackSkip() { assert.fail('failed navigation must not be a skip'); },
    showError() { errors++; }
  });
  await nav.loadNextMeme();
  assert.equal(nav.currentMeme, current);
  assert.equal(nav.loading, false);
  assert.equal(errors, 1);
});

test('prefetch calls are single-flight and release their promise after failure', async () => {
  const nav = navigation();
  let reject;
  let calls = 0;
  nav.fetchMeme = () => { calls++; return new Promise((_, fail) => { reject = fail; }); };
  const first = nav.prefetchNext();
  assert.equal(nav.prefetchNext(), first);
  assert.equal(calls, 1);
  reject(new Error('offline'));
  await first;
  assert.equal(nav.prefetchPromise, null);
});

test('fetch rejects invalid API payloads and includes an abort signal', async () => {
  globalThis.fetch = async (_url, options) => {
    assert.ok(options.signal instanceof AbortSignal);
    return { ok: true, json: async () => ({ error: 'empty pool' }) };
  };
  try {
    await assert.rejects(navigation().fetchMeme('/random.json'), /Invalid meme response/);
  } finally {
    delete globalThis.fetch;
  }
});

test('fetch timeout aborts a stalled request and clears the timer', async () => {
  const originalSetTimeout = globalThis.setTimeout;
  const originalClearTimeout = globalThis.clearTimeout;
  const originalFetch = globalThis.fetch;
  let expire;
  let cleared = false;
  globalThis.setTimeout = (callback, delay) => { assert.equal(delay, 10000); expire = callback; return 123; };
  globalThis.clearTimeout = id => { assert.equal(id, 123); cleared = true; };
  globalThis.fetch = (_url, { signal }) => new Promise((_, reject) => {
    signal.addEventListener('abort', () => reject(new Error('aborted')));
  });
  try {
    const result = navigation().fetchMeme('/random.json');
    expire();
    await assert.rejects(result, /aborted/);
    assert.equal(cleared, true);
  } finally {
    globalThis.setTimeout = originalSetTimeout;
    globalThis.clearTimeout = originalClearTimeout;
    globalThis.fetch = originalFetch;
  }
});

test('like/save state resets the real rendered controls and counts', () => {
  const elements = {};
  for (const id of ['#like-btn', '#save-btn', '#like-count']) {
    elements[id] = { dataset: {}, classList: { remove() {}, toggle() {} }, setAttribute(key, value) { this[key] = value; } };
  }
  globalThis.document = { querySelector: selector => elements[selector] };
  navigation().updateControlsState({ url: '/new.jpg', likes: 42 });
  assert.equal(elements['#like-count'].textContent, 42);
  assert.equal(elements['#like-btn']['aria-pressed'], 'false');
  assert.equal(elements['#save-btn'].dataset.memeUrl, '/new.jpg');
  navigation().updateControlsState({ url: '/restored.jpg', liked: true, saved: true, likes: 7 });
  assert.equal(elements['#like-btn']['aria-pressed'], 'true');
  assert.equal(elements['#save-btn']['aria-pressed'], 'true');
  assert.equal(elements['#like-count'].textContent, 7);
  delete globalThis.document;
});