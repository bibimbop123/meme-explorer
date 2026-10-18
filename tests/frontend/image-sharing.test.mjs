import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('../../public/js/share-system.js', import.meta.url), 'utf8');
const previous = globalThis.document;
globalThis.document = { readyState: 'loading', addEventListener() {} };
const { currentShareImage, prepareImageFile, copyImageFile, initializeShareButtons } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
globalThis.document = previous;

for (const mode of ['oversized', 'canvas-failure']) {
  test(`clipboard conversion releases bitmap on ${mode}`, async () => {
    const original = { document: globalThis.document, window: globalThis.window, fetch: globalThis.fetch, ClipboardItem: globalThis.ClipboardItem, createImageBitmap: globalThis.createImageBitmap, navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator') };
    let closed = 0;
    let canvases = 0;
    globalThis.window = { location: { origin: 'https://memes.example' } };
    globalThis.fetch = async () => ({ ok: true, blob: async () => new Blob(['jpeg'], { type: 'image/jpeg' }) });
    globalThis.createImageBitmap = async () => ({ width: mode === 'oversized' ? 9000 : 300, height: 300, close() { closed++; } });
    globalThis.document = { createElement() { canvases++; return { getContext() { throw new Error('Canvas unavailable'); } }; } };
    globalThis.ClipboardItem = class { constructor(items) { this.items = items; } };
    Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { clipboard: { write: async items => { await items[0].items['image/png']; } } } });
    try {
      await assert.rejects(copyImageFile('https://memes.example/images/large.jpg'), mode === 'oversized' ? /too large/ : /Canvas unavailable/);
      assert.equal(closed, 1);
      assert.equal(canvases, mode === 'oversized' ? 0 : 1);
    } finally {
      Object.assign(globalThis, { document: original.document, window: original.window, fetch: original.fetch, ClipboardItem: original.ClipboardItem, createImageBitmap: original.createImageBitmap });
      if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
    }
  });
}

test('clipboard denial before a later fetch failure does not leak an unhandled rejection', async () => {
  const original = { window: globalThis.window, fetch: globalThis.fetch, ClipboardItem: globalThis.ClipboardItem, navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator') };
  let rejectImage;
  globalThis.window = { location: { origin: 'https://memes.example' } };
  globalThis.fetch = () => new Promise((_resolve, reject) => { rejectImage = reject; });
  globalThis.ClipboardItem = class { constructor(items) { this.items = items; } };
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { clipboard: { write: async () => { throw new Error('Permission denied'); } } } });
  try {
    await assert.rejects(copyImageFile('https://memes.example/images/first.png'), /Permission denied/);
    rejectImage(new Error('Image failed later'));
    await new Promise(resolve => setImmediate(resolve));
  } finally {
    Object.assign(globalThis, { window: original.window, fetch: original.fetch, ClipboardItem: original.ClipboardItem });
    if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
  }
});

test('late image-copy success cannot announce the previous image after navigation', async () => {
  const original = { document: globalThis.document, window: globalThis.window, fetch: globalThis.fetch, ClipboardItem: globalThis.ClipboardItem, navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator') };
  const elements = [];
  let finishWrite;
  const image = { src: 'https://memes.example/images/first.png', dataset: {} };
  const container = { dataset: {}, querySelector: selector => selector === '.share-bar' ? null : selector === '#meme-display' ? {} : image, appendChild() {} };
  globalThis.window = { location: { origin: 'https://memes.example', href: 'https://memes.example/random' } };
  globalThis.document = {
    querySelectorAll: () => [container], querySelector: selector => selector === '#viewer-share-data' ? { dataset: { sharePath: `/meme/${'a'.repeat(64)}` } } : { textContent: 'Fixture' },
    createTextNode: text => ({ textContent: text }),
    createElement: () => { const el = { setAttribute() {}, appendChild() {}, replaceChildren() {}, addEventListener: (_, fn) => { el.click = fn; } }; elements.push(el); return el; }
  };
  globalThis.fetch = async () => ({ ok: true, blob: async () => new Blob(['png'], { type: 'image/png' }) });
  globalThis.ClipboardItem = class {};
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { clipboard: { write: () => new Promise(resolve => { finishWrite = resolve; }) } } });
  try {
    initializeShareButtons();
    const button = elements.find(el => el.textContent === 'Copy image for X');
    const pending = button.click();
    image.src = 'https://memes.example/images/second.png';
    finishWrite();
    await pending;
    assert.equal(button.disabled, false);
    assert.ok(!elements.some(el => el.textContent?.startsWith('Selected image copied.')));
  } finally {
    Object.assign(globalThis, { document: original.document, window: original.window, fetch: original.fetch, ClipboardItem: original.ClipboardItem });
    if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
  }
});

test('desktop clipboard starts write immediately with promised PNG bytes', async () => {
  const original = { window: globalThis.window, fetch: globalThis.fetch, ClipboardItem: globalThis.ClipboardItem, navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator') };
  let written;
  let resolveResponse;
  globalThis.window = { location: { origin: 'https://memes.example' } };
  globalThis.fetch = () => new Promise(resolve => { resolveResponse = resolve; });
  globalThis.ClipboardItem = class { constructor(items) { this.items = items; } };
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { clipboard: { write: async items => { written = items; await items[0].items['image/png']; } } } });
  try {
    const copying = copyImageFile('https://memes.example/images/current.png');
    assert.ok(written[0] instanceof ClipboardItem);
    resolveResponse({ ok: true, blob: async () => new Blob(['png'], { type: 'image/png' }) });
    await copying;
    assert.equal((await written[0].items['image/png']).type, 'image/png');
    navigator.clipboard = {};
    await assert.rejects(copyImageFile('https://memes.example/images/current.png'), /unavailable/);
  } finally {
    Object.assign(globalThis, { window: original.window, fetch: original.fetch, ClipboardItem: original.ClipboardItem });
    if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
  }
});

test('image selector uses active gallery image and refuses videos/untrusted media', () => {
  const original = globalThis.window;
  globalThis.window = { location: { href: 'https://memes.example/random', origin: 'https://memes.example' } };
  try {
    assert.equal(currentShareImage({ querySelector: () => null }), null);
    for (const src of ['https://evil.example/a.jpg', 'http://i.redd.it/a.jpg', 'https://user:pass@i.redd.it/a.jpg']) {
      assert.equal(currentShareImage({ querySelector: () => ({ src, dataset: {} }) }), null);
    }
    assert.equal(currentShareImage({ querySelector: selector => selector.includes('active') ? { src: '/images/second.jpeg', dataset: {} } : null }), 'https://memes.example/images/second.jpeg');
  } finally { globalThis.window = original; }
});

test('image preparation validates MIME and size and uses same-origin proxy for remote files', async () => {
  const original = { window: globalThis.window, fetch: globalThis.fetch };
  globalThis.window = { location: { origin: 'https://memes.example' } };
  let requested;
  globalThis.fetch = async url => { requested = url; return { ok: true, blob: async () => new Blob(['image'], { type: 'image/png' }) }; };
  try {
    const file = await prepareImageFile('https://i.redd.it/exact.png');
    assert.equal(file.type, 'image/png');
    assert.equal(file.name, 'meme-explorer.png');
    assert.equal(new URL(requested, 'https://memes.example').searchParams.get('url'), 'https://i.redd.it/exact.png');
    globalThis.fetch = async () => ({ ok: true, blob: async () => new Blob(['html'], { type: 'text/html' }) });
    await assert.rejects(prepareImageFile('https://i.redd.it/exact.png'));
  } finally { Object.assign(globalThis, original); }
});

test('two-click file sharing preserves activation, sends actual File and handles cancellation honestly', async () => {
  const original = { window: globalThis.window, document: globalThis.document, fetch: globalThis.fetch, navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator') };
  const buttons = [];
  const elements = [];
  const image = { src: 'https://memes.example/images/current.png', dataset: {} };
  const container = { dataset: {}, querySelector: selector => selector === '.share-bar' ? null : selector === '#meme-display' ? {} : image, appendChild() {} };
  globalThis.window = { location: { origin: 'https://memes.example', href: 'https://memes.example/random' } };
  globalThis.document = {
    querySelectorAll: () => [container], querySelector: selector => selector === '#viewer-share-data' ? { dataset: { sharePath: `/meme/${'a'.repeat(64)}` } } : { textContent: 'Exact image' },
    createTextNode: text => ({ textContent: text }),
    createElement: tag => { const el = { setAttribute() {}, appendChild() {}, replaceChildren() {}, addEventListener: (_, fn) => { el.click = fn; } }; elements.push(el); if (tag === 'button') buttons.push(el); return el; }
  };
  globalThis.fetch = async () => ({ ok: true, blob: async () => new Blob(['image'], { type: 'image/png' }) });
  let payload;
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { canShare: () => true, share: async data => { payload = data; } } });
  try {
    initializeShareButtons();
    const button = buttons.find(b => b.textContent === 'Share image');
    await button.click();
    assert.equal(payload, undefined);
    assert.equal(button.textContent, 'Choose app to share image');
    await button.click();
    assert.ok(payload.files[0] instanceof File);
    assert.equal(payload.text, `https://memes.example/meme/${'a'.repeat(64)}`);
    navigator.share = async () => { throw Object.assign(new Error(), { name: 'AbortError' }); };
    await button.click();
    assert.ok(elements.some(el => el.textContent === 'Image sharing canceled.'));
  } finally {
    Object.assign(globalThis, { window: original.window, document: original.document, fetch: original.fetch });
    if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
  }
});

test('navigation resets prepared-image UI and ignores an older pending download', async () => {
  const original = { document: globalThis.document, window: globalThis.window, fetch: globalThis.fetch, MutationObserver: globalThis.MutationObserver, navigator: Object.getOwnPropertyDescriptor(globalThis, 'navigator') };
  const elements = [];
  let changed;
  let finish;
  const image = { src: 'https://memes.example/images/first.png', dataset: {} };
  const container = { dataset: {}, querySelector: selector => selector === '.share-bar' ? null : selector === '#meme-display' ? {} : image, appendChild() {} };
  globalThis.window = { location: { origin: 'https://memes.example', href: 'https://memes.example/random' } };
  globalThis.document = {
    querySelectorAll: () => [container], querySelector: selector => selector === '#viewer-share-data' ? { dataset: { sharePath: `/meme/${'a'.repeat(64)}` } } : { textContent: 'Fixture' },
    createTextNode: text => ({ textContent: text }),
    createElement: () => { const el = { setAttribute() {}, appendChild() {}, replaceChildren() {}, addEventListener: (_, fn) => { el.click = fn; } }; elements.push(el); return el; }
  };
  globalThis.MutationObserver = class { constructor(callback) { changed = callback; } observe() {} };
  globalThis.fetch = () => new Promise(resolve => { finish = resolve; });
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { canShare: () => true, share: async () => assert.fail('old file must not share') } });
  try {
    initializeShareButtons();
    const button = elements.find(el => el.textContent === 'Share image');
    const preparing = button.click();
    assert.equal(button.disabled, true);
    image.src = 'https://memes.example/images/second.png';
    changed();
    assert.equal(button.disabled, false);
    assert.equal(button.textContent, 'Share image');
    finish({ ok: true, blob: async () => new Blob(['png'], { type: 'image/png' }) });
    await preparing;
    assert.equal(button.textContent, 'Share image');
    assert.ok(!elements.some(el => el.textContent?.startsWith('Image ready.')));
  } finally {
    Object.assign(globalThis, { document: original.document, window: original.window, fetch: original.fetch, MutationObserver: original.MutationObserver });
    if (original.navigator) Object.defineProperty(globalThis, 'navigator', original.navigator); else delete globalThis.navigator;
  }
});