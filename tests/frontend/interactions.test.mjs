import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../public/js/modules/meme-interactions.js', import.meta.url), 'utf8');
const { MemeInteractions } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

test('share uses the displayed stable meme path rather than random page address', async () => {
  const original = { navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator'), window: globalThis.window, document: globalThis.document };
  let copied;
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { clipboard: { writeText: async value => { copied = value; } } } });
  globalThis.window = { location: { href: 'https://memes.example/random' } };
  globalThis.document = { title: 'Exact meme', querySelector: () => ({ dataset: { sharePath: `/meme/${'a'.repeat(64)}` } }) };
  const interactions = Object.create(MemeInteractions.prototype);
  interactions.triggerHaptic = () => {};
  interactions.showToast = () => {};
  try {
    await interactions.handleShare();
    assert.equal(copied, `https://memes.example/meme/${'a'.repeat(64)}`);
  } finally {
    if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
    globalThis.window = original.window;
    globalThis.document = original.document;
  }
});

test('native share uses displayed title and clean exact URL rather than stale page context', async () => {
  const original = { navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator'), window: globalThis.window, document: globalThis.document };
  let payload;
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { share: async value => { payload = value; } } });
  globalThis.window = { location: { href: `https://memes.example/meme/${'b'.repeat(64)}?search_q=private` } };
  globalThis.document = {
    title: 'Stale document title',
    querySelector: selector => selector === '#viewer-share-data'
      ? { dataset: { sharePath: `/meme/${'a'.repeat(64)}` } }
      : { textContent: '  Current <meme>  ' }
  };
  const interactions = Object.create(MemeInteractions.prototype);
  interactions.triggerHaptic = () => {};
  interactions.showToast = () => {};
  try {
    await interactions.handleShare();
    assert.deepEqual(payload, { title: 'Current <meme>', url: `https://memes.example/meme/${'a'.repeat(64)}` });
  } finally {
    if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
    globalThis.window = original.window;
    globalThis.document = original.document;
  }
});

test('late clipboard failure cannot reopen recovery or steal focus after navigation', async () => {
  const original = { navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator'), window: globalThis.window, document: globalThis.document };
  let rejectCopy;
  let current = `/meme/${'a'.repeat(64)}`;
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: {
    clipboard: { writeText: () => new Promise((_resolve, reject) => { rejectCopy = reject; }) }
  } });
  globalThis.window = { location: { href: 'https://memes.example/random' } };
  globalThis.document = { querySelector: selector => selector === '#viewer-share-data'
    ? { dataset: { sharePath: current } } : { textContent: 'Current meme' } };
  const interactions = Object.create(MemeInteractions.prototype);
  interactions.triggerHaptic = () => {};
  interactions.showToast = () => assert.fail('stale recovery feedback');
  interactions.showManualShare = () => assert.fail('stale recovery must not steal focus');
  try {
    const share = interactions.handleShare();
    current = `/meme/${'b'.repeat(64)}`;
    rejectCopy(new Error('denied'));
    await share;
    assert.equal(interactions.isSharing, false);
  } finally {
    if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
    globalThis.window = original.window;
    globalThis.document = original.document;
  }
});

test('manual share recovery reveals and selects the exact link without HTML insertion', () => {
  const original = globalThis.document;
  const panel = { hidden: true };
  const events = [];
  const input = { focus: () => events.push('focus'), select: () => events.push('select') };
  globalThis.document = { querySelector: selector => selector === '#manual-share' ? panel : input };
  try {
    const interactions = Object.create(MemeInteractions.prototype);
    interactions.showManualShare(`https://memes.example/meme/${'a'.repeat(64)}`);
    assert.equal(panel.hidden, false);
    assert.equal(input.value, `https://memes.example/meme/${'a'.repeat(64)}`);
    assert.deepEqual(events, ['focus', 'select']);
    assert.equal(input.innerHTML, undefined);
  } finally { globalThis.document = original; }
});

for (const outcome of ['success', 'fallback', 'cancel']) {
  test(`pending share snapshots content and blocks duplicate taps: ${outcome}`, async () => {
    const original = { navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator'), window: globalThis.window, document: globalThis.document };
    let settle;
    let calls = 0;
    let payload;
    let copied;
    let current = 'a';
    const pending = new Promise((resolve, reject) => { settle = { resolve, reject }; });
    Object.defineProperty(globalThis, 'navigator', { configurable: true, value: {
      share: value => { calls++; payload = value; return pending; },
      clipboard: { writeText: async value => { copied = value; } }
    } });
    globalThis.window = { location: { href: 'https://memes.example/random' } };
    globalThis.document = { querySelector: selector => selector === '#viewer-share-data'
      ? { dataset: { sharePath: `/meme/${current.repeat(64)}` } }
      : { textContent: `Meme ${current}` } };
    const interactions = Object.create(MemeInteractions.prototype);
    interactions.triggerHaptic = () => {};
    interactions.showToast = () => {};
    try {
      const first = interactions.handleShare();
      assert.equal(interactions.isSharing, true);
      current = 'b';
      await interactions.handleShare();
      assert.equal(calls, 1);
      assert.deepEqual(payload, { title: 'Meme a', url: `https://memes.example/meme/${'a'.repeat(64)}` });
      if (outcome === 'success') settle.resolve();
      else settle.reject(Object.assign(new Error('share failed'), { name: outcome === 'cancel' ? 'AbortError' : 'NotAllowedError' }));
      await first;
      assert.equal(interactions.isSharing, false);
      assert.equal(copied, outcome === 'fallback' ? payload.url : undefined);
      await interactions.handleShare();
      assert.equal(calls, 2);
      assert.equal(payload.title, 'Meme b');
      assert.equal(payload.url, `https://memes.example/meme/${'b'.repeat(64)}`);
    } finally {
      if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
      globalThis.window = original.window;
      globalThis.document = original.document;
    }
  });
}

for (const sharePath of ['', '//evil.example/meme', '/meme/not-valid']) {
  test(`share refuses misleading page fallback for invalid exact path ${JSON.stringify(sharePath)}`, async () => {
    const original = { navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator'), window: globalThis.window, document: globalThis.document };
    const toasts = [];
    Object.defineProperty(globalThis, 'navigator', { configurable: true, value: {
      share: async () => assert.fail('must not share the original page'),
      clipboard: { writeText: async () => assert.fail('must not copy the original page') }
    } });
    globalThis.window = { location: { href: `https://memes.example/meme/${'b'.repeat(64)}?search_q=private` } };
    globalThis.document = { title: 'A different displayed meme', querySelector: () => ({ dataset: { sharePath } }) };
    const interactions = Object.create(MemeInteractions.prototype);
    interactions.triggerHaptic = () => {};
    interactions.showToast = (message, type) => toasts.push({ message, type });
    try {
      await interactions.handleShare();
      assert.equal(interactions.isSharing, false);
      assert.equal(toasts[0].type, 'error');
      assert.match(toasts[0].message, /exact link is unavailable/);
    } finally {
      if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
      globalThis.window = original.window;
      globalThis.document = original.document;
    }
  });
}

for (const scenario of ['cancel', 'native-failure', 'clipboard-denied', 'unsupported']) {
  test(`share feedback handles ${scenario} without an unhandled rejection`, async () => {
    const original = { navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator'), window: globalThis.window, document: globalThis.document };
    const toasts = [];
    let copies = 0;
    const navigator = {};
    if (scenario === 'cancel') navigator.share = async () => { throw Object.assign(new Error('cancel'), { name: 'AbortError' }); };
    if (scenario === 'native-failure') navigator.share = async () => { throw new Error('failed'); };
    if (scenario !== 'unsupported') navigator.clipboard = { writeText: async () => { copies++; if (scenario === 'clipboard-denied') throw new Error('denied'); } };
    Object.defineProperty(globalThis, 'navigator', { configurable: true, value: navigator });
    globalThis.window = { location: { href: 'https://memes.example/random' } };
    globalThis.document = { title: 'Meme Explorer', querySelector: () => ({ dataset: { sharePath: `/meme/${'a'.repeat(64)}` } }) };
    const interactions = Object.create(MemeInteractions.prototype);
    interactions.triggerHaptic = () => {};
    interactions.showToast = (message, type) => toasts.push({ message, type });
    let manualUrl;
    interactions.showManualShare = value => { manualUrl = value; };
    try {
      await interactions.handleShare();
      assert.equal(interactions.isSharing, false);
      if (scenario === 'cancel') { assert.equal(copies, 0); assert.equal(toasts.length, 0); }
      else if (scenario === 'native-failure') { assert.equal(copies, 1); assert.equal(toasts[0].message, 'Link copied'); }
      else {
        assert.equal(toasts[0].type, 'error');
        assert.doesNotMatch(toasts[0].message, /page address/);
        assert.equal(manualUrl, `https://memes.example/meme/${'a'.repeat(64)}`);
      }
    } finally {
      if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
      globalThis.window = original.window;
      globalThis.document = original.document;
    }
  });
}

test('guest Save rolls back and offers sign-in without claiming persistence', async () => {
  const original = { document: globalThis.document, fetch: globalThis.fetch };
  let focused = false;
  const panel = { hidden: true, querySelector: () => ({ focus: () => { focused = true; } }) };
  const button = { classList: { contains: () => false, add() {}, remove() {} } };
  const states = [];
  globalThis.document = { getElementById: () => button, querySelector: selector => selector === '#save-sign-in' ? panel : null };
  globalThis.fetch = async () => ({ ok: false, status: 401, json: async () => ({ pending_save: false }) });
  const interactions = Object.create(MemeInteractions.prototype);
  Object.assign(interactions, {
    getCurrentMemeUrl: () => '/guest.jpg', createRipple() {}, triggerHaptic() {},
    showToast: message => assert.match(message, /Not saved/),
    updateSaveButton: state => states.push(state),
    publishInteraction() { assert.fail('guest save must not publish persistence'); }
  });
  try {
    await interactions.handleSave({});
    assert.deepEqual(states, [true, false]);
    assert.equal(panel.hidden, false);
    assert.equal(focused, true);
    assert.equal(interactions.isProcessing, false);
  } finally { Object.assign(globalThis, original); }
});

test('guest Save resets recovery promises when a later catalog lookup fails', async () => {
  const original = { document: globalThis.document, fetch: globalThis.fetch };
  const message = {};
  const panel = { hidden: true, querySelector: selector => selector === 'p' ? message : { focus() {} } };
  const button = { classList: { contains: () => false, add() {}, remove() {} } };
  globalThis.document = { getElementById: () => button, querySelector: selector => selector === '#save-sign-in' ? panel : null };
  let pending = true;
  globalThis.fetch = async () => ({ ok: false, status: 401, json: async () => ({ pending_save: pending }) });
  const interactions = Object.create(MemeInteractions.prototype);
  Object.assign(interactions, { getCurrentMemeUrl: () => '/guest.jpg', createRipple() {}, triggerHaptic() {}, updateSaveButton() {}, showToast() {} });
  try {
    await interactions.handleSave({});
    assert.match(message.textContent, /Sign in to finish saving this meme/);
    pending = false;
    await interactions.handleSave({});
    assert.match(message.textContent, /Automatic return to this meme is unavailable/);
    assert.doesNotMatch(message.textContent, /Sign in to finish saving this meme/);
  } finally { Object.assign(globalThis, original); }
});

test('delayed guest Save failure does not prompt or steal focus after navigation', async () => {
  const original = { document: globalThis.document, fetch: globalThis.fetch };
  let current = '/first.jpg';
  let finish;
  const button = { classList: { contains: () => false, add() {}, remove() {} } };
  globalThis.document = { getElementById: () => button, querySelector: () => null };
  globalThis.fetch = () => new Promise(resolve => { finish = resolve; });
  const interactions = Object.create(MemeInteractions.prototype);
  Object.assign(interactions, {
    getCurrentMemeUrl: () => current, createRipple() {}, triggerHaptic() {}, updateSaveButton() {},
    showToast() { assert.fail('stale sign-in feedback'); },
    publishInteraction() { assert.fail('no persistence'); }
  });
  try {
    const pending = interactions.handleSave({});
    current = '/second.jpg';
    finish({ ok: false, status: 401 });
    await pending;
    assert.equal(interactions.isProcessing, false);
  } finally { Object.assign(globalThis, original); }
});

test('failed save response rolls back optimistic state and never publishes success', async () => {
  const original = { document: globalThis.document, fetch: globalThis.fetch };
  const changes = [];
  const button = { classList: { contains: () => false, add() {}, remove() {} } };
  globalThis.document = { getElementById: () => button, querySelector: () => null };
  globalThis.fetch = async () => ({ ok: true, json: async () => ({ success: false, message: 'Database unavailable' }) });
  const interactions = Object.create(MemeInteractions.prototype);
  Object.assign(interactions, {
    isProcessing: false, getCurrentMemeUrl: () => '/one.jpg', createRipple() {}, triggerHaptic() {}, showToast() {},
    updateSaveButton: value => changes.push(value),
    publishInteraction() { assert.fail('must not publish a failed save'); }
  });
  try {
    await interactions.handleSave({});
    assert.deepEqual(changes, [true, false]);
    assert.equal(interactions.isProcessing, false);
  } finally { Object.assign(globalThis, original); }
});

test('late successful like updates its content state without repainting a different meme', async () => {
  const original = { document: globalThis.document, fetch: globalThis.fetch };
  let current = '/one.jpg';
  let published;
  const changes = [];
  const button = { classList: { contains: () => false, add() {}, remove() {} } };
  globalThis.document = { getElementById: () => button };
  globalThis.fetch = async () => {
    current = '/two.jpg';
    return { ok: true, json: async () => ({ success: true, liked: true, likes: 9 }) };
  };
  const interactions = Object.create(MemeInteractions.prototype);
  Object.assign(interactions, {
    isProcessing: false, getCurrentMemeUrl: () => current, createRipple() {}, triggerHaptic() {}, showToast() {},
    updateLikeButton: value => changes.push(value),
    publishInteraction: (url, state) => { published = { url, state }; }
  });
  try {
    await interactions.handleLike({});
    assert.deepEqual(changes, [true]);
    assert.equal(published.url, '/one.jpg');
    assert.equal(published.state.likes, 9);
  } finally { Object.assign(globalThis, original); }
});