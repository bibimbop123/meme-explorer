import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('../../public/js/share-system.js', import.meta.url), 'utf8');
const previous = globalThis.document;
globalThis.document = { readyState: 'loading', addEventListener() {} };
const { currentShareImage, prepareImageFile, initializeShareButtons } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
globalThis.document = previous;

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